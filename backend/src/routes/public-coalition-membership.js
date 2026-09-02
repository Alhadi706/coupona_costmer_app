module.exports = function registerPublicCoalitionMembershipRoutes(app, deps) {
  const {
    pool,
    auth,
    requireAdmin,
    id,
    toIso,
    getMerchantProfileIdByUser,
    getBrandProfileIdByUser,
    insertNotification,
  } = deps;

  const PUBLIC_COALITION_ID = 'public-platform-coalition';

  async function resolveApplicant(userId, requestedType) {
    const applicantType = String(requestedType || '').trim().toLowerCase();
    if (!['merchant', 'brand'].includes(applicantType)) return null;
    const profileId = applicantType === 'merchant'
      ? await getMerchantProfileIdByUser(pool, userId)
      : await getBrandProfileIdByUser(pool, userId);
    return profileId ? { applicantType, profileId } : null;
  }

  function mapRequest(row) {
    return {
      id: row.id,
      applicantType: row.applicant_type,
      applicantProfileId: row.applicant_profile_id,
      applicantUserId: row.applicant_user_id,
      applicantName: row.applicant_name || null,
      applicantEmail: row.applicant_email || null,
      status: row.status,
      adminMessage: row.admin_message || null,
      paymentUrl: row.payment_url || null,
      paymentReference: row.payment_reference || null,
      activationSource: row.activation_source || null,
      rejectionReason: row.rejection_reason || null,
      createdAt: toIso(row.created_at),
      reviewedAt: toIso(row.reviewed_at),
      activatedAt: toIso(row.activated_at),
      updatedAt: toIso(row.updated_at),
    };
  }

  app.post('/api/public-coalition/membership/request', auth, async (req, res) => {
    const applicant = await resolveApplicant(req.user.userId, req.body?.applicantType);
    if (!applicant) return res.status(403).json({ error: 'eligible_merchant_or_brand_role_required' });

    const existing = (await pool.query(
      `SELECT * FROM public_coalition_membership_requests
        WHERE applicant_type = $1 AND applicant_profile_id = $2
          AND status IN ('pending_admin_review', 'approved_pending_payment', 'active')
        ORDER BY created_at DESC LIMIT 1`,
      [applicant.applicantType, applicant.profileId]
    )).rows[0];
    if (existing) return res.json(mapRequest(existing));

    const requestId = id();
    const row = (await pool.query(
      `INSERT INTO public_coalition_membership_requests
        (id, applicant_type, applicant_profile_id, applicant_user_id)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [requestId, applicant.applicantType, applicant.profileId, req.user.userId]
    )).rows[0];
    return res.status(201).json(mapRequest(row));
  });

  app.get('/api/public-coalition/membership/me', auth, async (req, res) => {
    const applicant = await resolveApplicant(req.user.userId, req.query.applicantType);
    if (!applicant) return res.status(403).json({ error: 'eligible_merchant_or_brand_role_required' });
    const row = (await pool.query(
      `SELECT * FROM public_coalition_membership_requests
        WHERE applicant_type = $1 AND applicant_profile_id = $2
        ORDER BY created_at DESC LIMIT 1`,
      [applicant.applicantType, applicant.profileId]
    )).rows[0];
    return res.json({ request: row ? mapRequest(row) : null });
  });

  app.get('/api/admin/public-coalition/membership-requests', auth, requireAdmin, async (req, res) => {
    const status = String(req.query.status || 'pending_admin_review').trim();
    const allowedStatuses = ['pending_admin_review', 'approved_pending_payment', 'active', 'rejected', 'cancelled', 'all'];
    if (!allowedStatuses.includes(status)) return res.status(400).json({ error: 'invalid_status' });
    const rows = (await pool.query(
      `SELECT r.*,
              COALESCE(mp.business_name, bp.business_name) AS applicant_name,
              u.email AS applicant_email
         FROM public_coalition_membership_requests r
         LEFT JOIN merchant_profiles mp ON r.applicant_type = 'merchant' AND mp.id = r.applicant_profile_id
         LEFT JOIN brand_profiles bp ON r.applicant_type = 'brand' AND bp.id = r.applicant_profile_id
         LEFT JOIN users u ON u.id = r.applicant_user_id
        WHERE ($1 = 'all' OR r.status = $1)
        ORDER BY r.created_at ASC`,
      [status]
    )).rows;
    return res.json(rows.map(mapRequest));
  });

  app.post('/api/admin/public-coalition/membership-requests/:id/approve', auth, requireAdmin, async (req, res) => {
    const adminMessage = String(req.body?.adminMessage || '').trim();
    const paymentUrl = String(req.body?.paymentUrl || '').trim();
    if (!adminMessage) return res.status(400).json({ error: 'admin_message_required' });
    if (paymentUrl && !/^https?:\/\//i.test(paymentUrl)) {
      return res.status(400).json({ error: 'invalid_payment_url' });
    }
    const row = (await pool.query(
      `UPDATE public_coalition_membership_requests
          SET status = 'approved_pending_payment', admin_message = $2, payment_url = $3,
              reviewed_by_user_id = $4, reviewed_at = NOW(), updated_at = NOW()
        WHERE id = $1 AND status = 'pending_admin_review'
        RETURNING *`,
      [req.params.id, adminMessage, paymentUrl || null, req.user.userId]
    )).rows[0];
    if (!row) return res.status(409).json({ error: 'membership_request_not_pending' });
    await insertNotification(
      pool,
      row.applicant_user_id,
      'public_coalition_payment_required',
      'Public coalition application approved',
      adminMessage,
      { requestId: row.id, applicantType: row.applicant_type, paymentUrl: paymentUrl || null, targetScreen: 'public_coalition_membership' }
    );
    return res.json(mapRequest(row));
  });

  app.post('/api/admin/public-coalition/membership-requests/:id/reject', auth, requireAdmin, async (req, res) => {
    const reason = String(req.body?.reason || '').trim();
    if (!reason) return res.status(400).json({ error: 'rejection_reason_required' });
    const row = (await pool.query(
      `UPDATE public_coalition_membership_requests
          SET status = 'rejected', rejection_reason = $2,
              reviewed_by_user_id = $3, reviewed_at = NOW(), updated_at = NOW()
        WHERE id = $1 AND status = 'pending_admin_review'
        RETURNING *`,
      [req.params.id, reason, req.user.userId]
    )).rows[0];
    if (!row) return res.status(409).json({ error: 'membership_request_not_pending' });
    await insertNotification(
      pool,
      row.applicant_user_id,
      'public_coalition_request_rejected',
      'Public coalition application update',
      reason,
      { requestId: row.id, applicantType: row.applicant_type, targetScreen: 'public_coalition_membership' }
    );
    return res.json(mapRequest(row));
  });

  app.post('/api/admin/public-coalition/membership-requests/:id/activate', auth, requireAdmin, async (req, res) => {
    const paymentReference = String(req.body?.paymentReference || '').trim();
    if (!paymentReference) return res.status(400).json({ error: 'payment_reference_required' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const row = (await client.query(
        `SELECT * FROM public_coalition_membership_requests WHERE id = $1 FOR UPDATE`,
        [req.params.id]
      )).rows[0];
      if (!row || row.status !== 'approved_pending_payment') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'membership_request_not_awaiting_payment' });
      }
      if (row.applicant_type === 'merchant') {
        await client.query(
          `INSERT INTO coalition_members (coalition_id, merchant_id)
           VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [PUBLIC_COALITION_ID, row.applicant_profile_id]
        );
        await client.query(
          `UPDATE merchant_profiles SET is_public_coalition_active = TRUE WHERE id = $1`,
          [row.applicant_profile_id]
        );
      } else {
        await client.query(
          `INSERT INTO brand_coalition_members (coalition_id, brand_id)
           VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [PUBLIC_COALITION_ID, row.applicant_profile_id]
        );
      }
      const activeRow = (await client.query(
        `UPDATE public_coalition_membership_requests
            SET status = 'active', payment_reference = $2, activation_source = 'manual_admin',
                activated_by_user_id = $3, activated_at = NOW(), updated_at = NOW()
          WHERE id = $1 RETURNING *`,
        [row.id, paymentReference, req.user.userId]
      )).rows[0];
      await insertNotification(
        client,
        row.applicant_user_id,
        'public_coalition_membership_active',
        'Public coalition membership active',
        'Your Coupona public coalition membership is now active.',
        { requestId: row.id, applicantType: row.applicant_type, targetScreen: 'public_coalition_membership' }
      );
      await client.query('COMMIT');
      return res.json(mapRequest(activeRow));
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'public_coalition_activation_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });
};