module.exports = function registerBrandTeamRoutes(app, deps) {
  const {pool, auth, id, toIso, getBrandProfileIdByUser, insertNotification} = deps;

  function permissions(raw) {
    return {
      canManageProducts: raw?.canManageProducts === true,
      canViewGeoDistribution: raw?.canViewGeoDistribution === true,
    };
  }

  app.post('/api/brand/team/invitations', auth, async (req, res) => {
    const identifier = String(req.body?.emailOrPhone || '').trim().toLowerCase();
    if (!identifier) return res.status(400).json({error: 'team_identifier_required'});
    const client = await pool.connect();
    try {
      const brandId = await getBrandProfileIdByUser(client, req.user.userId);
      if (!brandId) return res.status(403).json({error: 'brand_owner_required'});
      const user = (await client.query(
        'SELECT id, email, phone, full_name FROM users WHERE lower(email) = $1 OR phone = $2 LIMIT 1',
        [identifier, identifier]
      )).rows[0];
      if (!user) return res.status(404).json({error: 'team_user_not_found'});
      if (user.id === req.user.userId) return res.status(400).json({error: 'cannot_invite_self'});
      const existing = (await client.query(
        "SELECT id, status FROM brand_team_invitations WHERE brand_id = $1 AND invited_user_id = $2 AND status = 'pending' LIMIT 1",
        [brandId, user.id]
      )).rows[0];
      if (existing) return res.json(existing);
      const invitation = (await client.query(
        `INSERT INTO brand_team_invitations (id, brand_id, invited_user_id, invited_by_user_id, permissions)
         VALUES ($1,$2,$3,$4,$5::jsonb) RETURNING *`,
        [id(), brandId, user.id, req.user.userId, JSON.stringify(permissions(req.body?.permissions))]
      )).rows[0];
      await insertNotification(client, user.id, 'brand_team_invitation', 'Brand team invitation', 'You were invited to join a brand team.', {invitationId: invitation.id, targetScreen: 'brand_team_invitations'});
      return res.status(201).json({...invitation, permissions: invitation.permissions || {}, createdAt: toIso(invitation.created_at)});
    } catch (error) {
      return res.status(500).json({error: 'brand_team_invitation_failed', details: String(error.message || error)});
    } finally {
      client.release();
    }
  });

  app.get('/api/brand/team', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({error: 'brand_owner_required'});
    const members = (await pool.query(
      `SELECT m.user_id, m.can_manage_products, m.can_view_geo_distribution, m.created_at,
              u.full_name, u.email, u.phone
         FROM brand_team_members m JOIN users u ON u.id = m.user_id
        WHERE m.brand_id = $1 ORDER BY m.created_at`,
      [brandId]
    )).rows;
    const invitations = (await pool.query(
      `SELECT i.*, u.full_name, u.email, u.phone
         FROM brand_team_invitations i JOIN users u ON u.id = i.invited_user_id
        WHERE i.brand_id = $1 AND i.status = 'pending' ORDER BY i.created_at DESC`,
      [brandId]
    )).rows;
    return res.json({
      members: members.map((row) => ({userId: row.user_id, name: row.full_name, email: row.email, phone: row.phone, canManageProducts: row.can_manage_products === true, canViewGeoDistribution: row.can_view_geo_distribution === true, createdAt: toIso(row.created_at)})),
      invitations: invitations.map((row) => ({id: row.id, invitedUserId: row.invited_user_id, name: row.full_name, email: row.email, phone: row.phone, permissions: row.permissions || {}, status: row.status, createdAt: toIso(row.created_at)})),
    });
  });

  app.get('/api/brand/team/invitations/mine', auth, async (req, res) => {
    const rows = (await pool.query(
      `SELECT i.*, b.business_name AS brand_name
         FROM brand_team_invitations i JOIN brand_profiles b ON b.id = i.brand_id
        WHERE i.invited_user_id = $1 AND i.status = 'pending' ORDER BY i.created_at DESC`,
      [req.user.userId]
    )).rows;
    return res.json(rows.map((row) => ({id: row.id, brandId: row.brand_id, brandName: row.brand_name, permissions: row.permissions || {}, status: row.status, createdAt: toIso(row.created_at)})));
  });

  app.post('/api/brand/team/invitations/:id/respond', auth, async (req, res) => {
    const action = String(req.body?.action || '').toLowerCase();
    if (!['accept', 'reject'].includes(action)) return res.status(400).json({error: 'invalid_invitation_action'});
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const invitation = (await client.query(
        "SELECT * FROM brand_team_invitations WHERE id = $1 AND invited_user_id = $2 AND status = 'pending' FOR UPDATE",
        [req.params.id, req.user.userId]
      )).rows[0];
      if (!invitation) { await client.query('ROLLBACK'); return res.status(404).json({error: 'team_invitation_not_found'}); }
      if (action === 'accept') {
        const allowed = permissions(invitation.permissions);
        await client.query(
          `INSERT INTO brand_team_members (brand_id, user_id, can_manage_products, can_view_geo_distribution)
           VALUES ($1,$2,$3,$4)
           ON CONFLICT (brand_id, user_id) DO UPDATE SET
             can_manage_products=EXCLUDED.can_manage_products,
             can_view_geo_distribution=EXCLUDED.can_view_geo_distribution`,
          [invitation.brand_id, req.user.userId, allowed.canManageProducts, allowed.canViewGeoDistribution]
        );
      }
      const status = action === 'accept' ? 'accepted' : 'rejected';
      await client.query('UPDATE brand_team_invitations SET status=$2, responded_at=NOW(), updated_at=NOW() WHERE id=$1', [invitation.id, status]);
      await insertNotification(client, invitation.invited_by_user_id, `brand_team_invitation_${status}`, 'Brand team invitation update', `The invitation was ${status}.`, {invitationId: invitation.id, targetScreen: 'brand_team'});
      await client.query('COMMIT');
      return res.json({ok: true, status});
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({error: 'brand_team_invitation_response_failed', details: String(error.message || error)});
    } finally {
      client.release();
    }
  });

  app.delete('/api/brand/team/members/:userId', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({error: 'brand_owner_required'});
    const result = await pool.query('DELETE FROM brand_team_members WHERE brand_id = $1 AND user_id = $2', [brandId, req.params.userId]);
    if (!result.rowCount) return res.status(404).json({error: 'brand_team_member_not_found'});
    await insertNotification(pool, req.params.userId, 'brand_team_access_revoked', 'Brand team access updated', 'Your brand team access was revoked.', {targetScreen: 'team_invitations'});
    return res.json({ok: true, revoked: true});
  });
};
