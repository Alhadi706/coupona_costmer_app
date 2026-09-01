const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerUsersRoutes(app, deps) {
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

app.get('/api/blocks', auth, async (req, res) => {
  const rows = (await pool.query(
    `SELECT b.blocked_id, b.created_at, u.email
       FROM user_blocks b
       LEFT JOIN users u ON u.id = b.blocked_id
      WHERE b.blocker_id = $1
      ORDER BY b.created_at DESC`,
    [req.user.userId]
  )).rows;
  res.json(rows.map((r) => ({
    blockedUserId: r.blocked_id,
    blockedEmail: r.email,
    createdAt: toIso(r.created_at),
  })));
});

app.post('/api/users/:id/block', auth, async (req, res) => {
  const blockedId = String(req.params.id || '').trim();
  if (!blockedId) {
    return res.status(400).json({ error: 'blocked_user_required' });
  }
  if (blockedId === req.user.userId) {
    return res.status(400).json({ error: 'self_block_not_supported' });
  }
  const user = (await pool.query('SELECT id FROM users WHERE id = $1', [blockedId])).rows[0];
  if (!user) {
    return res.status(404).json({ error: 'user_not_found' });
  }
  await pool.query(
    'INSERT INTO user_blocks (blocker_id, blocked_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT (blocker_id, blocked_id) DO NOTHING',
    [req.user.userId, blockedId]
  );
  res.json({ ok: true });
});

app.post('/api/users/:id/unblock', auth, async (req, res) => {
  const blockedId = String(req.params.id || '').trim();
  if (!blockedId) {
    return res.status(400).json({ error: 'blocked_user_required' });
  }
  await pool.query(
    'DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2',
    [req.user.userId, blockedId]
  );
  res.json({ ok: true });
});

app.get('/api/users', auth, requireAdmin, async (_req, res) => {
  const rows = (await pool.query('SELECT id, email, role, full_name, gender, city, country, profile_completed, points, points_history, created_at FROM users ORDER BY created_at DESC LIMIT 200')).rows;
  res.json(rows.map((u) => ({
    id: u.id,
    email: u.email,
    role: u.role,
    fullName: u.full_name,
    full_name: u.full_name,
    gender: u.gender,
    city: u.city,
    country: u.country,
    profileCompleted: u.profile_completed,
    points: u.points,
    points_history: u.points_history || [],
    createdAt: toIso(u.created_at),
  })));
});

app.get('/api/users/:id', auth, async (req, res) => {
  if (!canAccessUserObject(req.user, req.params.id)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  const row = (await pool.query('SELECT id, email, role, full_name, gender, city, country, profile_completed, points, points_history, created_at FROM users WHERE id = $1', [req.params.id])).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  res.json({
    id: row.id,
    email: row.email,
    role: row.role,
    fullName: row.full_name,
    full_name: row.full_name,
    gender: row.gender,
    city: row.city,
    country: row.country,
    profileCompleted: row.profile_completed,
    points: row.points,
    points_history: row.points_history || [],
    createdAt: toIso(row.created_at),
  });
});

app.get('/api/customer/location/me', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    await ensureCustomerProfile(client, req.user.userId);
    const row = (await client.query(
      `SELECT location_lat, location_lng
         FROM customer_profiles
        WHERE user_id = $1
        LIMIT 1`,
      [req.user.userId]
    )).rows[0];
    return res.json({
      latitude: row?.location_lat == null ? null : Number(row.location_lat),
      longitude: row?.location_lng == null ? null : Number(row.location_lng),
    });
  } catch (e) {
    return res.status(500).json({ error: 'customer_location_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/customer/location/me', auth, async (req, res) => {
  const latitude = Number((req.body || {}).latitude);
  const longitude = Number((req.body || {}).longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ error: 'latitude_longitude_required' });
  }

  const client = await pool.connect();
  try {
    await ensureCustomerProfile(client, req.user.userId);
    await client.query(
      `UPDATE customer_profiles
          SET location_lat = $2,
              location_lng = $3
        WHERE user_id = $1`,
      [req.user.userId, latitude, longitude]
    );
    return res.json({ ok: true, latitude, longitude });
  } catch (e) {
    return res.status(500).json({ error: 'customer_location_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/users/:id/profile', auth, async (req, res) => {
  if (!canAccessUserObject(req.user, req.params.id)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  const p = req.body || {};
  await pool.query(
    'UPDATE users SET full_name=$1, gender=$2, city=$3, country=$4, profile_completed=COALESCE($5, profile_completed) WHERE id=$6',
    [p.fullName || p.full_name || null, p.gender || null, p.city || null, p.country || null, p.profileCompleted, req.params.id]
  );
  res.json({ ok: true });
});

};
