const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerOffersBillboardRoutes(app, deps) {
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

app.post('/api/offers/targeted', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!merchantId && !brandId) {
      return res.status(403).json({ error: 'merchant_or_brand_role_required' });
    }

  const p = req.body || {};
  const offerId = id();
  const targetType = String(p.targetType || 'all').trim();
  const minPoints = Number.isFinite(Number(p.minPoints)) ? Number(p.minPoints) : null;
  const criteriaInput = p.criteria && typeof p.criteria === 'object' ? p.criteria : null;
  const targetValue = targetType === 'demographic_geo'
    ? JSON.stringify({
        minAge: Number.isFinite(Number(criteriaInput?.minAge)) ? Number(criteriaInput.minAge) : null,
        maxAge: Number.isFinite(Number(criteriaInput?.maxAge)) ? Number(criteriaInput.maxAge) : null,
        gender: String(criteriaInput?.gender || '').trim() || 'any',
        city: String(criteriaInput?.city || '').trim() || null,
        country: String(criteriaInput?.country || '').trim() || null,
        centerLat: Number.isFinite(Number(criteriaInput?.centerLat)) ? Number(criteriaInput.centerLat) : null,
        centerLng: Number.isFinite(Number(criteriaInput?.centerLng)) ? Number(criteriaInput.centerLng) : null,
        maxDistanceKm: Number.isFinite(Number(criteriaInput?.maxDistanceKm)) ? Number(criteriaInput.maxDistanceKm) : null,
      })
    : (String(p.targetValue || '').trim() || null);
  await client.query(
    `INSERT INTO offers (
      id, owner_id, offer_type, category, title_type, discount_type, discount_value, price,
      description, start_date, end_date, location, image_url, created_at,
      lifecycle_status, lifecycle_updated_at, lifecycle_reason
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW(),'active',NOW(),$14
    )`,
    [
      offerId,
      req.user.userId,
      p.offerType || 'targeted',
      p.category || 'general',
      p.titleType || 'targeted_offer',
      p.discountType || null,
      p.discountValue || null,
      p.price || null,
      p.description || null,
      p.startDate || null,
      p.endDate || null,
      p.location || null,
      p.imageUrl || p.image || null,
      p.lifecycleReason || 'targeted_offer_created',
    ]
  );
  await client.query(
    `INSERT INTO offer_targeting_rules (offer_id, target_type, target_value, min_points, criteria_json)
     VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [offerId, targetType, targetValue, minPoints, targetType === 'demographic_geo' ? targetValue : null]
  );

  let audience = [];
  if (targetType === 'all') {
    audience = (await client.query('SELECT id FROM users ORDER BY created_at DESC LIMIT 1000')).rows;
  } else if (targetType === 'min_points') {
    audience = (await client.query(
      `SELECT u.id
         FROM users u
         JOIN point_accounts pa ON pa.owner_id = u.id
        WHERE pa.available_points >= $1
        ORDER BY pa.available_points DESC
        LIMIT 1000`,
      [minPoints || 0]
    )).rows;
  } else if (targetType === 'city') {
    audience = (await client.query(
      `SELECT id
         FROM users
        WHERE LOWER(COALESCE(city, '')) = LOWER($1)
        ORDER BY created_at DESC
        LIMIT 1000`,
      [targetValue || '']
    )).rows;
  } else if (targetType === 'demographic_geo') {
    const users = (await client.query(
      `SELECT u.id,
              u.city,
              u.country,
              u.gender,
              u.birth_date,
              cp.location_lat,
              cp.location_lng,
              COALESCE(pa.available_points, 0) AS available_points
         FROM users u
         LEFT JOIN customer_profiles cp ON cp.user_id = u.id
         LEFT JOIN point_accounts pa ON pa.owner_id = u.id
         ORDER BY u.created_at DESC
         LIMIT 2000`
    )).rows;
    audience = users.filter((u) => offerMatchesTargeting(
      {
        target_type: targetType,
        target_value: targetValue,
        criteria_json: targetType === 'demographic_geo' ? JSON.parse(targetValue) : null,
        min_points: minPoints,
      },
      {
        userId: u.id,
        city: u.city,
        country: u.country,
        gender: u.gender,
        age: calculateAgeYears(u.birth_date),
        locationLat: u.location_lat == null ? null : Number(u.location_lat),
        locationLng: u.location_lng == null ? null : Number(u.location_lng),
        availablePoints: Number(u.available_points || 0),
      }
    ));
  }

  for (const row of audience) {
    await insertNotification(
      client,
      row.id,
      'targeted_offer',
      'New targeted offer',
      p.description || 'You have a new offer tailored for you.',
      { offerId, targetType }
    );
  }

  return res.json({ ok: true, id: offerId, audienceSize: audience.length });
  } catch (e) {
    return res.status(500).json({ error: 'targeted_offer_create_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/offers/targeted/feed', auth, async (req, res) => {
  const userId = req.user.userId;
  const user = (await pool.query(
    `SELECT u.city,
            u.country,
            u.gender,
            u.birth_date,
            cp.location_lat,
            cp.location_lng
       FROM users u
       LEFT JOIN customer_profiles cp ON cp.user_id = u.id
      WHERE u.id = $1
      LIMIT 1`,
    [userId]
  )).rows[0] || {};
  const points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1 LIMIT 1', [userId])).rows[0]?.available_points || 0;

  const rows = (await pool.query(
    `SELECT o.*, otr.target_type, otr.target_value, otr.min_points, otr.criteria_json
       FROM offers o
       JOIN offer_targeting_rules otr ON otr.offer_id = o.id
      WHERE o.lifecycle_status = 'active'
      ORDER BY o.created_at DESC`
  )).rows;

  const eligible = rows.filter((row) => offerMatchesTargeting(row, {
    userId,
    city: user.city,
    country: user.country,
    gender: user.gender,
    age: calculateAgeYears(user.birth_date),
    locationLat: user.location_lat == null ? null : Number(user.location_lat),
    locationLng: user.location_lng == null ? null : Number(user.location_lng),
    availablePoints: Number(points || 0),
  }));

  return res.json(eligible.map((o) => ({
    id: o.id,
    offerType: o.offer_type,
    category: o.category,
    titleType: o.title_type,
    discountType: o.discount_type,
    discountValue: o.discount_value,
    price: o.price,
    description: o.description,
    startDate: toIso(o.start_date),
    endDate: toIso(o.end_date),
    location: o.location,
    imageUrl: o.image_url,
    targetType: o.target_type,
    targetValue: o.target_value,
    minPoints: o.min_points,
    createdAt: toIso(o.created_at),
  })));
});

app.get('/api/offers', auth, async (req, res) => {
  const { category, targetType, targetValue, minPoints } = req.query;

  const userRow = (await pool.query(
    `SELECT u.id,
            u.city,
            u.country,
            u.gender,
            u.birth_date,
            cp.location_lat,
            cp.location_lng
       FROM users u
       LEFT JOIN customer_profiles cp ON cp.user_id = u.id
      WHERE u.id = $1
      LIMIT 1`,
    [req.user.userId]
  )).rows[0] || {};
  const pointsRow = (await pool.query(
    'SELECT available_points FROM point_accounts WHERE owner_id = $1 LIMIT 1',
    [req.user.userId]
  )).rows[0] || {};

  const baseSql = category
    ? `SELECT o.*, otr.target_type, otr.target_value, otr.min_points, otr.criteria_json
         FROM offers o
         LEFT JOIN offer_targeting_rules otr ON otr.offer_id = o.id
        WHERE o.category = $1
        ORDER BY o.created_at DESC`
    : `SELECT o.*, otr.target_type, otr.target_value, otr.min_points, otr.criteria_json
         FROM offers o
         LEFT JOIN offer_targeting_rules otr ON otr.offer_id = o.id
        ORDER BY o.created_at DESC`;
  const params = category ? [category] : [];
  const rows = (await pool.query(baseSql, params)).rows;

  const userContext = {
    userId: req.user.userId,
    city: userRow.city,
    country: userRow.country,
    gender: userRow.gender,
    age: calculateAgeYears(userRow.birth_date),
    locationLat: userRow.location_lat == null ? null : Number(userRow.location_lat),
    locationLng: userRow.location_lng == null ? null : Number(userRow.location_lng),
    availablePoints: Number(pointsRow.available_points || 0),
  };

  let eligible = rows.filter((row) => offerMatchesTargeting(row, userContext));
  if (targetType) {
    const targetTypeRaw = String(targetType).toLowerCase();
    eligible = eligible.filter((row) => String(row.target_type || 'all').toLowerCase() === targetTypeRaw);
  }
  if (targetValue) {
    const tv = String(targetValue).toLowerCase();
    eligible = eligible.filter((row) => String(row.target_value || '').toLowerCase() === tv);
  }
  if (minPoints != null && String(minPoints).trim() !== '') {
    const mp = Number(minPoints);
    if (Number.isFinite(mp)) {
      eligible = eligible.filter((row) => Number(row.min_points || 0) >= mp);
    }
  }

  res.json(eligible.map((o) => ({
    id: o.id,
    offerType: o.offer_type,
    category: o.category,
    titleType: o.title_type,
    discountType: o.discount_type,
    discountValue: o.discount_value,
    price: o.price,
    description: o.description,
    startDate: toIso(o.start_date),
    endDate: toIso(o.end_date),
    location: o.location,
    image: o.image_url,
    imageUrl: o.image_url,
    createdAt: toIso(o.created_at),
    lifecycleStatus: o.lifecycle_status,
    lifecycleUpdatedAt: toIso(o.lifecycle_updated_at),
    lifecycleReason: o.lifecycle_reason,
    publishedAt: toIso(o.published_at),
    redeemedAt: toIso(o.redeemed_at),
    expiredAt: toIso(o.expired_at),
    archivedAt: toIso(o.archived_at),
    targetType: o.target_type || 'all',
    targetValue: o.target_value,
    minPoints: o.min_points,
    ctaType: o.cta_type || 'store',
    ctaValue: o.cta_value,
    impressions: Number(o.impressions || 0),
    clicks: Number(o.clicks || 0),
  })));
});

app.post('/api/offers', auth, async (req, res) => {
  const p = req.body || {};
  const offerId = id();
  await pool.query(
    `INSERT INTO offers (
      id, owner_id, offer_type, category, title_type, discount_type, discount_value, price,
      description, start_date, end_date, location, image_url, created_at,
      lifecycle_status, lifecycle_updated_at, lifecycle_reason, cta_type, cta_value
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,COALESCE($14::timestamptz,NOW()),
      'pending_review',NOW(),'created_from_api',$15,$16
    )`,
    [
      offerId, req.user.userId, p.offerType, p.category, p.titleType, p.discountType, p.discountValue, p.price,
      p.description, p.startDate, p.endDate, p.location, p.imageUrl || p.image, p.createdAt,
      String(p.ctaType || 'store'), String(p.ctaValue || '').trim() || null,
    ]
  );
  res.json({ id: offerId, ok: true });
});

app.get('/api/billboard-ads', auth, async (_req, res) => {
  const rows = (await pool.query(
    `SELECT id, offer_type, category, description, location, image_url, start_date, end_date,
            created_at, published_at
       FROM offers
      WHERE image_url IS NOT NULL
        AND image_url <> ''
        AND lifecycle_status = 'active'
        AND (start_date IS NULL OR start_date <= NOW())
        AND (end_date IS NULL OR end_date > NOW())
      ORDER BY published_at DESC NULLS LAST, created_at DESC
      LIMIT 30`
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    offerType: row.offer_type,
    category: row.category,
    description: row.description,
    location: row.location,
    imageUrl: row.image_url,
    startDate: toIso(row.start_date),
    endDate: toIso(row.end_date),
    createdAt: toIso(row.created_at),
    publishedAt: toIso(row.published_at),
  })));
});

app.post('/api/billboard-ads/:id/impression', auth, async (req, res) => {
  const result = await pool.query(
    `UPDATE offers SET impressions = impressions + 1
      WHERE id = $1 AND lifecycle_status = 'active' AND image_url IS NOT NULL
      RETURNING impressions`,
    [req.params.id]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, impressions: Number(result.rows[0].impressions || 0) });
});

app.post('/api/billboard-ads/:id/click', auth, async (req, res) => {
  const result = await pool.query(
    `UPDATE offers SET clicks = clicks + 1
      WHERE id = $1 AND lifecycle_status = 'active' AND image_url IS NOT NULL
      RETURNING clicks, cta_type, cta_value`,
    [req.params.id]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, clicks: Number(result.rows[0].clicks || 0), ctaType: result.rows[0].cta_type || 'store', ctaValue: result.rows[0].cta_value });
});

app.get('/api/admin/billboard-ads', auth, requireAdmin, async (_req, res) => {
  const rows = (await pool.query(
    `SELECT id, owner_id, offer_type, category, description, location, image_url,
            lifecycle_status, lifecycle_reason, created_at
       FROM offers
      WHERE image_url IS NOT NULL AND image_url <> ''
      ORDER BY created_at DESC
      LIMIT 200`
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    ownerId: row.owner_id,
    offerType: row.offer_type,
    category: row.category,
    description: row.description,
    location: row.location,
    imageUrl: row.image_url,
    lifecycleStatus: row.lifecycle_status,
    lifecycleReason: row.lifecycle_reason,
    createdAt: toIso(row.created_at),
  })));
});

app.post('/api/admin/billboard-ads/:id/approve', auth, requireAdmin, async (req, res) => {
  const result = await pool.query(
    `UPDATE offers
        SET lifecycle_status = 'active', lifecycle_updated_at = NOW(),
            lifecycle_reason = 'approved_by_admin', published_at = NOW()
      WHERE id = $1 AND image_url IS NOT NULL
      RETURNING id`,
    [req.params.id]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, status: 'active' });
});

app.post('/api/admin/billboard-ads/:id/reject', auth, requireAdmin, async (req, res) => {
  const reason = String((req.body || {}).reason || 'Rejected by admin').trim();
  const result = await pool.query(
    `UPDATE offers
        SET lifecycle_status = 'rejected', lifecycle_updated_at = NOW(), lifecycle_reason = $2
      WHERE id = $1 AND image_url IS NOT NULL
      RETURNING id`,
    [req.params.id, reason]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, status: 'rejected', reason });
});

};
