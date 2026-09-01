// Coalition Engine routes: coalitions CRUD, membership, cross-redemption, clearinghouse
module.exports = function registerCoalitionRoutes(app, deps) {
  const { pool, auth, id, toIso, getMerchantProfileIdByUser, insertNotification } = deps;

  // ── List public coalitions (joinable by merchant) ────────────────────────────
  app.get('/api/merchant/coalitions', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows } = await pool.query(`
      SELECT c.id, c.name, c.type, c.category, c.region, c.is_active,
             c.created_at,
             (SELECT COUNT(*) FROM coalition_members WHERE coalition_id = c.id) AS member_count,
             EXISTS (SELECT 1 FROM coalition_members WHERE coalition_id = c.id AND merchant_id = $1) AS is_member
        FROM coalitions c
       WHERE c.is_active = TRUE
         AND (c.type != 'private'
              OR EXISTS (SELECT 1 FROM coalition_members WHERE coalition_id = c.id AND merchant_id = $1)
              OR EXISTS (SELECT 1 FROM coalition_invitations WHERE coalition_id = c.id AND invited_merchant_id = $1 AND status = 'pending'))
       ORDER BY member_count DESC, c.created_at DESC
    `, [merchantId]);

    res.json({ coalitions: rows });
  });

  // ── Get my coalition memberships ─────────────────────────────────────────────
  app.get('/api/merchant/coalitions/mine', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows } = await pool.query(`
      SELECT c.id, c.name, c.type, c.category, c.region, cm.joined_at, cm.point_conversion_rate,
             (SELECT COUNT(*) FROM coalition_members WHERE coalition_id = c.id) AS member_count
        FROM coalitions c
        JOIN coalition_members cm ON cm.coalition_id = c.id AND cm.merchant_id = $1
       ORDER BY cm.joined_at DESC
    `, [merchantId]);

    res.json({ coalitions: rows });
  });

  // ── Create a coalition ────────────────────────────────────────────────────────
  app.post('/api/merchant/coalitions', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { name, type = 'general', category, region, monthly_points_cap } = req.body;
    if (!name?.trim()) return res.status(400).json({ error: 'name_required' });
    if (!['general', 'category', 'regional', 'private'].includes(type))
      return res.status(400).json({ error: 'invalid_type' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const coalitionId = id();
      await client.query(
        `INSERT INTO coalitions (id, name, type, category, region, created_by)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [coalitionId, name.trim(), type, category || null, region || null, merchantId]
      );
      // Creator automatically becomes a member
      await client.query(
        `INSERT INTO coalition_members (coalition_id, merchant_id) VALUES ($1, $2)`,
        [coalitionId, merchantId]
      );
      if (monthly_points_cap) {
        await client.query(
          `INSERT INTO coalition_spending_caps (coalition_id, merchant_id, monthly_points_cap)
           VALUES ($1, $2, $3)`,
          [coalitionId, merchantId, parseInt(monthly_points_cap)]
        );
      }
      await client.query('COMMIT');
      res.status(201).json({ coalition_id: coalitionId });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  });

  // ── Join a coalition ──────────────────────────────────────────────────────────
  app.post('/api/merchant/coalitions/:id/join', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows: [coalition] } = await pool.query(
      `SELECT * FROM coalitions WHERE id = $1 AND is_active = TRUE`, [req.params.id]
    );
    if (!coalition) return res.status(404).json({ error: 'not_found' });
    if (coalition.type === 'private') {
      // Private coalitions require an invitation
      const { rows: [inv] } = await pool.query(
        `SELECT id FROM coalition_invitations WHERE coalition_id = $1 AND invited_merchant_id = $2 AND status = 'pending'`,
        [coalition.id, merchantId]
      );
      if (!inv) return res.status(403).json({ error: 'invitation_required' });
      await pool.query(
        `UPDATE coalition_invitations SET status = 'accepted', responded_at = NOW() WHERE id = $1`,
        [inv.id]
      );
    }

    await pool.query(
      `INSERT INTO coalition_members (coalition_id, merchant_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [coalition.id, merchantId]
    );
    res.json({ ok: true });
  });

  // ── Leave a coalition ─────────────────────────────────────────────────────────
  app.post('/api/merchant/coalitions/:id/leave', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    await pool.query(
      `DELETE FROM coalition_members WHERE coalition_id = $1 AND merchant_id = $2`,
      [req.params.id, merchantId]
    );
    res.json({ ok: true });
  });

  // ── Invite another merchant to a private coalition ────────────────────────────
  app.post('/api/merchant/coalitions/:id/invite', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { invited_merchant_id } = req.body;
    if (!invited_merchant_id) return res.status(400).json({ error: 'invited_merchant_id_required' });

    // Inviter must be a member
    const { rows: [membership] } = await pool.query(
      `SELECT 1 FROM coalition_members WHERE coalition_id = $1 AND merchant_id = $2`,
      [req.params.id, merchantId]
    );
    if (!membership) return res.status(403).json({ error: 'not_a_member' });

    const invId = id();
    await pool.query(
      `INSERT INTO coalition_invitations (id, coalition_id, invited_merchant_id, invited_by)
       VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
      [invId, req.params.id, invited_merchant_id, merchantId]
    );
    res.status(201).json({ invitation_id: invId });
  });

  // ── My pending invitations ────────────────────────────────────────────────────
  app.get('/api/merchant/coalitions/invitations', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows } = await pool.query(`
      SELECT ci.id, ci.coalition_id, c.name AS coalition_name, c.type,
             ci.invited_by, mp.business_name AS inviter_name, ci.created_at
        FROM coalition_invitations ci
        JOIN coalitions c ON c.id = ci.coalition_id
        JOIN merchant_profiles mp ON mp.id = ci.invited_by
       WHERE ci.invited_merchant_id = $1 AND ci.status = 'pending'
       ORDER BY ci.created_at DESC
    `, [merchantId]);

    res.json({ invitations: rows });
  });

  // ── Cross-redemption ledger ───────────────────────────────────────────────────
  app.get('/api/merchant/coalitions/ledger', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { period } = req.query; // YYYY-MM optional filter
    const params = [merchantId];
    const periodFilter = period ? `AND to_char(cl.created_at, 'YYYY-MM') = $2` : '';
    if (period) params.push(period);

    const { rows } = await pool.query(`
      SELECT cl.id, cl.coalition_id, c.name AS coalition_name,
             cl.from_merchant_id, fm.business_name AS from_merchant,
             cl.to_merchant_id, tm.business_name AS to_merchant,
             cl.points_redeemed, cl.conversion_rate, cl.net_points, cl.created_at
        FROM coalition_ledger cl
        JOIN coalitions c ON c.id = cl.coalition_id
        JOIN merchant_profiles fm ON fm.id = cl.from_merchant_id
        JOIN merchant_profiles tm ON tm.id = cl.to_merchant_id
       WHERE (cl.from_merchant_id = $1 OR cl.to_merchant_id = $1) ${periodFilter}
       ORDER BY cl.created_at DESC LIMIT 200
    `, params);

    res.json({ ledger: rows });
  });

  // ── Monthly clearinghouse summary ─────────────────────────────────────────────
  app.get('/api/merchant/coalitions/clearinghouse', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows } = await pool.query(`
      SELECT cc.period, cc.coalition_id, c.name AS coalition_name,
             cc.from_merchant_id, fm.business_name AS from_merchant,
             cc.to_merchant_id, tm.business_name AS to_merchant,
             cc.total_points, cc.settled, cc.settled_at
        FROM coalition_clearinghouse cc
        JOIN coalitions c ON c.id = cc.coalition_id
        JOIN merchant_profiles fm ON fm.id = cc.from_merchant_id
        JOIN merchant_profiles tm ON tm.id = cc.to_merchant_id
       WHERE cc.from_merchant_id = $1 OR cc.to_merchant_id = $1
       ORDER BY cc.period DESC, cc.total_points DESC
    `, [merchantId]);

    res.json({ statements: rows });
  });

  // ── Mark clearinghouse period as settled ──────────────────────────────────────
  app.post('/api/merchant/coalitions/clearinghouse/settle', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { coalition_id, to_merchant_id, period } = req.body;
    if (!coalition_id || !to_merchant_id || !period)
      return res.status(400).json({ error: 'coalition_id, to_merchant_id, period required' });

    const { rowCount } = await pool.query(`
      UPDATE coalition_clearinghouse
         SET settled = TRUE, settled_at = NOW()
       WHERE coalition_id = $1 AND from_merchant_id = $2 AND to_merchant_id = $3
         AND period = $4 AND settled = FALSE
    `, [coalition_id, merchantId, to_merchant_id, period]);

    res.json({ ok: true, updated: rowCount });
  });

  // ── Coalition members list ─────────────────────────────────────────────────────
  app.get('/api/merchant/coalitions/:id/members', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    // Only members can see member list
    const { rows: [membership] } = await pool.query(
      `SELECT 1 FROM coalition_members WHERE coalition_id = $1 AND merchant_id = $2`,
      [req.params.id, merchantId]
    );
    if (!membership) return res.status(403).json({ error: 'not_a_member' });

    const { rows } = await pool.query(`
      SELECT mp.id, mp.business_name, mp.city, mp.category,
             cm.joined_at, cm.point_conversion_rate
        FROM coalition_members cm
        JOIN merchant_profiles mp ON mp.id = cm.merchant_id
       WHERE cm.coalition_id = $1
       ORDER BY cm.joined_at
    `, [req.params.id]);

    res.json({ members: rows });
  });

  // ── Set spending cap ───────────────────────────────────────────────────────────
  app.put('/api/merchant/coalitions/:id/spending-cap', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const cap = parseInt(req.body.monthly_points_cap);
    if (!cap || cap < 100) return res.status(400).json({ error: 'minimum_cap_100_points' });

    await pool.query(`
      INSERT INTO coalition_spending_caps (coalition_id, merchant_id, monthly_points_cap)
      VALUES ($1, $2, $3)
      ON CONFLICT (coalition_id, merchant_id)
      DO UPDATE SET monthly_points_cap = EXCLUDED.monthly_points_cap
    `, [req.params.id, merchantId, cap]);

    res.json({ ok: true });
  });
};
