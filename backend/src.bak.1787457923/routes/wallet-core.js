const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerWalletCoreRoutes(app, deps) {
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

app.post('/api/wallet/ensure', auth, async (req, res) => {
  const userId = req.user.userId;
  await pool.query('INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,\'SAR\',NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  await pool.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  res.json({ ok: true });
});

app.get('/api/wallet', auth, async (req, res) => {
  const userId = req.user.userId;
  await pool.query('INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,\'SAR\',NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  const row = (await pool.query('SELECT * FROM wallet_accounts WHERE owner_id = $1', [userId])).rows[0];
  res.json({ ownerId: row.owner_id, balance: Number(row.balance), currency: row.currency, updatedAt: toIso(row.updated_at) });
});

app.get('/api/wallet/points', auth, async (req, res) => {
  const userId = req.user.userId;
  await pool.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  const row = (await pool.query('SELECT * FROM point_accounts WHERE owner_id = $1', [userId])).rows[0];
  res.json({ ownerId: row.owner_id, availablePoints: row.available_points, lifetimePoints: row.lifetime_points, updatedAt: toIso(row.updated_at) });
});

app.get('/api/wallet/points-breakdown', auth, async (req, res) => {
  const userId = req.user.userId;
  const [merchantRows, brandRows] = await Promise.all([
    pool.query(
      `SELECT f.merchant_id,
              f.fraction_balance,
              f.updated_at,
              m.business_name
         FROM customer_merchant_fraction_balance f
         LEFT JOIN merchant_profiles m ON m.id = f.merchant_id
        WHERE f.customer_id = $1
        ORDER BY f.updated_at DESC`,
      [userId]
    ),
    pool.query(
      `SELECT f.brand_id,
              f.fraction_balance,
              f.updated_at,
              b.business_name
         FROM customer_brand_fraction_balance f
         LEFT JOIN brand_profiles b ON b.id = f.brand_id
        WHERE f.customer_id = $1
        ORDER BY f.updated_at DESC`,
      [userId]
    ),
  ]);

  return res.json({
    ownerId: userId,
    merchantFractions: merchantRows.rows.map((r) => ({
      merchantId: r.merchant_id,
      merchantName: r.business_name,
      fraction: Number(r.fraction_balance || 0),
      updatedAt: toIso(r.updated_at),
    })),
    brandFractions: brandRows.rows.map((r) => ({
      brandId: r.brand_id,
      brandName: r.business_name,
      fraction: Number(r.fraction_balance || 0),
      updatedAt: toIso(r.updated_at),
    })),
  });
});

app.get('/api/wallet/points/sources', auth, async (req, res) => {
  const userId = req.user.userId;
  const [merchantRows, brandRows] = await Promise.all([
    pool.query(
      `SELECT m.id AS source_id,
              m.business_name AS source_name,
              COALESCE(SUM(CASE WHEN plm.status = 'active' THEN plm.points_delta ELSE 0 END), 0) AS active_points,
              COALESCE(SUM(plm.points_delta), 0) AS lifetime_points
         FROM points_ledger_merchant plm
         JOIN merchant_profiles m ON m.id = plm.merchant_id
        WHERE plm.customer_id = $1
        GROUP BY m.id, m.business_name
        ORDER BY m.business_name ASC`,
      [userId]
    ),
    pool.query(
      `SELECT b.id AS source_id,
              b.business_name AS source_name,
              COALESCE(SUM(CASE WHEN plb.status = 'active' THEN plb.points_delta ELSE 0 END), 0) AS active_points,
              COALESCE(SUM(plb.points_delta), 0) AS lifetime_points
         FROM points_ledger_brand plb
         JOIN brand_profiles b ON b.id = plb.brand_id
        WHERE plb.customer_id = $1
        GROUP BY b.id, b.business_name
        ORDER BY b.business_name ASC`,
      [userId]
    ),
  ]);

  return res.json({
    ownerId: userId,
    merchantSources: merchantRows.rows.map((r) => ({
      sourceId: r.source_id,
      sourceName: r.source_name,
      activePoints: Number(r.active_points || 0),
      lifetimePoints: Number(r.lifetime_points || 0),
    })),
    brandSources: brandRows.rows.map((r) => ({
      sourceId: r.source_id,
      sourceName: r.source_name,
      activePoints: Number(r.active_points || 0),
      lifetimePoints: Number(r.lifetime_points || 0),
    })),
  });
});

app.get('/api/wallet/ledger', auth, async (req, res) => {
  const userId = req.user.userId;
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query('SELECT * FROM ledger_entries WHERE owner_id = $1 ORDER BY created_at DESC LIMIT $2', [userId, limit])).rows;
  res.json(rows.map((l) => ({
    ownerId: l.owner_id,
    type: l.type,
    amount: Number(l.amount),
    points: l.points,
    reference: l.reference,
    createdAt: toIso(l.created_at),
  })));
});

app.post('/api/wallet/cashback', auth, async (req, res) => {
  const userId = req.user.userId;
  const purchaseAmount = Number((req.body || {}).purchaseAmount || 0);
  const reference = String((req.body || {}).reference || '').trim();
  if (!Number.isFinite(purchaseAmount) || purchaseAmount <= 0 || !reference) {
    return res.status(400).json({ error: 'invalid_payload' });
  }
  const cashback = Number((purchaseAmount * 0.05).toFixed(2));
  const earnedPoints = Math.floor(purchaseAmount);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,\'SAR\',NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    await client.query('UPDATE wallet_accounts SET balance = balance + $1, updated_at = NOW() WHERE owner_id = $2', [cashback, userId]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $1, lifetime_points = lifetime_points + $1, updated_at = NOW() WHERE owner_id = $2', [earnedPoints, userId]);
    await client.query('UPDATE users SET points = points + $1, points_history = points_history || to_jsonb($2::int) WHERE id = $3', [earnedPoints, earnedPoints, userId]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'cashbackEarned', cashback, 0, reference]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'pointsEarned', 0, earnedPoints, reference]);
    await client.query('COMMIT');
    res.json({ ok: true, cashback, earnedPoints });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: 'cashback_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/wallet/redeem', auth, async (req, res) => {
  const userId = req.user.userId;
  const points = Number((req.body || {}).points || 0);
  const reference = String((req.body || {}).reference || '').trim();
  if (!Number.isInteger(points) || points <= 0 || !reference) {
    return res.status(400).json({ error: 'invalid_payload' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    const row = (await client.query('SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE', [userId])).rows[0];
    if (!row || Number(row.available_points) < points) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'insufficient_points' });
    }
    await client.query('UPDATE point_accounts SET available_points = available_points - $1, updated_at = NOW() WHERE owner_id = $2', [points, userId]);
    await client.query('UPDATE users SET points = GREATEST(points - $1, 0) WHERE id = $2', [points, userId]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'pointsRedeemed', 0, points, reference]);
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: 'redeem_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

};
