const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerRolesSubscriptionsRoutes(app, deps) {
  const {
    pool, CANONICAL_ROLES,
    PORT, JWT_SECRET, POS_GRANT_TOKEN_SECRET, POS_GRANT_TOKEN_TTL_SECONDS, FCM_SERVER_KEY,
    PAYMENT_WEBHOOK_SECRET, GEMINI_API_KEY, GEMINI_MODEL, ACCESS_TOKEN_TTL, KUPUNA_OWNER_EMAIL,
    OWNER_ENFORCEMENT_ENABLED, DEV_OWNER_BYPASS, SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD,
    EMAIL_FROM, OWNER_MFA_CODE_TTL_MS, OWNER_MFA_MAX_ATTEMPTS, DEV_OWNER_CHALLENGE_TTL_MS,
    devOwnerChallenges, GEMINI_FALLBACK_MODELS, AI_ONLY_MODE, UPLOAD_DIR, INVOICES_UPLOAD_DIR,
    CORS_ALLOWED_ORIGINS, AUTH_RATE_LIMIT_WINDOW_MS, LOGIN_RATE_LIMIT_MAX, SIGNUP_RATE_LIMIT_MAX,
    UPLOAD_RATE_LIMIT_WINDOW_MS, UPLOAD_RATE_LIMIT_MAX, requiredEnv, parseList, corsGuard,
    createRateLimiter, loginRateLimit, signupRateLimit, uploadRateLimit, ownerLoginRateLimit,
    ownerVerifyRateLimit, ownerResendRateLimit,
    id, normalizeRole, signAccessToken, isSystemOwner, smtpConfigured, ownerMailer,
    sendOwnerMfaCode, hashOwnerCode, ownerCode, isAdmin, isLoopbackRequest, canAccessUserObject,
    detectImageMime, toIso, normalizeMerchantKey, canonicalMerchantName, normalizeForFingerprint,
    buildInvoiceFingerprint, parseFlexibleDate, haversineDistanceKm, calculateAgeYears,
    parseTargetingCriteria, extractJsonObject, normalizeAiInvoiceFields, analyzeInvoiceWithGemini,
    auth, requireAdmin, ensureCustomerProfile, getIntSetting, canManageInvoice, canRedeemClaim,
    runSubscriptionTransitions, hasBlockRelation, isPrivateChatParticipant, getPeerUserId,
    sendFcmToTokens, getActivePushTokens, insertNotification, ensureCommunityGroupForRole,
    ensureCommunityMembership, joinCustomerToMerchantCommunity, joinCustomerToBrandCommunities,
    canModerateCommunityGroup, canTransitionSubscription, getSubscriptionOwnerUserId,
    syncCashierProfilesForMerchantSubscription, applySubscriptionTransition,
    assertMerchantSubscriptionWritable, isMerchantSubscriptionReadOnlyError,
    ensurePrivateChatBetweenUsers, applyInvoiceApprovalRewards, offerMatchesTargeting,
    calculatePointsWithFraction, getMerchantProfileIdByUser, getBrandProfileIdByUser,
    normalizeRoleType, resolveMerchantProfileIdByKey, autoMatchLineItemToBrand,
    matchesPeerAdCategory, parseGeoJson, matchesPeerAdGeo, mapRewardRow, validateRewardSource,
    analyticsRangeDays, analyticsDaysAgo, analyticsSafeNumber, analyticsPercentChange,
    analyticsAgeBucket, analyticsCountEntries, analyticsTopEntries,
  } = deps;

app.get('/api/roles/me', auth, async (req, res) => {
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    await ensureCustomerProfile(client, userId);

    const customerExists = (await client.query(
      'SELECT 1 FROM customer_profiles WHERE user_id = $1 LIMIT 1',
      [userId]
    )).rows.length > 0;

    const merchantExists = (await client.query(
      "SELECT 1 FROM merchant_profiles WHERE user_id = $1 AND status = 'active' LIMIT 1",
      [userId]
    )).rows.length > 0;

    const brandExists = (await client.query(
      "SELECT 1 FROM brand_profiles WHERE user_id = $1 AND status = 'active' LIMIT 1",
      [userId]
    )).rows.length > 0;

    const cashierRows = (await client.query(
      `SELECT cp.id, cp.merchant_id, cp.branch_id, cp.is_active,
              mp.business_name AS merchant_name,
              b.name AS branch_name
         FROM cashier_profiles cp
         LEFT JOIN merchant_profiles mp ON mp.id = cp.merchant_id
         LEFT JOIN branches b ON b.id = cp.branch_id
        WHERE cp.user_id = $1
        ORDER BY cp.created_at ASC`,
      [userId]
    )).rows;

    const subscriptionRows = (await client.query(
      `SELECT s.id, s.role_profile_id, s.role_type, s.status, s.plan_type, s.trial_start_date, s.trial_end_date, s.next_billing_date
         FROM subscriptions s
        WHERE s.role_profile_id IN (
          SELECT id FROM merchant_profiles WHERE user_id = $1
          UNION
          SELECT id FROM brand_profiles WHERE user_id = $1
        )
        ORDER BY s.updated_at DESC`,
      [userId]
    )).rows;

    return res.json({
      customer: customerExists,
      merchant: merchantExists,
      brand: brandExists,
      cashier: cashierRows.map((row) => ({
        id: row.id,
        merchantId: row.merchant_id,
        merchantName: row.merchant_name || null,
        branchId: row.branch_id,
        branchName: row.branch_name || null,
        isActive: Boolean(row.is_active),
      })),
      subscriptions: subscriptionRows.map((row) => ({
        id: row.id,
        roleProfileId: row.role_profile_id,
        roleType: row.role_type,
        status: row.status,
        planType: row.plan_type,
        trialStartDate: toIso(row.trial_start_date),
        trialEndDate: toIso(row.trial_end_date),
        nextBillingDate: toIso(row.next_billing_date),
      })),
    });
  } catch (e) {
    return res.status(500).json({ error: 'roles_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/roles/merchant/request', auth, async (req, res) => {
  const p = req.body || {};
  const phone = String(p.phone || '').trim();
  const category = String(p.category || '').trim() || null;
  const locationLat = Number(p.locationLat);
  const locationLng = Number(p.locationLng);
  const locationAddress = String(p.locationAddress || '').trim();
  if (!phone || !Number.isFinite(locationLat) || !Number.isFinite(locationLng)) {
    return res.status(400).json({ error: 'missing_required_fields' });
  }
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const profileId = id();
    await client.query(
      `INSERT INTO merchant_profiles (
         id, user_id, business_name, commercial_registration,
         phone, category, location_lat, location_lng, location_address, status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending_admin_review')
       ON CONFLICT (user_id)
       DO UPDATE SET
         business_name = EXCLUDED.business_name,
         commercial_registration = EXCLUDED.commercial_registration,
         phone = EXCLUDED.phone,
         category = EXCLUDED.category,
         location_lat = EXCLUDED.location_lat,
         location_lng = EXCLUDED.location_lng,
         location_address = EXCLUDED.location_address,
         status = 'pending_admin_review'`,
      [
        profileId,
        userId,
        p.businessName || null,
        p.commercialRegistration || null,
        phone,
        category,
        locationLat,
        locationLng,
        locationAddress || null,
      ]
    );

    const effectiveProfile = (await client.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0]?.id;
    const requestId = id();
    await client.query(
      `INSERT INTO role_requests (id, user_id, role_type, role_profile_id, status, plan_type, request_data)
       VALUES ($1, $2, 'merchant', $3, 'pending_admin_review', $4, $5::jsonb)`,
      [requestId, userId, effectiveProfile, p.planType || null, JSON.stringify(p)]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, requestId, status: 'pending_admin_review' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'merchant_request_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/roles/brand/request', auth, async (req, res) => {
  const p = req.body || {};
  const phone = String(p.phone || '').trim();
  const locationLat = Number(p.locationLat);
  const locationLng = Number(p.locationLng);
  const locationAddress = String(p.locationAddress || '').trim();
  if (!phone || !Number.isFinite(locationLat) || !Number.isFinite(locationLng)) {
    return res.status(400).json({ error: 'missing_required_fields' });
  }
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const profileId = id();
    await client.query(
      `INSERT INTO brand_profiles (
         id, user_id, business_name, commercial_registration,
         phone, location_lat, location_lng, location_address, status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending_admin_review')
       ON CONFLICT (user_id)
       DO UPDATE SET
         business_name = EXCLUDED.business_name,
         commercial_registration = EXCLUDED.commercial_registration,
         phone = EXCLUDED.phone,
         location_lat = EXCLUDED.location_lat,
         location_lng = EXCLUDED.location_lng,
         location_address = EXCLUDED.location_address,
         status = 'pending_admin_review'`,
      [
        profileId,
        userId,
        p.businessName || null,
        p.commercialRegistration || null,
        phone,
        locationLat,
        locationLng,
        locationAddress || null,
      ]
    );

    const effectiveProfile = (await client.query('SELECT id FROM brand_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0]?.id;
    const requestId = id();
    await client.query(
      `INSERT INTO role_requests (id, user_id, role_type, role_profile_id, status, plan_type, request_data)
       VALUES ($1, $2, 'brand', $3, 'pending_admin_review', $4, $5::jsonb)`,
      [requestId, userId, effectiveProfile, p.planType || null, JSON.stringify(p)]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, requestId, status: 'pending_admin_review' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'brand_request_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/roles/requests/me', auth, async (req, res) => {
  const userId = req.user.userId;
  try {
    const rows = (await pool.query(
      `SELECT id, role_type, status, plan_type, rejection_reason, created_at, reviewed_at
         FROM role_requests
        WHERE user_id = $1
        ORDER BY created_at DESC`,
      [userId]
    )).rows;
    return res.json(rows.map((row) => ({
      id: row.id,
      roleType: row.role_type,
      status: row.status,
      planType: row.plan_type,
      rejectionReason: row.rejection_reason,
      createdAt: toIso(row.created_at),
      reviewedAt: toIso(row.reviewed_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'role_requests_fetch_failed', details: String(e.message || e) });
  }
});

app.get('/api/admin/role-requests', auth, requireAdmin, async (req, res) => {
  const requestedStatus = String(req.query.status || '').trim();
  const status = requestedStatus || 'pending_admin_review';
  try {
    const rows = (await pool.query(
      `SELECT
         rr.id,
         rr.user_id,
         rr.role_type,
         rr.role_profile_id,
         rr.status,
         rr.plan_type,
         rr.request_data,
         rr.rejection_reason,
         rr.created_at,
         rr.reviewed_at,
         COALESCE(mp.business_name, bp.business_name) AS business_name,
         COALESCE(mp.commercial_registration, bp.commercial_registration) AS commercial_registration,
         COALESCE(mp.phone, bp.phone) AS phone,
         COALESCE(mp.location_lat, bp.location_lat) AS location_lat,
         COALESCE(mp.location_lng, bp.location_lng) AS location_lng,
         COALESCE(mp.location_address, bp.location_address) AS location_address
       FROM role_requests rr
       LEFT JOIN merchant_profiles mp
         ON rr.role_type = 'merchant'
        AND rr.role_profile_id = mp.id
       LEFT JOIN brand_profiles bp
         ON rr.role_type = 'brand'
        AND rr.role_profile_id = bp.id
      WHERE rr.status = $1
      ORDER BY rr.created_at DESC`,
      [status]
    )).rows;

    return res.json(rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      roleType: row.role_type,
      roleProfileId: row.role_profile_id,
      status: row.status,
      planType: row.plan_type,
      requestData: row.request_data || {},
      category: row.request_data?.category || null,
      workingHours: row.request_data?.workingHours || null,
      rejectionReason: row.rejection_reason,
      businessName: row.business_name,
      commercialRegistration: row.commercial_registration,
      phone: row.phone,
      locationLat: row.location_lat == null ? null : Number(row.location_lat),
      locationLng: row.location_lng == null ? null : Number(row.location_lng),
      locationAddress: row.location_address,
      createdAt: toIso(row.created_at),
      reviewedAt: toIso(row.reviewed_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'admin_role_requests_fetch_failed', details: String(e.message || e) });
  }
});

app.post('/api/admin/role-requests/:id/approve', auth, requireAdmin, async (req, res) => {
  const requestId = req.params.id;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const requestRow = (await client.query('SELECT * FROM role_requests WHERE id = $1 LIMIT 1', [requestId])).rows[0];
    if (!requestRow) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'role_request_not_found' });
    }

    const trialDays = await getIntSetting(client, 'trial_duration_days_default', 30);
    const trialStart = new Date();
    const trialEnd = new Date(trialStart.getTime() + trialDays * 24 * 60 * 60 * 1000);

    await client.query(
      `UPDATE role_requests
          SET status = 'approved', reviewed_at = NOW(), rejection_reason = NULL
        WHERE id = $1`,
      [requestId]
    );

    if (requestRow.role_type === 'merchant') {
      await client.query(
        `UPDATE merchant_profiles
            SET status = 'active'
          WHERE id = $1`,
        [requestRow.role_profile_id]
      );

      const merchantProfile = (await client.query(
        'SELECT business_name, user_id FROM merchant_profiles WHERE id = $1 LIMIT 1',
        [requestRow.role_profile_id]
      )).rows[0];
      await ensureCommunityGroupForRole(
        client,
        'merchant',
        requestRow.role_profile_id,
        merchantProfile?.user_id || requestRow.user_id,
        merchantProfile?.business_name || 'Merchant Community'
      );
    }

    if (requestRow.role_type === 'brand') {
      await client.query(
        `UPDATE brand_profiles
            SET status = 'active'
          WHERE id = $1`,
        [requestRow.role_profile_id]
      );

      const brandProfile = (await client.query(
        'SELECT business_name, user_id FROM brand_profiles WHERE id = $1 LIMIT 1',
        [requestRow.role_profile_id]
      )).rows[0];
      await ensureCommunityGroupForRole(
        client,
        'brand',
        requestRow.role_profile_id,
        brandProfile?.user_id || requestRow.user_id,
        brandProfile?.business_name || 'Brand Community'
      );
    }

    await client.query(
      `INSERT INTO subscriptions (
         id, role_profile_id, role_type, plan_type, status,
         trial_duration_days, trial_start_date, trial_end_date, billing_cycle, next_billing_date
       ) VALUES ($1,$2,$3,$4,'trial',$5,$6,$7,'monthly',$7)`,
      [
        id(),
        requestRow.role_profile_id,
        requestRow.role_type,
        requestRow.plan_type,
        trialDays,
        trialStart.toISOString(),
        trialEnd.toISOString(),
      ]
    );

    await client.query('COMMIT');
    await insertNotification(
      pool,
      requestRow.user_id,
      'role_request_approved',
      'Role approved',
      `${requestRow.role_type} role was approved and activated.`,
      { roleType: requestRow.role_type, roleProfileId: requestRow.role_profile_id }
    );
    return res.json({ ok: true, status: 'approved', subscriptionStatus: 'trial' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'role_request_approve_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/role-requests/:id/reject', auth, requireAdmin, async (req, res) => {
  const requestId = req.params.id;
  const reason = String((req.body || {}).reason || '').trim() || 'Rejected by admin';
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const requestRow = (await client.query('SELECT * FROM role_requests WHERE id = $1 LIMIT 1', [requestId])).rows[0];
    if (!requestRow) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'role_request_not_found' });
    }

    await client.query(
      `UPDATE role_requests
          SET status = 'rejected', rejection_reason = $2, reviewed_at = NOW()
        WHERE id = $1`,
      [requestId, reason]
    );

    if (requestRow.role_type === 'merchant') {
      await client.query('UPDATE merchant_profiles SET status = $2 WHERE id = $1', [requestRow.role_profile_id, 'rejected']);
    }
    if (requestRow.role_type === 'brand') {
      await client.query('UPDATE brand_profiles SET status = $2 WHERE id = $1', [requestRow.role_profile_id, 'rejected']);
    }

    await client.query('COMMIT');
    return res.json({ ok: true, status: 'rejected', reason });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'role_request_reject_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/subscriptions/run-transitions', auth, requireAdmin, async (_req, res) => {
  try {
    await runSubscriptionTransitions();
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'subscription_transition_failed', details: String(e.message || e) });
  }
});

app.get('/api/admin/subscriptions', auth, requireAdmin, async (req, res) => {
  const roleType = normalizeRoleType(req.query.roleType);
  const status = String(req.query.status || '').trim();
  const filters = [];
  const params = [];
  if (roleType) {
    params.push(roleType);
    filters.push(`s.role_type = $${params.length}`);
  }
  if (status) {
    params.push(status);
    filters.push(`s.status = $${params.length}`);
  }
  const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
  const rows = (await pool.query(
    `SELECT s.id,
            s.role_profile_id,
            s.role_type,
            s.plan_type,
            s.status,
            s.trial_start_date,
            s.trial_end_date,
            s.next_billing_date,
            CASE
              WHEN s.role_type = 'merchant' THEN mp.user_id
              WHEN s.role_type = 'brand' THEN bp.user_id
              ELSE NULL
            END AS owner_user_id,
            CASE
              WHEN s.role_type = 'merchant' THEN mp.business_name
              WHEN s.role_type = 'brand' THEN bp.business_name
              ELSE NULL
            END AS owner_label
       FROM subscriptions s
       LEFT JOIN merchant_profiles mp ON s.role_type = 'merchant' AND mp.id = s.role_profile_id
       LEFT JOIN brand_profiles bp ON s.role_type = 'brand' AND bp.id = s.role_profile_id
       ${whereClause}
      ORDER BY s.updated_at DESC`,
    params
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    roleProfileId: row.role_profile_id,
    roleType: row.role_type,
    planType: row.plan_type,
    status: row.status,
    ownerUserId: row.owner_user_id,
    ownerLabel: row.owner_label,
    trialStartDate: toIso(row.trial_start_date),
    trialEndDate: toIso(row.trial_end_date),
    nextBillingDate: toIso(row.next_billing_date),
    accessMode: row.status === 'suspended' ? 'read_only' : 'full',
  })));
});

app.post('/api/admin/subscriptions/:id/expire-trial-now', auth, requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE subscriptions
          SET trial_end_date = NOW() - INTERVAL '1 minute',
              updated_at = NOW()
        WHERE id = $1`,
      [req.params.id]
    );
    await client.query('COMMIT');
    await runSubscriptionTransitions();
    const row = (await pool.query(
      'SELECT id, status, trial_end_date, next_billing_date FROM subscriptions WHERE id = $1 LIMIT 1',
      [req.params.id]
    )).rows[0];
    return res.json({ ok: true, id: row.id, status: row.status, trialEndDate: toIso(row.trial_end_date), nextBillingDate: toIso(row.next_billing_date) });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'subscription_expire_trial_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/subscriptions/:id/end-grace-now', auth, requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE subscriptions
          SET next_billing_date = NOW() - INTERVAL '1 minute',
              updated_at = NOW()
        WHERE id = $1`,
      [req.params.id]
    );
    await client.query('COMMIT');
    await runSubscriptionTransitions();
    const row = (await pool.query(
      'SELECT id, status, trial_end_date, next_billing_date FROM subscriptions WHERE id = $1 LIMIT 1',
      [req.params.id]
    )).rows[0];
    return res.json({ ok: true, id: row.id, status: row.status, trialEndDate: toIso(row.trial_end_date), nextBillingDate: toIso(row.next_billing_date) });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'subscription_end_grace_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/subscriptions/:id/activate-now', auth, requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const transition = await applySubscriptionTransition(client, req.params.id, 'active', {
      nextBillingDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
    await client.query('COMMIT');
    return res.json({ ok: true, ...transition });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'subscription_activate_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

};
