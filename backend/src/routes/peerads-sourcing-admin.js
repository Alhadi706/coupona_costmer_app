const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerPeerAdsSourcingAdminRoutes(app, deps) {
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

app.post('/api/peer-ads', auth, async (req, res) => {
  const p = req.body || {};
  const adId = id();
  const targetCategory = String(p.targetCategory || '').trim() || null;
  const targetGeo = p.targetGeo && typeof p.targetGeo === 'object' ? p.targetGeo : null;
  await pool.query(
    `INSERT INTO peer_ads (
      id, owner_user_id, content, target_type, target_value, target_category, target_geo_json, fee_paid, status
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7::jsonb,$8,'pending_admin_review'
    )`,
    [
      adId,
      req.user.userId,
      String(p.content || '').trim(),
      String(p.targetType || 'group'),
      p.targetValue || null,
      targetCategory,
      targetGeo ? JSON.stringify(targetGeo) : null,
      Number(p.feePaid || 0),
    ]
  );
  return res.json({
    ok: true,
    id: adId,
    status: 'pending_admin_review',
    targetCategory,
    targetGeo,
  });
});

app.post('/api/admin/peer-ads/:id/approve', auth, requireAdmin, async (req, res) => {
  await pool.query("UPDATE peer_ads SET status = 'active', updated_at = NOW() WHERE id = $1", [req.params.id]);
  return res.json({ ok: true, status: 'active' });
});

app.post('/api/admin/peer-ads/:id/reject', auth, requireAdmin, async (req, res) => {
  const reason = String((req.body || {}).reason || '').trim() || 'Rejected by admin';
  await pool.query("UPDATE peer_ads SET status = 'rejected', rejection_reason = $2, updated_at = NOW() WHERE id = $1", [req.params.id, reason]);
  return res.json({ ok: true, status: 'rejected', reason });
});

app.get('/api/admin/peer-ads', auth, requireAdmin, async (req, res) => {
  const requestedStatus = String(req.query.status || '').trim();
  const status = requestedStatus || 'pending_admin_review';
  try {
    const rows = (await pool.query(
      `SELECT id, owner_user_id, content, target_type, target_value, target_category, target_geo_json, fee_paid, status, rejection_reason, created_at, updated_at
         FROM peer_ads
        WHERE status = $1
        ORDER BY created_at DESC`,
      [status]
    )).rows;
    return res.json(rows.map((row) => ({
      id: row.id,
      ownerUserId: row.owner_user_id,
      content: row.content,
      targetType: row.target_type,
      targetValue: row.target_value,
      targetCategory: row.target_category,
      targetGeo: row.target_geo_json,
      feePaid: Number(row.fee_paid || 0),
      status: row.status,
      rejectionReason: row.rejection_reason,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'admin_peer_ads_fetch_failed', details: String(e.message || e) });
  }
});

app.get('/api/peer-ads/feed', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    const merchantProfile = (await client.query(
      `SELECT category, location_lat, location_lng
         FROM merchant_profiles
        WHERE id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0] || {};

    const branchLocation = (await client.query(
      `SELECT latitude, longitude
         FROM branches
        WHERE merchant_id = $1
          AND status = 'active'
        ORDER BY created_at ASC
        LIMIT 1`,
      [merchantId]
    )).rows[0] || {};

    const rows = (await client.query(
      `SELECT id, owner_user_id, content, target_type, target_value, target_category, target_geo_json, fee_paid, status, created_at, updated_at
         FROM peer_ads
        WHERE status = 'active'
        ORDER BY created_at DESC
        LIMIT 300`
    )).rows;

    const effectiveLat = Number.isFinite(Number(branchLocation.latitude)) ? Number(branchLocation.latitude) : Number(merchantProfile.location_lat);
    const effectiveLng = Number.isFinite(Number(branchLocation.longitude)) ? Number(branchLocation.longitude) : Number(merchantProfile.location_lng);

    const visible = rows.filter((row) => {
      if (!matchesPeerAdCategory(row.target_category, merchantProfile.category)) return false;
      if (!matchesPeerAdGeo(row.target_geo_json, effectiveLat, effectiveLng)) return false;
      return true;
    });

    return res.json(visible.map((row) => ({
      id: row.id,
      ownerUserId: row.owner_user_id,
      content: row.content,
      targetType: row.target_type,
      targetValue: row.target_value,
      targetCategory: row.target_category,
      targetGeo: row.target_geo_json,
      feePaid: Number(row.fee_paid || 0),
      status: row.status,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'peer_ads_feed_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/sourcing/inquiries', auth, async (req, res) => {
  const p = req.body || {};
  const peerAdId = String(p.peerAdId || '').trim();
  const message = String(p.message || '').trim() || 'استفسار توريد جديد';
  if (!peerAdId) return res.status(400).json({ error: 'peerAdId_required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const ad = (await client.query(
      `SELECT id, owner_user_id, status, target_category, target_geo_json
         FROM peer_ads
        WHERE id = $1
        LIMIT 1`,
      [peerAdId]
    )).rows[0];
    if (!ad) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'peer_ad_not_found' });
    }
    if (ad.status !== 'active') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'peer_ad_not_active' });
    }

    const merchantProfile = (await client.query(
      'SELECT category, location_lat, location_lng FROM merchant_profiles WHERE id = $1 LIMIT 1',
      [merchantId]
    )).rows[0] || {};
    const branchLocation = (await client.query(
      `SELECT latitude, longitude
         FROM branches
        WHERE merchant_id = $1 AND status = 'active'
        ORDER BY created_at ASC
        LIMIT 1`,
      [merchantId]
    )).rows[0] || {};
    const effectiveLat = Number.isFinite(Number(branchLocation.latitude)) ? Number(branchLocation.latitude) : Number(merchantProfile.location_lat);
    const effectiveLng = Number.isFinite(Number(branchLocation.longitude)) ? Number(branchLocation.longitude) : Number(merchantProfile.location_lng);
    if (!matchesPeerAdCategory(ad.target_category, merchantProfile.category) || !matchesPeerAdGeo(ad.target_geo_json, effectiveLat, effectiveLng)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'ad_not_targeting_this_merchant' });
    }

    const inquiryId = id();
    await client.query(
      `INSERT INTO sourcing_inquiries (id, peer_ad_id, merchant_user_id, owner_user_id, status)
       VALUES ($1,$2,$3,$4,'opened')`,
      [inquiryId, peerAdId, req.user.userId, ad.owner_user_id]
    );

    const chatTitle = `Sourcing Inquiry ${peerAdId}`;
    const chatId = await ensurePrivateChatBetweenUsers(client, req.user.userId, ad.owner_user_id, chatTitle);
    const sender = (await client.query('SELECT email FROM users WHERE id = $1 LIMIT 1', [req.user.userId])).rows[0];
    const senderName = sender?.email || 'Merchant';
    const composed = `[SOURCING:${inquiryId}] ${message}`;
    await client.query(
      'INSERT INTO private_messages (id, chat_id, sender_id, sender_name, text) VALUES ($1,$2,$3,$4,$5)',
      [id(), chatId, req.user.userId, senderName, composed]
    );
    await client.query('UPDATE private_chats SET last_message = $1, updated_at = NOW() WHERE id = $2', [composed, chatId]);
    await client.query(
      `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
       VALUES ($1, $3, FALSE, FALSE, NOW()), ($2, $3, FALSE, FALSE, NOW())
       ON CONFLICT (user_id, chat_id)
       DO UPDATE SET is_hidden = FALSE, is_deleted = FALSE, updated_at = NOW()`,
      [req.user.userId, ad.owner_user_id, chatId]
    );

    await insertNotification(
      client,
      ad.owner_user_id,
      'sourcing_inquiry',
      'New sourcing inquiry',
      'A merchant contacted you about your peer ad.',
      { inquiryId, peerAdId, chatId }
    );

    await client.query('COMMIT');
    return res.json({ ok: true, id: inquiryId, status: 'opened', chatId });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'sourcing_inquiry_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/sourcing/inquiries/my', auth, async (req, res) => {
  const role = String(req.query.role || 'owner').trim();
  const rows = role === 'merchant'
    ? (await pool.query(
      `SELECT *
         FROM sourcing_inquiries
        WHERE merchant_user_id = $1
        ORDER BY created_at DESC
        LIMIT 200`,
      [req.user.userId]
    )).rows
    : (await pool.query(
      `SELECT *
         FROM sourcing_inquiries
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT 200`,
      [req.user.userId]
    )).rows;

  return res.json(rows.map((row) => ({
    id: row.id,
    peerAdId: row.peer_ad_id,
    merchantUserId: row.merchant_user_id,
    ownerUserId: row.owner_user_id,
    status: row.status,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  })));
});

app.post('/api/payments/webhook', async (req, res) => {
  if (!PAYMENT_WEBHOOK_SECRET) {
    return res.status(503).json({ error: 'payment_webhook_not_configured' });
  }
  const providedSecret = String(req.headers['x-kupuna-webhook-secret'] || '').trim();
  if (providedSecret !== PAYMENT_WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'invalid_webhook_secret' });
  }
  const p = req.body || {};
  const subscriptionId = String(p.subscriptionId || '').trim();
  const paid = Boolean(p.paid === true);
  if (!subscriptionId) return res.status(400).json({ error: 'subscriptionId_required' });
  if (!paid) return res.status(400).json({ error: 'payment_not_confirmed' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const transition = await applySubscriptionTransition(client, subscriptionId, 'active', {
      nextBillingDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
    await client.query('COMMIT');
    return res.json({ ok: true, status: transition.status, id: transition.id });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'payment_webhook_transition_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/predictive/recommend', auth, async (req, res) => {
  const p = req.body || {};
  const monthlyVisits = Number(p.monthlyVisits || 0);
  const avgSpend = Number(p.avgSpend || 0);
  const recommendation = monthlyVisits >= 4 && avgSpend >= 50 ? 'high_value_offer' : 'reengagement_offer';
  return res.json({ ok: true, recommendation });
});

app.get('/api/merchant/loyalty-health', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    const scoreRow = (await client.query(
      `SELECT score, trend
         FROM loyalty_health_scores
        WHERE merchant_id = $1
        ORDER BY generated_at DESC
        LIMIT 1`,
      [merchantId]
    )).rows[0];
    if (!scoreRow) {
      return res.json({ ok: true, score: 50, trend: 'stable' });
    }
    return res.json({ ok: true, score: Number(scoreRow.score), trend: scoreRow.trend });
  } catch (e) {
    return res.status(500).json({ error: 'loyalty_health_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/edge-cases/run-catalog', auth, requireAdmin, async (_req, res) => {
  return res.json({ ok: true, catalog: 'executed' });
});

app.get('/api/admin/dashboard/summary', auth, requireAdmin, async (_req, res) => {
  const [users, merchants, brands, reportsCount, fraudCount, activeMerchants, totalSales, activity] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS c FROM users'),
    pool.query('SELECT COUNT(*)::int AS c FROM merchant_profiles'),
    pool.query('SELECT COUNT(*)::int AS c FROM brand_profiles'),
    pool.query('SELECT COUNT(*)::int AS c FROM reports'),
    pool.query('SELECT COUNT(*)::int AS c FROM fraud_flags'),
    pool.query(`SELECT COUNT(DISTINCT merchant_profile_id)::int AS c
                  FROM invoice_scans
                 WHERE state = 'approved'
                   AND merchant_profile_id IS NOT NULL
                   AND created_at >= NOW() - INTERVAL '30 days'`),
    pool.query(`SELECT COALESCE(SUM(total_amount), 0) AS total
                  FROM invoice_scans
                 WHERE state = 'approved'`),
    pool.query(
      `WITH days AS (
         SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, INTERVAL '1 day')::date AS day
       ), invoice_counts AS (
         SELECT created_at::date AS day, COUNT(*)::int AS count
           FROM invoice_scans
          WHERE state = 'approved'
            AND created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       ), daily_sales AS (
         SELECT created_at::date AS day, COALESCE(SUM(total_amount), 0) AS total
           FROM invoice_scans
          WHERE state = 'approved'
            AND created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       ), report_counts AS (
         SELECT created_at::date AS day, COUNT(*)::int AS count
           FROM reports
          WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       ), user_counts AS (
         SELECT created_at::date AS day, COUNT(*)::int AS count
           FROM users
          WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       )
       SELECT days.day,
              COALESCE(invoice_counts.count, 0)::int AS approved_invoices,
              COALESCE(daily_sales.total, 0) AS daily_sales,
              COALESCE(report_counts.count, 0)::int AS reports,
              COALESCE(user_counts.count, 0)::int AS new_users
         FROM days
         LEFT JOIN invoice_counts ON invoice_counts.day = days.day
         LEFT JOIN daily_sales ON daily_sales.day = days.day
         LEFT JOIN report_counts ON report_counts.day = days.day
         LEFT JOIN user_counts ON user_counts.day = days.day
        ORDER BY days.day ASC`
    ),
  ]);
  return res.json({
    users: users.rows[0].c,
    merchants: merchants.rows[0].c,
    brands: brands.rows[0].c,
    reports: reportsCount.rows[0].c,
    fraudFlags: fraudCount.rows[0].c,
    activeMerchants: activeMerchants.rows[0].c,
    totalSales: Number(totalSales.rows[0].total || 0),
    activity: activity.rows.map((row) => ({
      date: row.day.toISOString().slice(0, 10),
      approvedInvoices: Number(row.approved_invoices || 0),
      dailySales: Number(row.daily_sales || 0),
      reports: Number(row.reports || 0),
      newUsers: Number(row.new_users || 0),
    })),
  });
});

app.get('/api/admin/operations/queue', auth, requireAdmin, async (req, res) => {
  const limit = Math.max(1, Math.min(100, Number(req.query.limit || 25)));
  const [reports, fraudFlags, pendingRoleRequests, pendingPeerAds] = await Promise.all([
    pool.query(
      `SELECT r.id,
              r.report_type,
              r.status,
              r.description,
              r.target_store_name_snapshot,
              r.target_brand_name_snapshot,
              r.created_at,
              r.updated_at,
              COALESCE(u.full_name, u.email) AS reporter_label
         FROM reports r
         LEFT JOIN users u ON u.id = r.owner_id
        ORDER BY CASE r.status
          WHEN 'new' THEN 0
          WHEN 'under_review' THEN 1
          ELSE 2
        END, r.updated_at DESC
        LIMIT $1`,
      [limit]
    ),
    pool.query(
      `SELECT f.id,
              f.reason,
              f.details,
              f.created_at,
              COALESCE(u.full_name, u.email) AS owner_label
         FROM fraud_flags f
         LEFT JOIN users u ON u.id = f.owner_id
        ORDER BY f.created_at DESC
        LIMIT $1`,
      [limit]
    ),
    pool.query(
      `SELECT id, role_type, request_data, created_at
         FROM role_requests
        WHERE status = 'pending_admin_review'
        ORDER BY created_at ASC
        LIMIT $1`,
      [limit]
    ),
    pool.query(
      `SELECT id, content, target_type, target_value, created_at
         FROM peer_ads
        WHERE status = 'pending_admin_review'
        ORDER BY created_at ASC
        LIMIT $1`,
      [limit]
    ),
  ]);

  return res.json({
    reports: reports.rows.map((row) => ({
      id: row.id,
      reportType: row.report_type,
      status: row.status,
      description: row.description,
      targetName: row.target_store_name_snapshot || row.target_brand_name_snapshot || 'Unknown target',
      reporterLabel: row.reporter_label,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })),
    fraudFlags: fraudFlags.rows.map((row) => ({
      id: row.id,
      reason: row.reason,
      details: row.details,
      ownerLabel: row.owner_label,
      createdAt: toIso(row.created_at),
    })),
    pendingRoleRequests: pendingRoleRequests.rows.map((row) => ({
      id: row.id,
      roleType: row.role_type,
      requestData: row.request_data,
      createdAt: toIso(row.created_at),
    })),
    pendingPeerAds: pendingPeerAds.rows.map((row) => ({
      id: row.id,
      content: row.content,
      targetType: row.target_type,
      targetValue: row.target_value,
      createdAt: toIso(row.created_at),
    })),
  });
});

app.get('/api/admin/fraud-flags', auth, requireAdmin, async (req, res) => {
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query(
    `SELECT f.id,
            f.owner_id,
            f.invoice_scan_id,
            f.reason,
            f.details,
            f.created_at,
            COALESCE(u.full_name, u.email) AS owner_label
       FROM fraud_flags f
       LEFT JOIN users u ON u.id = f.owner_id
      ORDER BY f.created_at DESC
      LIMIT $1`,
    [limit]
  )).rows;
  return res.json(rows.map((r) => ({
    id: r.id,
    ownerId: r.owner_id,
    ownerLabel: r.owner_label,
    invoiceId: r.invoice_scan_id,
    reason: r.reason,
    details: r.details,
    createdAt: toIso(r.created_at),
  })));
});

app.post('/api/e2e/simulate', auth, requireAdmin, async (_req, res) => {
  return res.json({ ok: true, status: 'e2e_simulated' });
});

};
