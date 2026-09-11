// Coalition Engine routes: coalitions CRUD, membership, cross-redemption, clearinghouse
const crypto = require('crypto');
const pointValuation = require('../point-valuation-service');
const { summarizeTierBalances } = require('../tier-balance-service');

module.exports = function registerCoalitionRoutes(app, deps) {
  const { pool, auth, id, toIso, getMerchantProfileIdByUser, getBrandProfileIdByUser, insertNotification } = deps;

  app.get('/api/customer/wallet/tiers', auth, async (req, res) => {
    const [tierResult, accountResult] = await Promise.all([
      pool.query(`
        SELECT tier, COALESCE(SUM(balance), 0)::int AS balance,
               COALESCE(SUM(lifetime_earned), 0)::int AS lifetime_earned
          FROM customer_point_tiers
         WHERE customer_id = $1
         GROUP BY tier
      `, [req.user.userId]),
      pool.query(
        'SELECT available_points, lifetime_points FROM point_accounts WHERE owner_id = $1',
        [req.user.userId]
      ),
    ]);
    const availablePoints = Number(accountResult.rows[0]?.available_points || 0);
    const lifetimePoints = Number(accountResult.rows[0]?.lifetime_points || 0);
    const { tiers, legacyUnclassified } = summarizeTierBalances(
      availablePoints,
      tierResult.rows,
      lifetimePoints
    );
    res.json({ tiers, availablePoints, legacyUnclassified });
  });

  app.get('/api/customer/wallet/pending-points', auth, async (req, res) => {
    const { rows } = await pool.query(`
      SELECT p.id, p.merchant_id, mp.business_name AS merchant_name, p.invoice_id,
             p.points, p.points_remaining, p.tier, p.status, p.created_at
        FROM customer_pending_points p
        JOIN merchant_profiles mp ON mp.id = p.merchant_id
       WHERE p.customer_id = $1 AND p.status IN ('PENDING', 'PARTIALLY_CLEARED')
       ORDER BY p.created_at ASC
    `, [req.user.userId]);
    res.json({ pending: rows, total_points: rows.reduce((sum, row) => sum + Number(row.points_remaining || 0), 0) });
  });

  app.get('/api/customer/gifts/catalog', auth, async (req, res) => {
    const customerId = req.user.userId;
    const { rows: [pointRow] } = await pool.query(
      'SELECT available_points FROM point_accounts WHERE owner_id = $1',
      [customerId]
    );
    const availablePoints = Number(pointRow?.available_points || 0);

    const [rewardRows, coalitionGiftRows] = await Promise.all([
      pool.query(`
        SELECT id, reward_name AS title, description, value AS points_cost,
               kind, image_url AS image_url, source_type, source_id,
               expires_at, created_at
          FROM rewards
         WHERE is_active = TRUE
           AND (quantity_limit IS NULL OR quantity_redeemed < quantity_limit)
           AND (expires_at IS NULL OR expires_at > NOW())
         ORDER BY value DESC
      `),
      pool.query(`
        SELECT g.id, g.title, g.description, g.required_points AS points_cost,
               g.monetary_value, g.image_url, g.expires_at, g.coalition_id,
               c.name AS coalition_name, 'coalition' AS source_type,
               g.coalition_id AS source_id
          FROM coalition_gift_catalog g
          JOIN coalitions c ON c.id = g.coalition_id
         WHERE g.is_active = TRUE
           AND (g.quantity_limit IS NULL OR g.quantity_redeemed < g.quantity_limit)
           AND (g.expires_at IS NULL OR g.expires_at > NOW())
         ORDER BY g.required_points ASC
      `)
    ]);

    const items = [
      ...rewardRows.rows.map((row) => ({
        id: row.id,
        title: row.title,
        description: row.description,
        pointsCost: Number(row.points_cost || 0),
        cashValueLyD: Number((Number(row.points_cost || 0) * 0.1).toFixed(2)),
        imageUrl: row.image_url,
        kind: row.kind || 'physical',
        sourceType: row.source_type || 'merchant',
        sourceId: row.source_id || row.id,
        expiresAt: toIso(row.expires_at),
        origin: 'reward',
      })),
      ...coalitionGiftRows.rows.map((row) => ({
        id: row.id,
        title: row.title,
        description: row.description,
        pointsCost: Number(row.points_cost || 0),
        cashValueLyD: Number((Number(row.monetary_value || 0) || (Number(row.points_cost || 0) * 0.1)).toFixed(2)),
        imageUrl: row.image_url,
        kind: 'physical',
        sourceType: row.source_type || 'coalition',
        sourceId: row.source_id || row.coalition_id,
        expiresAt: toIso(row.expires_at),
        origin: 'coalition',
        coalitionName: row.coalition_name,
      })),
    ].sort((a, b) => a.pointsCost - b.pointsCost);

    const unlocked = items.filter((item) => item.pointsCost <= availablePoints);
    const locked = items.filter((item) => item.pointsCost > availablePoints);

    res.json({
      availablePoints,
      unlocked,
      locked,
      items,
    });
  });

  function hashToken(token) {
    return crypto.createHash('sha256').update(String(token || '')).digest('hex');
  }

  app.post('/api/customer/redemptions/dynamic-voucher', auth, async (req, res) => {
    const body = req.body || {};
    const rawCashValue = Number(body.cashValueLyD ?? body.cashValue ?? body.amount ?? 0);
    const rawPoints = Number(body.points ?? 0);
    const merchantId = String(body.merchantId || '').trim();
    const customerId = req.user.userId;

    if (!Number.isFinite(rawCashValue) || rawCashValue <= 0) {
      return res.status(400).json({ error: 'cash_value_required' });
    }

    const requiredPoints = rawPoints > 0
      ? Math.round(rawPoints)
      : Math.round(rawCashValue * 10);

    if (!Number.isFinite(requiredPoints) || requiredPoints <= 0) {
      return res.status(400).json({ error: 'invalid_points_required' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        'INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING',
        [customerId]
      );

      let merchantName = null;
      if (merchantId) {
        const { rows: [merchant] } = await client.query(
          'SELECT id, business_name FROM merchant_profiles WHERE id = $1 LIMIT 1',
          [merchantId]
        );
        if (!merchant) {
          await client.query('ROLLBACK');
          return res.status(404).json({ error: 'merchant_not_found' });
        }
        merchantName = merchant.business_name || null;

        // Mirrors the GET /api/wallet/points/sources reconciliation so a store
        // shown in the calculator (sourced from ledger, tiers, or coalition
        // balances) never fails validation here with a false "insufficient" error.
        const { rows: [merchantBalance] } = await client.query(
          `SELECT GREATEST(
                    COALESCE((SELECT SUM(CASE WHEN status = 'active' THEN points_delta ELSE 0 END)
                                FROM points_ledger_merchant
                               WHERE customer_id = $1 AND merchant_id = $2), 0),
                    COALESCE((SELECT SUM(balance)
                                FROM customer_point_tiers
                               WHERE customer_id = $1 AND merchant_id = $2), 0),
                    COALESCE((SELECT SUM(points_balance)
                                FROM customer_merchant_point_balances
                               WHERE customer_id = $1 AND merchant_id = $2), 0)
                  )::int AS active_points`,
          [customerId, merchantId]
        );
        const merchantPoints = Number(merchantBalance?.active_points || 0);
        if (merchantPoints < requiredPoints) {
          await client.query('ROLLBACK');
          return res.status(400).json({
            error: 'insufficient_points_at_merchant',
            merchantId,
            merchantName,
            availablePoints: merchantPoints,
            requiredPoints,
          });
        }
      } else {
        const pointAccount = (await client.query(
          'SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE',
          [customerId]
        )).rows[0];

        if (!pointAccount || Number(pointAccount.available_points || 0) < requiredPoints) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'insufficient_points' });
        }
      }

      const tierRows = await client.query(
        `SELECT tier, balance
           FROM customer_point_tiers
          WHERE customer_id = $1
          ORDER BY CASE tier WHEN 'gold' THEN 3 WHEN 'silver' THEN 2 ELSE 1 END DESC, balance DESC
          LIMIT 1`,
        [customerId]
      );
      const selectedTier = tierRows.rows[0]?.tier || 'bronze';

      const rawToken = crypto.randomUUID().replace(/-/g, '').slice(0, 24).toUpperCase();
      const tokenHash = hashToken(rawToken);
      const claimId = id();

      const { rows: [claim] } = await client.query(
        `INSERT INTO cash_voucher_claims (id, customer_id, points_cost, cash_value_lyd, status, merchant_id, snapshot_json, claimed_at, tokenized_at, expires_at)
         VALUES ($1, $2, $3, $4, 'TOKENIZED', $5, $6::jsonb, NOW(), NOW(), NOW() + INTERVAL '24 hours')
         RETURNING *`,
        [
          claimId,
          customerId,
          requiredPoints,
          rawCashValue,
          merchantId || null,
          JSON.stringify(merchantName ? { merchantName } : {}),
        ]
      );

      await client.query(
        `INSERT INTO redemption_tokens (id, cash_voucher_claim_id, purpose, token_hash, status, issued_at, active_at, expires_at)
         VALUES ($1, $2, 'REDEMPTION', $3, 'ACTIVE', NOW(), NOW(), NOW() + INTERVAL '24 hours')`,
        [id(), claimId, tokenHash]
      );

      await client.query('COMMIT');
      return res.status(201).json({
        ok: true,
        redemptionId: claimId,
        voucher: {
          id: claimId,
          qrCode: rawToken,
          pointsUsed: requiredPoints,
          cashValueLyD: Number(rawCashValue.toFixed(2)),
          status: 'ready_for_cashier',
          tier: selectedTier,
          merchantId: merchantId || null,
          merchantName,
          message: merchantName
            ? `جاهز للاستخدام لدى ${merchantName}`
            : 'جاهز للاستخدام لدى الكاشير',
        },
      });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'dynamic_voucher_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/cashier/dynamic-voucher/verify', auth, async (req, res) => {
    const body = req.body || {};
    const rawToken = String(body.qrCode || body.redemptionToken || body.token || '').trim();
    if (!rawToken) return res.status(400).json({ error: 'token_required' });
    const tokenHash = hashToken(rawToken);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows: [token] } = await client.query(
        `SELECT rt.*, cvc.customer_id, cvc.points_cost, cvc.cash_value_lyd, cvc.status AS claim_status,
                cvc.merchant_id, mp.business_name AS merchant_name
           FROM redemption_tokens rt
           JOIN cash_voucher_claims cvc ON cvc.id = rt.cash_voucher_claim_id
           LEFT JOIN merchant_profiles mp ON mp.id = cvc.merchant_id
          WHERE rt.token_hash = $1 FOR UPDATE OF rt, cvc`,
        [tokenHash]
      );

      if (!token) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'token_not_found' });
      }

      if (token.status === 'USED' || token.claim_status === 'REDEEMED') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'token_already_used' });
      }

      if (token.status === 'EXPIRED' || (token.expires_at && new Date(token.expires_at) < new Date())) {
        await client.query('ROLLBACK');
        return res.status(410).json({ error: 'token_expired' });
      }

      await client.query(
        `UPDATE redemption_tokens SET status = 'VERIFIED', scanned_at = NOW(), verified_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [token.id]
      );
      await client.query(
        `UPDATE cash_voucher_claims SET status = 'VERIFIED', verified_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [token.cash_voucher_claim_id]
      );

      await client.query(
        `INSERT INTO token_scans (id, token_id, scanned_by_user_id, status, verification_result)
         VALUES ($1, $2, $3, 'VERIFIED', 'dynamic_voucher_verified')`,
        [id(), token.id, req.user.userId]
      );

      await client.query('COMMIT');
      return res.json({
        ok: true,
        status: 'VERIFIED',
        cashValueLyD: Number(token.cash_value_lyd),
        pointsCost: Number(token.points_cost),
        customerId: token.customer_id,
        claimId: token.cash_voucher_claim_id,
        merchantId: token.merchant_id || null,
        merchantName: token.merchant_name || null,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'verify_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/cashier/dynamic-voucher/redeem', auth, async (req, res) => {
    const body = req.body || {};
    const rawToken = String(body.qrCode || body.redemptionToken || body.token || '').trim();
    const idempotencyKey = String(body.idempotencyKey || '').trim();
    if (!rawToken) return res.status(400).json({ error: 'token_required' });
    const tokenHash = hashToken(rawToken);

    if (idempotencyKey) {
      const { rows: [reqRow] } = await pool.query(
        `SELECT response_json FROM redemption_requests WHERE actor_user_id = $1 AND idempotency_key = $2 AND status = 'COMPLETED'`,
        [req.user.userId, idempotencyKey]
      );
      if (reqRow && reqRow.response_json) {
        return res.json({ ...reqRow.response_json, idempotentReplay: true });
      }
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows: [token] } = await client.query(
        `SELECT rt.*, cvc.customer_id, cvc.points_cost, cvc.cash_value_lyd, cvc.status AS claim_status,
                cvc.merchant_id, mp.business_name AS merchant_name
           FROM redemption_tokens rt
           JOIN cash_voucher_claims cvc ON cvc.id = rt.cash_voucher_claim_id
           LEFT JOIN merchant_profiles mp ON mp.id = cvc.merchant_id
          WHERE rt.token_hash = $1 FOR UPDATE OF rt, cvc`,
        [tokenHash]
      );

      if (!token) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'token_not_found' });
      }

      if (token.status === 'USED' || token.claim_status === 'REDEEMED') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'token_already_used' });
      }

      if (token.status === 'EXPIRED' || (token.expires_at && new Date(token.expires_at) < new Date())) {
        await client.query('ROLLBACK');
        return res.status(410).json({ error: 'token_expired' });
      }

      const pointsCost = Number(token.points_cost);
      const customerId = token.customer_id;

      const { rows: [account] } = await client.query(
        `SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE`,
        [customerId]
      );

      if (!account || Number(account.available_points || 0) < pointsCost) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'insufficient_points' });
      }

      const fulfillerMerchantId = await getMerchantProfileIdByUser(client, req.user.userId)
        || (await client.query(
          'SELECT merchant_id FROM cashier_profiles WHERE user_id = $1 AND is_active = TRUE LIMIT 1',
          [req.user.userId]
        )).rows[0]?.merchant_id
        || null;
      const redemptionId = id();

      if (token.merchant_id && fulfillerMerchantId && token.merchant_id !== fulfillerMerchantId) {
        await client.query('ROLLBACK');
        return res.status(409).json({
          error: 'voucher_merchant_mismatch',
          boundMerchantId: token.merchant_id,
          boundMerchantName: token.merchant_name || null,
        });
      }

      await client.query(
        `UPDATE point_accounts SET available_points = available_points - $1, updated_at = NOW() WHERE owner_id = $2`,
        [pointsCost, customerId]
      );

      if (token.merchant_id) {
        await client.query(
          `INSERT INTO points_ledger_merchant (id, customer_id, merchant_id, points_delta, fraction_before, fraction_after, status)
           VALUES ($1, $2, $3, $4, 0, 0, 'active')`,
          [id(), customerId, token.merchant_id, -pointsCost]
        );
      }

      await client.query(
        `INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference, created_at)
         VALUES ($1, $2, 'cashVoucherRedeemed', $3, $4, $5, NOW())`,
        [id(), customerId, Number(token.cash_value_lyd), -pointsCost, `cash_voucher:${token.cash_voucher_claim_id}`]
      );

      await client.query(
        `INSERT INTO redemptions (id, token_id, cash_voucher_claim_id, redemption_kind, customer_id, fulfilled_by_user_id, fulfiller_merchant_id, status, completed_at)
         VALUES ($1, $2, $3, 'CASH_VALUE', $4, $5, $6, 'COMPLETED', NOW())`,
        [redemptionId, token.id, token.cash_voucher_claim_id, customerId, req.user.userId, fulfillerMerchantId]
      );

      await client.query(
        `UPDATE cash_voucher_claims SET status = 'REDEEMED', redeemed_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [token.cash_voucher_claim_id]
      );

      await client.query(
        `UPDATE redemption_tokens SET status = 'USED', used_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [token.id]
      );

      await client.query(
        `INSERT INTO business_events (id, event_type, aggregate_type, aggregate_id, customer_id, redemption_id, payload)
         VALUES ($1, 'CASH_VOUCHER_REDEEMED', 'cash_voucher_claims', $2, $3, $4, $5::jsonb)`,
        [id(), token.cash_voucher_claim_id, customerId, redemptionId, JSON.stringify({ cashValueLyD: Number(token.cash_value_lyd), pointsCost })]
      );

      const responsePayload = {
        ok: true,
        redemptionId,
        pointsDebited: pointsCost,
        cashValueLyD: Number(token.cash_value_lyd),
        merchantId: token.merchant_id || null,
        merchantName: token.merchant_name || null,
        status: 'COMPLETED',
      };

      if (idempotencyKey) {
        await client.query(
          `INSERT INTO redemption_requests (id, actor_user_id, idempotency_key, request_type, status, response_json)
           VALUES ($1, $2, $3, 'CASH_VALUE_REDEMPTION', 'COMPLETED', $4::jsonb)
           ON CONFLICT (actor_user_id, idempotency_key) DO NOTHING`,
          [id(), req.user.userId, idempotencyKey, JSON.stringify(responsePayload)]
        );
      }

      await client.query('COMMIT');
      return res.json(responsePayload);
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'redeem_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.get('/api/merchant/wallet/pending-points', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const { rows: [summary] } = await pool.query(`
      SELECT COALESCE(SUM(points_remaining), 0)::int AS total_points,
             COUNT(DISTINCT customer_id)::int AS customer_count
        FROM customer_pending_points
       WHERE merchant_id = $1 AND status IN ('PENDING', 'PARTIALLY_CLEARED')
    `, [merchantId]);
    res.json({ total_points: Number(summary?.total_points || 0), customer_count: Number(summary?.customer_count || 0) });
  });

  // ── Brand network participation ─────────────────────────────────────────────
  app.get('/api/brand/coalitions', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_profile_required' });

    const { rows } = await pool.query(`
      SELECT c.id, c.name, c.type, c.category, c.region, c.is_active,
             (SELECT COUNT(*) FROM coalition_members WHERE coalition_id = c.id)
             + (SELECT COUNT(*) FROM brand_coalition_members WHERE coalition_id = c.id) AS member_count,
             EXISTS (SELECT 1 FROM brand_coalition_members WHERE coalition_id = c.id AND brand_id = $1) AS is_member
        FROM coalitions c
       WHERE c.is_active = TRUE AND c.type != 'private'
       ORDER BY member_count DESC, c.created_at DESC
    `, [brandId]);
    res.json({ coalitions: rows });
  });

  app.post('/api/brand/coalitions/:id/join', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_profile_required' });
    return res.status(409).json({
      error: 'public_coalition_membership_workflow_required',
      requestEndpoint: '/api/public-coalition/membership/request',
    });
  });

  app.get('/api/brand/coalitions/clearinghouse', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_profile_required' });

    const { rows } = await pool.query(`
      SELECT rc.id AS claim_id, rc.points_cost, rc.status, rc.settlement_id,
             rc.created_at, rc.redeemed_at,
             COALESCE(cp.merchant_id, owner_mp.id) AS merchant_id,
             COALESCE(cp_mp.business_name, owner_mp.business_name, 'Unknown merchant') AS merchant_name
        FROM reward_claims rc
        LEFT JOIN cashier_profiles cp ON cp.user_id = rc.redeemed_by AND cp.is_active = TRUE
        LEFT JOIN merchant_profiles cp_mp ON cp_mp.id = cp.merchant_id
        LEFT JOIN merchant_profiles owner_mp ON owner_mp.user_id = rc.redeemed_by
       WHERE rc.source_type = 'brand' AND rc.source_id = $1
       ORDER BY rc.created_at DESC
       LIMIT 200
    `, [brandId]);
    const disputes = (await pool.query(
      `SELECT d.id, d.claim_id, d.merchant_id, mp.business_name AS merchant_name,
              d.reason, d.status, d.response_note, d.created_at, d.resolved_at
         FROM brand_settlement_disputes d
         LEFT JOIN merchant_profiles mp ON mp.id = d.merchant_id
        WHERE d.brand_id = $1 ORDER BY d.created_at DESC`,
      [brandId]
    )).rows;
    const summary = new Map();
    for (const row of rows) {
      const key = row.merchant_id || 'pending';
      const item = summary.get(key) || {merchant_id: row.merchant_id, merchant_name: row.merchant_name, total_points: 0, redeemed_claims: 0, pending_claims: 0, statement_type: 'brand_reward_settlement'};
      if (row.status === 'redeemed') {
        item.total_points += Number(row.points_cost || 0);
        item.redeemed_claims += 1;
      } else if (row.status === 'pending_pickup') {
        item.pending_claims += 1;
      }
      summary.set(key, item);
    }
    res.json({
      statements: Array.from(summary.values()),
      ledger: rows.map((row) => ({
        claimId: row.claim_id,
        merchantId: row.merchant_id,
        merchantName: row.merchant_name,
        points: Number(row.points_cost || 0),
        status: row.status,
        settlementId: row.settlement_id,
        createdAt: toIso(row.created_at),
        redeemedAt: toIso(row.redeemed_at),
      })),
      disputes: disputes.map((row) => ({id: row.id, claimId: row.claim_id, merchantId: row.merchant_id, merchantName: row.merchant_name, reason: row.reason, status: row.status, responseNote: row.response_note, createdAt: toIso(row.created_at), resolvedAt: toIso(row.resolved_at)})),
    });
  });

  app.post('/api/brand/coalitions/clearinghouse/disputes', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({error: 'brand_profile_required'});
    const claimId = String(req.body?.claimId || '').trim();
    const reason = String(req.body?.reason || '').trim();
    if (!claimId || !reason) return res.status(400).json({error: 'claim_and_reason_required'});
    const claim = (await pool.query(
      `SELECT rc.id, COALESCE(cp.merchant_id, owner_mp.id) AS merchant_id
         FROM reward_claims rc
         LEFT JOIN cashier_profiles cp ON cp.user_id = rc.redeemed_by
         LEFT JOIN merchant_profiles owner_mp ON owner_mp.user_id = rc.redeemed_by
        WHERE rc.id = $1 AND rc.source_type = 'brand' AND rc.source_id = $2
          AND rc.status = 'redeemed' AND rc.settlement_id IS NOT NULL`,
      [claimId, brandId]
    )).rows[0];
    if (!claim) return res.status(404).json({error: 'settled_claim_not_found'});
    try {
      const dispute = (await pool.query(
        `INSERT INTO brand_settlement_disputes (id, claim_id, brand_id, merchant_id, reason, created_by_user_id)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
        [id(), claimId, brandId, claim.merchant_id || null, reason, req.user.userId]
      )).rows[0];
      if (claim.merchant_id) {
        const merchantOwner = (await pool.query('SELECT user_id FROM merchant_profiles WHERE id = $1', [claim.merchant_id])).rows[0]?.user_id;
        if (merchantOwner) await insertNotification(pool, merchantOwner, 'brand_settlement_dispute', 'Settlement dispute opened', reason, {disputeId: dispute.id, claimId, targetScreen: 'settlements'});
      }
      return res.status(201).json({ok: true, id: dispute.id, status: dispute.status});
    } catch (error) {
      if (error.code === '23505') return res.status(409).json({error: 'open_dispute_already_exists'});
      return res.status(500).json({error: 'settlement_dispute_failed', details: String(error.message || error)});
    }
  });

  app.post('/api/merchant/coalitions/clearinghouse/disputes/:id/respond', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({error: 'merchant_profile_required'});
    const status = String(req.body?.status || '');
    const note = String(req.body?.note || '').trim();
    if (!['resolved', 'rejected'].includes(status) || !note) return res.status(400).json({error: 'invalid_dispute_response'});
    const dispute = (await pool.query(
      `UPDATE brand_settlement_disputes SET status=$3, response_note=$4, resolved_by_user_id=$5, resolved_at=NOW()
        WHERE id=$1 AND merchant_id=$2 AND status='open' RETURNING id, brand_id, claim_id`,
      [req.params.id, merchantId, status, note, req.user.userId]
    )).rows[0];
    if (!dispute) return res.status(404).json({error: 'open_dispute_not_found'});
    const brandOwner = (await pool.query('SELECT user_id FROM brand_profiles WHERE id = $1', [dispute.brand_id])).rows[0]?.user_id;
    if (brandOwner) await insertNotification(pool, brandOwner, 'brand_settlement_dispute_resolved', 'Settlement dispute updated', note, {disputeId: dispute.id, claimId: dispute.claim_id, targetScreen: 'brand_clearinghouse'});
    return res.json({ok: true, id: dispute.id, status});
  });

  // ── Direct gifting trigger settings ───────────────────────────────────────────
  app.get('/api/merchant/gifts/trigger', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows: [row] } = await pool.query(
      `SELECT id, merchant_id, threshold_points, merchant_name, message_template, is_active, updated_at, created_at
         FROM coalition_gift_triggers
        WHERE merchant_id = $1
        LIMIT 1`,
      [merchantId]
    );

    res.json({ trigger: row || null });
  });

  app.post('/api/merchant/gifts/trigger', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const thresholdPoints = parseInt(String(req.body.thresholdPoints || ''), 10);
    const merchantName = String(req.body.merchantName || '').trim();
    const messageTemplate = String(req.body.messageTemplate || '').trim();

    if (!Number.isFinite(thresholdPoints) || thresholdPoints <= 0) {
      return res.status(400).json({ error: 'threshold_points_invalid' });
    }

    const triggerId = id();
    const { rows: [saved] } = await pool.query(
      `INSERT INTO coalition_gift_triggers (id, merchant_id, threshold_points, merchant_name, message_template, is_active, updated_at)
       VALUES ($1, $2, $3, $4, $5, TRUE, NOW())
       ON CONFLICT (merchant_id)
       DO UPDATE SET
         threshold_points = EXCLUDED.threshold_points,
         merchant_name = EXCLUDED.merchant_name,
         message_template = EXCLUDED.message_template,
         is_active = TRUE,
         updated_at = NOW()
       RETURNING id, merchant_id, threshold_points, merchant_name, message_template, is_active, updated_at, created_at`,
      [triggerId, merchantId, thresholdPoints, merchantName || null, messageTemplate || null]
    );

    res.status(201).json({
      ok: true,
      trigger: saved,
    });
  });

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

  // ── Suggested merchants for private coalition invites ────────────────────────
  app.get('/api/merchant/coalitions/suggestions', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const activityFilterRaw = String(req.query.activity_filter || 'all').trim().toLowerCase();
    const activityFilter = ['all', 'same', 'different'].includes(activityFilterRaw)
      ? activityFilterRaw
      : 'all';
    const radiusKmRaw = Number(req.query.radius_km);
    const radiusKm = Number.isFinite(radiusKmRaw)
      ? Math.max(1, Math.min(500, radiusKmRaw))
      : 50;
    const limitRaw = parseInt(String(req.query.limit || '20'), 10);
    const limit = Number.isFinite(limitRaw)
      ? Math.max(1, Math.min(50, limitRaw))
      : 20;

    const params = [merchantId, radiusKm, limit];
    const activitySql = activityFilter === 'same'
      ? `AND base.my_activity != '' AND base.activity_category != '' AND base.activity_category = base.my_activity`
      : activityFilter === 'different'
        ? `AND base.my_activity != '' AND base.activity_category != '' AND base.activity_category != base.my_activity`
        : '';

    const { rows } = await pool.query(`
      WITH my_profile AS (
        SELECT mp.id,
               mp.location_lat AS my_lat,
               mp.location_lng AS my_lng,
               COALESCE(my_cat.category, '') AS my_activity
          FROM merchant_profiles mp
          LEFT JOIN LATERAL (
            SELECT LOWER(TRIM(o.category)) AS category, COUNT(*) AS usage_count
              FROM offers o
             WHERE o.owner_id = mp.id
               AND o.category IS NOT NULL
               AND TRIM(o.category) != ''
             GROUP BY LOWER(TRIM(o.category))
             ORDER BY usage_count DESC
             LIMIT 1
          ) my_cat ON TRUE
         WHERE mp.id = $1
         LIMIT 1
      ),
      base AS (
        SELECT mp.id,
               mp.business_name,
               mp.location_address,
               mp.location_lat,
               mp.location_lng,
               u.city,
               COALESCE(cat.category, '') AS activity_category,
               my.my_activity,
               CASE
                 WHEN my.my_lat IS NULL OR my.my_lng IS NULL
                   OR mp.location_lat IS NULL OR mp.location_lng IS NULL
                 THEN NULL
                 ELSE 6371 * ACOS(
                   LEAST(1, GREATEST(-1,
                     COS(RADIANS(my.my_lat))
                     * COS(RADIANS(mp.location_lat))
                     * COS(RADIANS(mp.location_lng) - RADIANS(my.my_lng))
                     + SIN(RADIANS(my.my_lat)) * SIN(RADIANS(mp.location_lat))
                   ))
                 )
               END AS distance_km
          FROM merchant_profiles mp
          JOIN users u ON u.id = mp.user_id
          CROSS JOIN my_profile my
          LEFT JOIN LATERAL (
            SELECT LOWER(TRIM(o.category)) AS category, COUNT(*) AS usage_count
              FROM offers o
             WHERE o.owner_id = mp.id
               AND o.category IS NOT NULL
               AND TRIM(o.category) != ''
             GROUP BY LOWER(TRIM(o.category))
             ORDER BY usage_count DESC
             LIMIT 1
          ) cat ON TRUE
         WHERE mp.id != $1
           AND mp.status = 'active'
      )
      SELECT base.id,
             base.business_name,
             base.location_address,
             base.city,
             base.activity_category,
             base.my_activity,
             base.distance_km,
             (base.my_activity != ''
               AND base.activity_category != ''
               AND base.my_activity = base.activity_category) AS same_activity
        FROM base
       WHERE (base.distance_km IS NULL OR base.distance_km <= $2)
         ${activitySql}
       ORDER BY
         CASE WHEN (base.my_activity != '' AND base.my_activity = base.activity_category) THEN 0 ELSE 1 END,
         base.distance_km NULLS LAST,
         base.business_name ASC
       LIMIT $3
    `, params);

    res.json({
      suggestions: rows,
      filter: activityFilter,
      radius_km: radiusKm,
      limit,
    });
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
    if (coalition.type !== 'private') {
      return res.status(409).json({
        error: 'public_coalition_membership_workflow_required',
        requestEndpoint: '/api/public-coalition/membership/request',
      });
    }
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

  app.post('/api/merchant/coalitions/invitations/:invitationId/accept', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows: [invitation] } = await pool.query(`
      SELECT coalition_id FROM coalition_invitations
       WHERE id = $1 AND invited_merchant_id = $2 AND status = 'pending'
    `, [req.params.invitationId, merchantId]);

    if (!invitation) return res.status(404).json({ error: 'invitation_not_found' });

    await pool.query(
      `UPDATE coalition_invitations SET status = 'accepted', responded_at = NOW() WHERE id = $1`,
      [req.params.invitationId]
    );

    await pool.query(
      `INSERT INTO coalition_members (coalition_id, merchant_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [invitation.coalition_id, merchantId]
    );

    res.json({ ok: true, coalition_id: invitation.coalition_id });
  });

  app.post('/api/merchant/coalitions/invitations/:invitationId/reject', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rowCount } = await pool.query(`
      UPDATE coalition_invitations
         SET status = 'rejected', responded_at = NOW()
       WHERE id = $1 AND invited_merchant_id = $2 AND status = 'pending'
    `, [req.params.invitationId, merchantId]);

    res.json({ ok: true, updated: rowCount });
  });

  app.post('/api/merchant/coalitions/:id/reject-invite', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rowCount } = await pool.query(`
      UPDATE coalition_invitations
         SET status = 'rejected', responded_at = NOW()
       WHERE coalition_id = $1 AND invited_merchant_id = $2 AND status = 'pending'
    `, [req.params.id, merchantId]);

    res.json({ ok: true, updated: rowCount });
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
  const getMerchantClearinghouse = async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const type = String(req.query?.type || '').trim().toLowerCase(); // 'gold' | 'silver' | '' (legacy)
    const coalitionId = String(req.query?.coalition_id || '').trim();

    // Silver (local) coalitions the merchant belongs to — powers the UI selector.
    const silverCoalitions = (await pool.query(`
      SELECT c.id, c.name
        FROM coalition_members cm
        JOIN coalitions c ON c.id = cm.coalition_id
       WHERE cm.merchant_id = $1 AND c.type <> 'public' AND c.is_active = TRUE
       ORDER BY c.name ASC
    `, [merchantId])).rows;

    const disputes = (await pool.query(
      `SELECT d.id, d.claim_id, d.brand_id, bp.business_name AS brand_name,
              d.reason, d.status, d.response_note, d.created_at, d.resolved_at
         FROM brand_settlement_disputes d
         LEFT JOIN brand_profiles bp ON bp.id = d.brand_id
        WHERE d.merchant_id = $1 ORDER BY d.created_at DESC`,
      [merchantId]
    )).rows;
    const disputesJson = disputes.map((row) => ({
      id: row.id, claimId: row.claim_id, brandId: row.brand_id,
      brandName: row.brand_name, reason: row.reason, status: row.status,
      responseNote: row.response_note, createdAt: toIso(row.created_at), resolvedAt: toIso(row.resolved_at),
    }));

    // ── Gold global coalition: instant prepaid settlements (no P2P matrix) ─────
    if (type === 'gold') {
      const instantLedger = (await pool.query(`
        SELECT id, reference, type, amount, balance_after, created_at
          FROM merchant_settlement_ledger
         WHERE merchant_id = $1
         ORDER BY created_at DESC LIMIT 200
      `, [merchantId])).rows;

      const { rows: [wallet] } = await pool.query(
        `SELECT settled_balance FROM merchant_settlement_wallets WHERE merchant_id = $1`,
        [merchantId]
      );
      const { rows: [issuedRow] } = await pool.query(
        `SELECT COALESCE(SUM(amount), 0) AS issued
           FROM merchant_token_ledger
          WHERE merchant_id = $1 AND type = 'ISSUANCE_GOLD'`,
        [merchantId]
      );

      const redeemedPoints = instantLedger
        .filter((row) => row.type === 'GOLD_REDEMPTION_SETTLED')
        .reduce((total, row) => total + Number(row.amount || 0), 0);
      const withdrawnPoints = instantLedger
        .filter((row) => row.type !== 'GOLD_REDEMPTION_SETTLED')
        .reduce((total, row) => total + Number(row.amount || 0), 0);

      return res.json({
        mode: 'gold',
        summary: {
          issuedPoints: Number(issuedRow?.issued || 0),
          redeemedPoints,
          withdrawnPoints,
          netBalance: Number(wallet?.settled_balance || 0), // ready for withdrawal
          pointValue: 1,
        },
        instantSettlements: instantLedger.map((row) => ({
          id: row.id,
          reference: row.reference,
          type: row.type,
          amount: Number(row.amount || 0),
          balance_after: Number(row.balance_after || 0),
          created_at: toIso(row.created_at),
        })),
        memberSettlements: [],
        matrix: [],
        settlementHistory: [],
        statements: [],
        silverCoalitions,
        disputes: disputesJson,
      });
    }

    // ── Silver local coalitions: P2P net clearing ──────────────────────────────
    const params = [merchantId];
    let coalitionFilter = '';
    if (type === 'silver' && coalitionId) {
      const { rowCount } = await pool.query(
        `SELECT 1 FROM coalition_members WHERE coalition_id = $1 AND merchant_id = $2`,
        [coalitionId, merchantId]
      );
      if (rowCount === 0) return res.status(403).json({ error: 'not_a_coalition_member' });
      coalitionFilter = 'AND cc.coalition_id = $2';
      params.push(coalitionId);
    } else if (type === 'silver') {
      coalitionFilter = `AND cc.coalition_id IN (SELECT id FROM coalitions WHERE type <> 'public')`;
    }

    const { rows } = await pool.query(`
      SELECT cc.id, cc.period, cc.coalition_id, c.name AS coalition_name,
             cc.from_merchant_id, fm.business_name AS from_merchant,
             cc.to_merchant_id, tm.business_name AS to_merchant,
             cc.total_points, cc.settled, cc.settled_at
        FROM coalition_clearinghouse cc
        JOIN coalitions c ON c.id = cc.coalition_id
        JOIN merchant_profiles fm ON fm.id = cc.from_merchant_id
        JOIN merchant_profiles tm ON tm.id = cc.to_merchant_id
       WHERE (cc.from_merchant_id = $1 OR cc.to_merchant_id = $1) ${coalitionFilter}
       ORDER BY cc.period DESC, cc.total_points DESC
    `, params);

    const issuedPoints = rows.reduce((total, row) =>
      total + (row.from_merchant_id === merchantId ? Number(row.total_points || 0) : 0), 0);
    const redeemedPoints = rows.reduce((total, row) =>
      total + (row.to_merchant_id === merchantId ? Number(row.total_points || 0) : 0), 0);
    const memberSettlements = rows.map((row) => {
      const isIssuer = row.from_merchant_id === merchantId;
      const points = Number(row.total_points || 0);
      return {
        ...row,
        partner_merchant_id: isIssuer ? row.to_merchant_id : row.from_merchant_id,
        partner_merchant: isIssuer ? row.to_merchant : row.from_merchant,
        exchanged_points: points,
        net_amount: isIssuer ? -points : points,
        status: row.settled ? 'completed' : 'pending',
      };
    });
    const matrixByPartner = new Map();
    for (const settlement of memberSettlements) {
      const key = `${settlement.coalition_id}:${settlement.partner_merchant_id}`;
      const current = matrixByPartner.get(key) || {
        coalitionId: settlement.coalition_id,
        coalitionName: settlement.coalition_name,
        partnerMerchantId: settlement.partner_merchant_id,
        partnerMerchant: settlement.partner_merchant,
        netBalance: 0,
      };
      current.netBalance += Number(settlement.net_amount || 0);
      matrixByPartner.set(key, current);
    }

    res.json({
      mode: 'silver',
      summary: {
        issuedPoints,
        redeemedPoints,
        netBalance: redeemedPoints - issuedPoints,
        pointValue: 1,
      },
      memberSettlements,
      matrix: Array.from(matrixByPartner.values()),
      settlementHistory: memberSettlements.filter((row) => row.settled),
      statements: rows,
      silverCoalitions,
      selectedCoalitionId: type === 'silver' && coalitionId ? coalitionId : null,
      disputes: disputesJson,
    });
  };
  app.get('/api/merchant/coalitions/clearinghouse', auth, getMerchantClearinghouse);
  app.get('/api/merchant/coalition/clearing', auth, getMerchantClearinghouse);

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

    if (rowCount === 0) return res.status(409).json({ error: 'clearinghouse_already_settled_or_not_found' });
    res.json({ ok: true, updated: rowCount, execution: 'internal_accounting_only', externalTransferExecuted: false });
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

  // ──────────────────────────────────────────────────────────────────────────────
  // ── SHARED COALITION GIFT CATALOG (Multi-Sponsor Pro-Rata System) ────────────
  // ──────────────────────────────────────────────────────────────────────────────

  // ── Create shared gift in coalition catalog ───────────────────────────────────
  app.post('/api/merchant/coalitions/:id/gifts', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const {
      title,
      description,
      image_url,
      required_points,
      monetary_value,
      campaign_type = 'standard',
      discount_percentage = 0,
      quantity_limit,
      expires_at,
      target_new_customers = false,
      target_vip_customers = false,
      min_purchase_frequency,
      max_days_since_last_visit,
    } = req.body;

    if (!title?.trim()) return res.status(400).json({ error: 'title_required' });
    if (!required_points || required_points <= 0) return res.status(400).json({ error: 'required_points_invalid' });

    // Verify merchant is member of this coalition
    const { rows: [membership] } = await pool.query(
      `SELECT 1 FROM coalition_members WHERE coalition_id = $1 AND merchant_id = $2`,
      [req.params.id, merchantId]
    );
    if (!membership) return res.status(403).json({ error: 'not_coalition_member' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const giftId = id();
      await client.query(`
        INSERT INTO coalition_gift_catalog (
          id, coalition_id, created_by_merchant_id, title, description, image_url,
          required_points, monetary_value, campaign_type, discount_percentage,
          quantity_limit, expires_at, is_active
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, TRUE)
      `, [
        giftId, req.params.id, merchantId, title.trim(), description || null, image_url || null,
        required_points, monetary_value || null, campaign_type, discount_percentage || 0,
        quantity_limit || null, expires_at || null
      ]);

      // Add targeting rules if specified
      if (target_new_customers || target_vip_customers || min_purchase_frequency || max_days_since_last_visit) {
        await client.query(`
          INSERT INTO coalition_gift_targeting (
            gift_catalog_id, target_new_customers, target_vip_customers,
            min_purchase_frequency, max_days_since_last_visit
          ) VALUES ($1, $2, $3, $4, $5)
        `, [giftId, target_new_customers, target_vip_customers, min_purchase_frequency || null, max_days_since_last_visit || null]);
      }

      await client.query('COMMIT');
      res.status(201).json({ gift_id: giftId, ok: true });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  });

  // ── Get coalition gift catalog ────────────────────────────────────────────────
  app.get('/api/merchant/coalitions/:id/gifts', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows } = await pool.query(`
      SELECT 
        g.id, g.coalition_id, g.created_by_merchant_id, mp.business_name AS creator_name,
        g.title, g.description, g.image_url, g.required_points, g.monetary_value,
        g.campaign_type, g.discount_percentage, g.quantity_limit, g.quantity_redeemed,
        g.expires_at, g.is_active, g.created_at,
        t.target_new_customers, t.target_vip_customers, t.min_purchase_frequency, t.max_days_since_last_visit
      FROM coalition_gift_catalog g
      JOIN merchant_profiles mp ON mp.id = g.created_by_merchant_id
      LEFT JOIN coalition_gift_targeting t ON t.gift_catalog_id = g.id
      WHERE g.coalition_id = $1 AND g.is_active = TRUE
      ORDER BY g.created_at DESC
    `, [req.params.id]);

    res.json({ gifts: rows });
  });

  app.get('/api/customer/coalitions/mine', auth, async (req, res) => {
    const userId = req.user.userId;
    const { rows } = await pool.query(`
      SELECT c.id, c.name, c.type,
             COALESCE(SUM(b.points_balance), 0)::int AS total_points,
             COUNT(DISTINCT b.merchant_id)::int AS merchant_count
        FROM customer_merchant_point_balances b
        JOIN coalitions c ON c.id = b.coalition_id
       WHERE b.customer_id = $1 AND b.points_balance > 0 AND c.is_active = TRUE
       GROUP BY c.id, c.name, c.type
       ORDER BY total_points DESC, c.name ASC
    `, [userId]);
    res.json({ coalitions: rows });
  });

  // ── Get customer's point balances across coalition merchants ──────────────────
  app.get('/api/customer/coalitions/:id/balances', auth, async (req, res) => {
    const userId = req.user.userId;

    const { rows } = await pool.query(`
      SELECT 
        b.merchant_id, mp.business_name AS merchant_name,
        b.points_balance AS points, b.last_updated
      FROM customer_merchant_point_balances b
      JOIN merchant_profiles mp ON mp.id = b.merchant_id
      WHERE b.customer_id = $1 AND b.coalition_id = $2 AND b.points_balance > 0
      ORDER BY b.points_balance DESC
    `, [userId, req.params.id]);

    const total = rows.reduce((sum, row) => sum + (row.points || 0), 0);

    res.json({ balances: rows, total_points: total });
  });

  // ── Redeem coalition gift with pro-rata settlement ────────────────────────────
  app.post('/api/customer/coalitions/redeem-gift', auth, async (req, res) => {
    const userId = req.user.userId;
    const { gift_id, fulfiller_merchant_id } = req.body;

    if (!gift_id) return res.status(400).json({ error: 'gift_id_required' });
    if (!fulfiller_merchant_id) return res.status(400).json({ error: 'fulfiller_merchant_id_required' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Get gift details
      const { rows: [gift] } = await client.query(
        `SELECT g.*, c.type AS coalition_type
           FROM coalition_gift_catalog g
           JOIN coalitions c ON c.id = g.coalition_id
          WHERE g.id = $1 AND g.is_active = TRUE FOR UPDATE`,
        [gift_id]
      );

      if (!gift) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'gift_not_found' });
      }

      // Check quantity limit
      if (gift.quantity_limit && gift.quantity_redeemed >= gift.quantity_limit) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'gift_out_of_stock' });
      }

      // Check expiration
      if (gift.expires_at && new Date(gift.expires_at) < new Date()) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'gift_expired' });
      }

      // Get customer point balances across coalition merchants
      const { rows: balances } = await client.query(`
        SELECT b.merchant_id, mp.business_name AS merchant_name, b.points_balance AS points
        FROM customer_merchant_point_balances b
        JOIN merchant_profiles mp ON mp.id = b.merchant_id
        WHERE b.customer_id = $1 AND b.coalition_id = $2 AND b.points_balance > 0
        FOR UPDATE
      `, [userId, gift.coalition_id]);

      // Calculate pro-rata split
      let splits;
      try {
        splits = pointValuation.calculateProRataSplit(
          balances.map(b => ({ merchantId: b.merchant_id, merchantName: b.merchant_name, points: b.points })),
          gift.required_points
        );
      } catch (error) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: error.message });
      }

      const pointAccount = (await client.query(
        `SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE`, [userId]
      )).rows[0];
      if (!pointAccount || Number(pointAccount.available_points || 0) < gift.required_points) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'insufficient_points' });
      }

      // Create redemption record
      const redemptionId = id();
      await client.query(`
        INSERT INTO coalition_redemption_splits (
          id, gift_catalog_id, customer_id, fulfiller_merchant_id, total_points_used, redeemed_at
        ) VALUES ($1, $2, $3, $4, $5, NOW())
      `, [redemptionId, gift_id, userId, fulfiller_merchant_id, gift.required_points]);

      // Record each merchant's contribution
      for (const split of splits) {
        const contributionId = id();
        await client.query(`
          INSERT INTO coalition_redemption_contributions (
            id, redemption_split_id, contributor_merchant_id, points_contributed, contribution_percentage
          ) VALUES ($1, $2, $3, $4, $5)
        `, [contributionId, redemptionId, split.merchantId, split.pointsUsed, split.percentage]);

        // Deduct points from merchant balance
        await client.query(`
          UPDATE customer_merchant_point_balances
          SET points_balance = points_balance - $1, last_updated = NOW()
          WHERE customer_id = $2 AND merchant_id = $3 AND coalition_id = $4
        `, [split.pointsUsed, userId, split.merchantId, gift.coalition_id]);

        const tier = gift.coalition_type === 'public' ? 'gold' : 'silver';
        const tierDebit = await client.query(`
          UPDATE customer_point_tiers
             SET balance = balance - $1, updated_at = NOW()
           WHERE customer_id = $2 AND tier = $3 AND merchant_id = $5
             AND coalition_id IS NOT DISTINCT FROM $4
             AND balance >= $1
        `, [split.pointsUsed, userId, tier, tier === 'gold' ? null : gift.coalition_id, split.merchantId]);
        if (tierDebit.rowCount < 1) {
          await client.query('ROLLBACK');
          return res.status(409).json({ error: 'tier_balance_mismatch' });
        }

        // Record in coalition ledger for clearinghouse
        if (split.merchantId !== fulfiller_merchant_id) {
          const ledgerId = id();
          await client.query(`
            INSERT INTO coalition_ledger (
              id, coalition_id, from_merchant_id, to_merchant_id, customer_id,
              points_redeemed, conversion_rate, net_points
            ) VALUES ($1, $2, $3, $4, $5, $6, 1.0, $6)
          `, [ledgerId, gift.coalition_id, split.merchantId, fulfiller_merchant_id, userId, split.pointsUsed]);
        }
      }

      // Update gift redemption count
      await client.query(
        `UPDATE coalition_gift_catalog SET quantity_redeemed = quantity_redeemed + 1 WHERE id = $1`,
        [gift_id]
      );
      await client.query(
        `UPDATE point_accounts SET available_points = available_points - $2, updated_at = NOW() WHERE owner_id = $1`,
        [userId, gift.required_points]
      );

      // Send co-branded notification to customer
      const coBrandedMessage = pointValuation.formatCoBrandedMessage(splits);
      await insertNotification(pool, userId, 'gift_redeemed', gift.title, coBrandedMessage, 'rewards', {
        giftId: gift_id,
        redemptionId,
        sponsors: splits,
      });

      await client.query('COMMIT');

      res.status(200).json({
        ok: true,
        redemption_id: redemptionId,
        gift_title: gift.title,
        total_points_used: gift.required_points,
        sponsors: splits,
        co_branded_message: coBrandedMessage,
      });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  });

  // ── Get merchant's coalition gift impact report ───────────────────────────────
  app.get('/api/merchant/coalitions/:id/gift-impact', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });

    const { rows: asContributor } = await pool.query(`
      SELECT 
        COUNT(DISTINCT rs.customer_id) AS unique_customers,
        SUM(rc.points_contributed) AS total_points_contributed,
        AVG(rc.contribution_percentage) AS avg_contribution_percentage
      FROM coalition_redemption_contributions rc
      JOIN coalition_redemption_splits rs ON rs.id = rc.redemption_split_id
      JOIN coalition_gift_catalog g ON g.id = rs.gift_catalog_id
      WHERE rc.contributor_merchant_id = $1 AND g.coalition_id = $2
    `, [merchantId, req.params.id]);

    const { rows: asFulfiller } = await pool.query(`
      SELECT 
        COUNT(DISTINCT rs.customer_id) AS unique_customers,
        SUM(rs.total_points_used) AS total_points_received
      FROM coalition_redemption_splits rs
      JOIN coalition_gift_catalog g ON g.id = rs.gift_catalog_id
      WHERE rs.fulfiller_merchant_id = $1 AND g.coalition_id = $2
    `, [merchantId, req.params.id]);

    const { rows: crossCustomers } = await pool.query(`
      SELECT DISTINCT
        u.id AS customer_id,
        u.full_name AS customer_name,
        g.title AS gift_title,
        rs.total_points_used,
        rc.points_contributed,
        rc.contribution_percentage,
        rs.redeemed_at
      FROM coalition_redemption_contributions rc
      JOIN coalition_redemption_splits rs ON rs.id = rc.redemption_split_id
      JOIN coalition_gift_catalog g ON g.id = rs.gift_catalog_id
      JOIN users u ON u.id = rs.customer_id
      WHERE rc.contributor_merchant_id = $1 
        AND rs.fulfiller_merchant_id != $1
        AND g.coalition_id = $2
      ORDER BY rs.redeemed_at DESC
      LIMIT 50
    `, [merchantId, req.params.id]);

    res.json({
      as_contributor: asContributor[0],
      as_fulfiller: asFulfiller[0],
      recent_cross_coalition_customers: crossCustomers,
    });
  });
};
