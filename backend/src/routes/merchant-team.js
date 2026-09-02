module.exports = function registerMerchantTeamRoutes(app, deps) {
  const {
    pool,
    auth,
    id,
    toIso,
    getMerchantProfileIdByUser,
    assertMerchantSubscriptionWritable,
    isMerchantSubscriptionReadOnlyError,
    insertNotification,
  } = deps;

  const permissionKeys = [
    'canReviewInvoices',
    'canCreateOffers',
    'canManageGroup',
    'canViewReports',
    'canViewSettlements',
    'canAddCashiers',
    'canReplyReports',
  ];

  function normalizePermissions(raw) {
    const source = raw && typeof raw === 'object' ? raw : {};
    return Object.fromEntries(permissionKeys.map((key) => [key, source[key] === true]));
  }

  function mapInvitation(row) {
    return {
      id: row.id,
      merchantId: row.merchant_id,
      merchantName: row.merchant_name || null,
      branchId: row.branch_id,
      branchName: row.branch_name || null,
      invitedUserId: row.invited_user_id,
      invitedUserName: row.invited_user_name || null,
      invitedUserEmail: row.invited_user_email || null,
      invitedUserPhone: row.invited_user_phone || null,
      roleType: row.role_type,
      permissions: row.permissions || {},
      status: row.status,
      createdAt: toIso(row.created_at),
      respondedAt: toIso(row.responded_at),
    };
  }

  app.post('/api/merchant/team/invitations', auth, async (req, res) => {
    const branchId = String(req.body?.branchId || '').trim();
    const roleType = String(req.body?.roleType || '').trim().toLowerCase();
    const identifier = String(req.body?.emailOrPhone || '').trim().toLowerCase();
    if (!branchId || !identifier || !['manager', 'cashier'].includes(roleType)) {
      return res.status(400).json({ error: 'invalid_team_invitation' });
    }

    const client = await pool.connect();
    try {
      const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
      if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
      await assertMerchantSubscriptionWritable(client, merchantId);
      const branch = (await client.query(
        "SELECT id, name FROM branches WHERE id = $1 AND merchant_id = $2 AND status = 'active' LIMIT 1",
        [branchId, merchantId]
      )).rows[0];
      if (!branch) return res.status(404).json({ error: 'branch_not_found' });
      const invitedUser = (await client.query(
        'SELECT id, email, phone, full_name FROM users WHERE lower(email) = $1 OR phone = $2 LIMIT 1',
        [identifier, identifier]
      )).rows[0];
      if (!invitedUser) return res.status(404).json({ error: 'team_user_not_found' });
      if (invitedUser.id === req.user.userId) return res.status(400).json({ error: 'cannot_invite_self' });

      const existing = (await client.query(
        `SELECT * FROM merchant_team_invitations
          WHERE branch_id = $1 AND invited_user_id = $2 AND role_type = $3 AND status = 'pending'
          LIMIT 1`,
        [branchId, invitedUser.id, roleType]
      )).rows[0];
      if (existing) return res.json(mapInvitation(existing));

      const invitation = (await client.query(
        `INSERT INTO merchant_team_invitations
          (id, merchant_id, branch_id, invited_user_id, invited_by_user_id, role_type, permissions)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
         RETURNING *`,
        [id(), merchantId, branchId, invitedUser.id, req.user.userId, roleType, JSON.stringify(normalizePermissions(req.body?.permissions))]
      )).rows[0];
      await insertNotification(
        client,
        invitedUser.id,
        'merchant_team_invitation',
        'Store team invitation',
        `You were invited as ${roleType} for ${branch.name}.`,
        { invitationId: invitation.id, roleType, branchId, targetScreen: 'team_invitations' }
      );
      return res.status(201).json(mapInvitation(invitation));
    } catch (error) {
      if (isMerchantSubscriptionReadOnlyError(error)) {
        return res.status(403).json({ error: 'merchant_subscription_read_only' });
      }
      return res.status(500).json({ error: 'team_invitation_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.get('/api/merchant/team', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
      if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
      const managers = (await client.query(
        `SELECT bmp.*, b.name AS branch_name, u.full_name, u.email, u.phone
           FROM branch_manager_permissions bmp
           JOIN branches b ON b.id = bmp.branch_id
           JOIN users u ON u.id = bmp.user_id
          WHERE b.merchant_id = $1 ORDER BY b.name, u.full_name NULLS LAST, u.email`,
        [merchantId]
      )).rows;
      const cashiers = (await client.query(
        `SELECT cp.*, b.name AS branch_name, u.full_name, u.email, u.phone
           FROM cashier_profiles cp
           JOIN branches b ON b.id = cp.branch_id
           JOIN users u ON u.id = cp.user_id
          WHERE cp.merchant_id = $1 ORDER BY b.name, u.full_name NULLS LAST, u.email`,
        [merchantId]
      )).rows;
      const invitations = (await client.query(
        `SELECT i.*, b.name AS branch_name, u.full_name AS invited_user_name,
                u.email AS invited_user_email, u.phone AS invited_user_phone
           FROM merchant_team_invitations i
           JOIN branches b ON b.id = i.branch_id
           JOIN users u ON u.id = i.invited_user_id
          WHERE i.merchant_id = $1 AND i.status = 'pending'
          ORDER BY i.created_at DESC`,
        [merchantId]
      )).rows;
      return res.json({
        managers: managers.map((row) => ({
          userId: row.user_id, name: row.full_name, email: row.email, phone: row.phone,
          branchId: row.branch_id, branchName: row.branch_name,
          permissions: {
            canReviewInvoices: row.can_review_invoices === true,
            canCreateOffers: row.can_create_offers === true,
            canManageGroup: row.can_manage_group === true,
            canViewReports: row.can_view_reports === true,
            canViewSettlements: row.can_view_settlements === true,
            canAddCashiers: row.can_add_cashiers === true,
            canReplyReports: row.can_reply_reports === true,
          },
        })),
        cashiers: cashiers.map((row) => ({
          userId: row.user_id, name: row.full_name, email: row.email, phone: row.phone,
          branchId: row.branch_id, branchName: row.branch_name, isActive: row.is_active === true,
        })),
        invitations: invitations.map(mapInvitation),
      });
    } catch (error) {
      return res.status(500).json({ error: 'merchant_team_list_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.get('/api/team/invitations/mine', auth, async (req, res) => {
    const rows = (await pool.query(
      `SELECT i.*, b.name AS branch_name, mp.business_name AS merchant_name
         FROM merchant_team_invitations i
         JOIN branches b ON b.id = i.branch_id
         JOIN merchant_profiles mp ON mp.id = i.merchant_id
        WHERE i.invited_user_id = $1 AND i.status = 'pending'
        ORDER BY i.created_at DESC`,
      [req.user.userId]
    )).rows;
    return res.json(rows.map(mapInvitation));
  });

  app.post('/api/team/invitations/:id/respond', auth, async (req, res) => {
    const action = String(req.body?.action || '').trim().toLowerCase();
    if (!['accept', 'reject'].includes(action)) return res.status(400).json({ error: 'invalid_invitation_action' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const invitation = (await client.query(
        `SELECT * FROM merchant_team_invitations
          WHERE id = $1 AND invited_user_id = $2 AND status = 'pending' FOR UPDATE`,
        [req.params.id, req.user.userId]
      )).rows[0];
      if (!invitation) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'team_invitation_not_found' });
      }
      if (action === 'accept' && invitation.role_type === 'manager') {
        const permissions = normalizePermissions(invitation.permissions);
        await client.query(
          `INSERT INTO branch_manager_permissions
            (branch_id, user_id, can_review_invoices, can_create_offers, can_manage_group,
             can_view_reports, can_view_settlements, can_add_cashiers, can_reply_reports)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
           ON CONFLICT (branch_id, user_id) DO UPDATE SET
             can_review_invoices=EXCLUDED.can_review_invoices,
             can_create_offers=EXCLUDED.can_create_offers,
             can_manage_group=EXCLUDED.can_manage_group,
             can_view_reports=EXCLUDED.can_view_reports,
             can_view_settlements=EXCLUDED.can_view_settlements,
             can_add_cashiers=EXCLUDED.can_add_cashiers,
             can_reply_reports=EXCLUDED.can_reply_reports`,
          [invitation.branch_id, req.user.userId, ...permissionKeys.map((key) => permissions[key])]
        );
      }
      if (action === 'accept' && invitation.role_type === 'cashier') {
        const existing = (await client.query(
          'SELECT id FROM cashier_profiles WHERE user_id = $1 AND branch_id = $2 LIMIT 1',
          [req.user.userId, invitation.branch_id]
        )).rows[0];
        if (existing) {
          await client.query('UPDATE cashier_profiles SET is_active = TRUE WHERE id = $1', [existing.id]);
        } else {
          await client.query(
            `INSERT INTO cashier_profiles (id, user_id, merchant_id, branch_id, is_active)
             VALUES ($1,$2,$3,$4,TRUE)`,
            [id(), req.user.userId, invitation.merchant_id, invitation.branch_id]
          );
        }
      }
      const status = action === 'accept' ? 'accepted' : 'rejected';
      await client.query(
        `UPDATE merchant_team_invitations SET status = $2, responded_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [invitation.id, status]
      );
      await insertNotification(
        client,
        invitation.invited_by_user_id,
        `merchant_team_invitation_${status}`,
        'Store team invitation update',
        `The ${invitation.role_type} invitation was ${status}.`,
        { invitationId: invitation.id, branchId: invitation.branch_id, targetScreen: 'merchant_team' }
      );
      await client.query('COMMIT');
      return res.json({ ok: true, status, roleType: invitation.role_type });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'team_invitation_response_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.delete('/api/merchant/team/:roleType/:branchId/:userId', auth, async (req, res) => {
    const roleType = String(req.params.roleType || '').toLowerCase();
    if (!['manager', 'cashier'].includes(roleType)) return res.status(400).json({ error: 'invalid_team_role' });
    const client = await pool.connect();
    try {
      const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
      if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
      await assertMerchantSubscriptionWritable(client, merchantId);
      const branch = (await client.query(
        'SELECT id FROM branches WHERE id = $1 AND merchant_id = $2 LIMIT 1',
        [req.params.branchId, merchantId]
      )).rows[0];
      if (!branch) return res.status(404).json({ error: 'branch_not_found' });
      if (roleType === 'manager') {
        await client.query('DELETE FROM branch_manager_permissions WHERE branch_id = $1 AND user_id = $2', [req.params.branchId, req.params.userId]);
      } else {
        await client.query(
          'UPDATE cashier_profiles SET is_active = FALSE WHERE branch_id = $1 AND user_id = $2 AND merchant_id = $3',
          [req.params.branchId, req.params.userId, merchantId]
        );
      }
      await insertNotification(
        client,
        req.params.userId,
        'merchant_team_access_revoked',
        'Store team access updated',
        `Your ${roleType} access for this branch was revoked.`,
        { branchId: req.params.branchId, roleType, targetScreen: 'team_invitations' }
      );
      return res.json({ ok: true, roleType, revoked: true });
    } catch (error) {
      if (isMerchantSubscriptionReadOnlyError(error)) {
        return res.status(403).json({ error: 'merchant_subscription_read_only' });
      }
      return res.status(500).json({ error: 'team_access_revoke_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.delete('/api/merchant/team/invitations/:id', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
      if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
      await assertMerchantSubscriptionWritable(client, merchantId);
      const invitation = (await client.query(
        `UPDATE merchant_team_invitations
            SET status = 'cancelled', updated_at = NOW()
          WHERE id = $1 AND merchant_id = $2 AND status = 'pending'
          RETURNING invited_user_id, branch_id, role_type`,
        [req.params.id, merchantId]
      )).rows[0];
      if (!invitation) return res.status(404).json({ error: 'team_invitation_not_found' });
      await insertNotification(
        client,
        invitation.invited_user_id,
        'merchant_team_invitation_cancelled',
        'Store team invitation cancelled',
        'The store cancelled this team invitation.',
        { invitationId: req.params.id, branchId: invitation.branch_id, roleType: invitation.role_type, targetScreen: 'team_invitations' }
      );
      return res.json({ ok: true, status: 'cancelled' });
    } catch (error) {
      if (isMerchantSubscriptionReadOnlyError(error)) {
        return res.status(403).json({ error: 'merchant_subscription_read_only' });
      }
      return res.status(500).json({ error: 'team_invitation_cancel_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });
};