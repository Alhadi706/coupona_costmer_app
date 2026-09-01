const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerRewardsRoutes(app, deps) {
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
    REWARDS_WITH_STORE_NAME_SQL,
    matchesPeerAdCategory, parseGeoJson, matchesPeerAdGeo, mapRewardRow, validateRewardSource,
    analyticsRangeDays, analyticsDaysAgo, analyticsSafeNumber, analyticsPercentChange,
    analyticsAgeBucket, analyticsCountEntries, analyticsTopEntries,
  } = deps;

app.get('/api/rewards', auth, async (_req, res) => {
  const rows = (await pool.query(
    `${REWARDS_WITH_STORE_NAME_SQL} WHERE r.is_active = TRUE AND (r.quantity_limit IS NULL OR r.quantity_redeemed < r.quantity_limit) AND (r.expires_at IS NULL OR r.expires_at > NOW()) ORDER BY r.value DESC`
  )).rows;
  res.json(rows.map(mapRewardRow));
});

app.get('/api/merchant/rewards', auth, async (req, res) => {
  const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
  if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
  const rows = (await pool.query(
    `${REWARDS_WITH_STORE_NAME_SQL} WHERE r.source_type = 'merchant' AND r.source_id = $1 ORDER BY r.created_at DESC`,
    [merchantId]
  )).rows;
  return res.json(rows.map((row) => ({ ...mapRewardRow(row), isActive: row.is_active, quantityLimit: row.quantity_limit, quantityRedeemed: row.quantity_redeemed })));
});

app.get('/api/brand/rewards', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const rows = (await pool.query(
    `${REWARDS_WITH_STORE_NAME_SQL} WHERE r.source_type = 'brand' AND r.source_id = $1 ORDER BY r.created_at DESC`,
    [brandId]
  )).rows;
  return res.json(rows.map((row) => ({ ...mapRewardRow(row), isActive: row.is_active, quantityLimit: row.quantity_limit, quantityRedeemed: row.quantity_redeemed, pickupInstructions: row.pickup_instructions, drawEnabled: row.draw_enabled, drawAt: toIso(row.draw_at) })));
});

app.get('/api/brand/products', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const rows = (await pool.query(
    `SELECT id, name, image_url, barcode, created_at
       FROM product_registry
      WHERE brand_id = $1
      ORDER BY created_at DESC`,
    [brandId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    name: row.name,
    imageUrl: row.image_url,
    barcode: row.barcode,
    createdAt: toIso(row.created_at),
  })));
});

app.post('/api/brand/rewards', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const p = req.body || {};
  const name = String(p.rewardName || '').trim();
  const value = Number(p.value);
  const quantityLimit = p.quantityLimit == null || String(p.quantityLimit).trim() === '' ? null : Number(p.quantityLimit);
  const drawEnabled = Boolean(p.drawEnabled);
  if (!name || !Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_reward' });
  if (quantityLimit != null && (!Number.isInteger(quantityLimit) || quantityLimit <= 0)) return res.status(400).json({ error: 'invalid_quantity_limit' });
  if (drawEnabled && !p.expiresAt) return res.status(400).json({ error: 'draw_expiry_required' });
  const drawDisclosure = 'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك المكتسبة من مشترياتك العادية.';
  const description = String(p.description || '').trim();
  const safeDescription = drawEnabled && !description.includes('لا حاجة لأي شراء إضافي')
    ? `${description ? `${description}\n` : ''}${drawDisclosure}`
    : (description || null);
  const result = await pool.query(
    `INSERT INTO rewards (id, reward_name, description, value, kind, source_type, source_id, image_url, expires_at, is_active, quantity_limit, pickup_instructions, draw_enabled, draw_at)
     VALUES ($1,$2,$3,$4,$5,'brand',$6,$7,$8,TRUE,$9,$10,$11,$12) RETURNING id`,
    [id(), name, safeDescription, value, p.kind === 'physical' ? 'physical' : 'digital', brandId, String(p.imageUrl || '').trim() || null, p.expiresAt || null, quantityLimit, String(p.pickupInstructions || '').trim() || null, drawEnabled, p.drawAt || p.expiresAt || null]
  );
  return res.json({ ok: true, id: result.rows[0].id, status: 'active' });
});

app.post('/api/brand/rewards/:id/draw', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const reward = (await client.query(
      `SELECT id, reward_name, expires_at, draw_enabled, draw_winner_user_id
         FROM rewards
        WHERE id = $1 AND source_type = 'brand' AND source_id = $2
        FOR UPDATE`,
      [req.params.id, brandId]
    )).rows[0];
    if (!reward) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'reward_not_found' }); }
    if (!reward.draw_enabled) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'draw_not_enabled' }); }
    if (reward.draw_winner_user_id) { await client.query('ROLLBACK'); return res.json({ ok: true, winnerUserId: reward.draw_winner_user_id, alreadyCompleted: true }); }
    if (reward.expires_at && new Date(reward.expires_at) > new Date()) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'draw_not_due' }); }
    const candidates = (await client.query(
      `SELECT DISTINCT owner_id
         FROM reward_claims
        WHERE reward_id = $1 AND status IN ('pending_pickup', 'redeemed')`,
      [reward.id]
    )).rows;
    if (!candidates.length) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'no_draw_candidates' }); }
    const winner = candidates[Math.floor(Math.random() * candidates.length)].owner_id;
    await client.query('UPDATE rewards SET draw_winner_user_id = $1, draw_completed_at = NOW() WHERE id = $2', [winner, reward.id]);
    await insertNotification(client, winner, 'reward_draw_winner', 'مبروك! فزت بالجائزة', `تم اختيارك عشوائياً للفوز بجائزة ${reward.reward_name}. لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك المكتسبة من مشترياتك العادية.`, { rewardId: reward.id });
    await client.query('COMMIT');
    return res.json({ ok: true, winnerUserId: winner });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'reward_draw_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/rewards', auth, async (req, res) => {
  const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
  if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
  const p = req.body || {};
  const name = String(p.rewardName || '').trim();
  const value = Number(p.value);
  const quantityLimit = p.quantityLimit == null || String(p.quantityLimit).trim() === '' ? null : Number(p.quantityLimit);
  if (!name || !Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_reward' });
  if (quantityLimit != null && (!Number.isInteger(quantityLimit) || quantityLimit <= 0)) return res.status(400).json({ error: 'invalid_quantity_limit' });
  const result = await pool.query(
    `INSERT INTO rewards (id, reward_name, description, value, kind, source_type, source_id, image_url, expires_at, is_active, quantity_limit)
     VALUES ($1,$2,$3,$4,$5,'merchant',$6,$7,$8,TRUE,$9) RETURNING id`,
    [id(), name, String(p.description || '').trim() || null, value, p.kind === 'digital' ? 'digital' : 'physical', merchantId, String(p.imageUrl || '').trim() || null, p.expiresAt || null, quantityLimit]
  );
  return res.json({ ok: true, id: result.rows[0].id, status: 'active' });
});

app.patch('/api/merchant/rewards/:id', auth, async (req, res) => {
  const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
  if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
  const p = req.body || {};
  const result = await pool.query(
    `UPDATE rewards SET is_active = COALESCE($1, is_active), quantity_limit = $2, expires_at = $3, description = COALESCE($4, description)
      WHERE id = $5 AND source_type = 'merchant' AND source_id = $6 RETURNING id`,
    [p.isActive == null ? null : Boolean(p.isActive), p.quantityLimit == null || String(p.quantityLimit).trim() === '' ? null : Number(p.quantityLimit), p.expiresAt || null, p.description == null ? null : String(p.description).trim(), req.params.id, merchantId]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'reward_not_found' });
  return res.json({ ok: true });
});

app.get('/api/admin/rewards', auth, requireAdmin, async (_req, res) => {
  const rows = (await pool.query(`${REWARDS_WITH_STORE_NAME_SQL} ORDER BY r.value DESC`)).rows;
  res.json(rows.map(mapRewardRow));
});

app.post('/api/admin/rewards', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const rewardName = String(p.rewardName || '').trim();
  if (!rewardName) return res.status(400).json({ error: 'reward_name_required' });
  const value = Number(p.value);
  if (!Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_value' });
  const kind = p.kind === 'physical' ? 'physical' : 'digital';
  const sourceType = ['merchant', 'brand', 'system'].includes(p.sourceType) ? p.sourceType : 'system';
  const sourceId = String(p.sourceId || '').trim();
  if (sourceType !== 'system' && !sourceId) return res.status(400).json({ error: 'source_id_required' });
  const sourceError = sourceType === 'system' ? null : await validateRewardSource(sourceType, sourceId);
  if (sourceError) return res.status(400).json({ error: sourceError });
  const description = String(p.description || '').trim() || null;
  const imageUrl = String(p.imageUrl || '').trim() || null;
  let expiresAt = null;
  if (p.expiresAt) {
    expiresAt = new Date(p.expiresAt);
    if (Number.isNaN(expiresAt.getTime())) return res.status(400).json({ error: 'invalid_expires_at' });
  }
  const rewardId = id();
  await pool.query(
    `INSERT INTO rewards (id, reward_name, description, value, kind, source_type, source_id, image_url, expires_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [rewardId, rewardName, description, value, kind, sourceType === 'system' ? null : sourceType, sourceType === 'system' ? null : sourceId, imageUrl, expiresAt]
  );
  res.json({ ok: true, id: rewardId });
});

app.put('/api/admin/rewards/:id', auth, requireAdmin, async (req, res) => {
  const existing = await pool.query('SELECT id FROM rewards WHERE id = $1', [req.params.id]);
  if (!existing.rowCount) return res.status(404).json({ error: 'reward_not_found' });
  const p = req.body || {};
  const rewardName = String(p.rewardName || '').trim();
  if (!rewardName) return res.status(400).json({ error: 'reward_name_required' });
  const value = Number(p.value);
  if (!Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_value' });
  const kind = p.kind === 'physical' ? 'physical' : 'digital';
  const sourceType = ['merchant', 'brand', 'system'].includes(p.sourceType) ? p.sourceType : 'system';
  const sourceId = String(p.sourceId || '').trim();
  if (sourceType !== 'system' && !sourceId) return res.status(400).json({ error: 'source_id_required' });
  const sourceError = sourceType === 'system' ? null : await validateRewardSource(sourceType, sourceId);
  if (sourceError) return res.status(400).json({ error: sourceError });
  const description = String(p.description || '').trim() || null;
  const imageUrl = String(p.imageUrl || '').trim() || null;
  let expiresAt = null;
  if (p.expiresAt) {
    expiresAt = new Date(p.expiresAt);
    if (Number.isNaN(expiresAt.getTime())) return res.status(400).json({ error: 'invalid_expires_at' });
  }
  await pool.query(
    `UPDATE rewards SET reward_name = $2, description = $3, value = $4, kind = $5,
       source_type = $6, source_id = $7, image_url = $8, expires_at = $9
     WHERE id = $1`,
    [req.params.id, rewardName, description, value, kind, sourceType === 'system' ? null : sourceType, sourceType === 'system' ? null : sourceId, imageUrl, expiresAt]
  );
  res.json({ ok: true });
});

app.delete('/api/admin/rewards/:id', auth, requireAdmin, async (req, res) => {
  const result = await pool.query('DELETE FROM rewards WHERE id = $1', [req.params.id]);
  if (!result.rowCount) return res.status(404).json({ error: 'reward_not_found' });
  res.json({ ok: true });
});

app.get('/api/activity-logs', auth, async (req, res) => {
  const email = String(req.query.customerEmail || '').trim().toLowerCase();
  if (!email) return res.json([]);
  const rows = (await pool.query('SELECT * FROM activity_logs WHERE customer_email = $1 ORDER BY transaction_date DESC', [email])).rows;
  res.json(rows.map((a) => ({ id: a.id, customerEmail: a.customer_email, amount: Number(a.amount), transaction_date: toIso(a.transaction_date) })));
});

};
