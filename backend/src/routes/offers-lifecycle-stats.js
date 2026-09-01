const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerOffersLifecycleStatsRoutes(app, deps) {
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

app.get('/api/offers/:id/lifecycle', auth, async (req, res) => {
  const row = (await pool.query('SELECT * FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, row.owner_id)) return res.status(403).json({ error: 'forbidden' });
  res.json({
    lifecycleStatus: row.lifecycle_status,
    createdAt: toIso(row.created_at),
    lifecycleUpdatedAt: toIso(row.lifecycle_updated_at),
    lifecycleReason: row.lifecycle_reason,
    redeemedAt: toIso(row.redeemed_at),
    archivedAt: toIso(row.archived_at),
  });
});

app.post('/api/offers/:id/lifecycle/ensure-defaults', auth, async (req, res) => {
  const owner = (await pool.query('SELECT owner_id FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!owner) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, owner.owner_id)) return res.status(403).json({ error: 'forbidden' });
  await pool.query(
    `UPDATE offers
        SET lifecycle_status = COALESCE(lifecycle_status, 'draft'),
            lifecycle_updated_at = COALESCE(lifecycle_updated_at, NOW())
      WHERE id = $1`,
    [req.params.id]
  );
  res.json({ ok: true });
});

app.post('/api/offers/:id/lifecycle/transition', auth, async (req, res) => {
  const targetStatus = String((req.body || {}).targetStatus || '').trim();
  const reason = (req.body || {}).reason || null;
  if (!targetStatus) return res.status(400).json({ error: 'targetStatus_required' });
  const owner = (await pool.query('SELECT owner_id FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!owner) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, owner.owner_id)) return res.status(403).json({ error: 'forbidden' });
  await pool.query(
    `UPDATE offers
        SET lifecycle_status = $1,
            lifecycle_updated_at = NOW(),
            lifecycle_reason = $2,
            published_at = CASE WHEN $1 = 'active' THEN NOW() ELSE published_at END,
            redeemed_at = CASE WHEN $1 = 'redeemed' THEN NOW() ELSE redeemed_at END,
            expired_at = CASE WHEN $1 = 'expired' THEN NOW() ELSE expired_at END,
            archived_at = CASE WHEN $1 = 'archived' THEN NOW() ELSE archived_at END
      WHERE id = $3`,
    [targetStatus, reason, req.params.id]
  );
  res.json({ ok: true });
});

app.post('/api/offers/:id/lifecycle/sync-temporal', auth, async (req, res) => {
  const row = (await pool.query('SELECT id, lifecycle_status, start_date, end_date FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  const owner = (await pool.query('SELECT owner_id FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!canAccessUserObject(req.user, owner.owner_id)) return res.status(403).json({ error: 'forbidden' });
  const now = new Date();
  let status = row.lifecycle_status;
  if (row.end_date && new Date(row.end_date) < now) status = 'expired';
  else if ((status === 'approved' || status === 'pending_review') && row.start_date && new Date(row.start_date) <= now) status = 'active';
  if (status !== row.lifecycle_status) {
    await pool.query('UPDATE offers SET lifecycle_status = $1, lifecycle_updated_at = NOW(), lifecycle_reason = $2 WHERE id = $3', [status, 'temporal_sync', req.params.id]);
  }
  res.json({ ok: true, lifecycleStatus: status });
});

app.get('/api/stats/counts', auth, async (req, res) => {
  const userId = req.user.userId;
  const offers = (await pool.query('SELECT COUNT(*)::int AS c FROM offers')).rows[0].c;
  const community = (await pool.query('SELECT COUNT(*)::int AS c FROM groups')).rows[0].c;
  const rewards = userId
    ? (await pool.query('SELECT available_points::int AS p FROM point_accounts WHERE owner_id = $1', [userId])).rows[0]?.p || 0
    : 0;
  res.json({ offers, community, rewards });
});

};
