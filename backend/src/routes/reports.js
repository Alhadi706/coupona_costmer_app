const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerReportsRoutes(app, deps) {
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

app.get('/api/reports/store-options', auth, async (req, res) => {
  const search = String(req.query.q || '').trim();
  if (!search) {
    const latest = (await pool.query(
      `SELECT DISTINCT ON (COALESCE(i.merchant_profile_id, i.merchant_name))
              COALESCE(i.merchant_profile_id, 'visited:' || i.id) AS store_id,
              COALESCE(mp.business_name, i.merchant_name, 'Unknown merchant') AS store_name,
              mp.location_lat, mp.location_lng, mp.location_address,
              i.created_at
         FROM invoice_scans i
         LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
        WHERE i.owner_id = $1 AND i.state = 'approved'
        ORDER BY COALESCE(i.merchant_profile_id, i.merchant_name), i.created_at DESC`,
      [req.user.userId]
    )).rows
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, 3);
    return res.json(latest.map((store) => ({
      storeId: store.store_id,
      storeName: store.store_name,
      locationLat: store.location_lat == null ? null : Number(store.location_lat),
      locationLng: store.location_lng == null ? null : Number(store.location_lng),
      locationAddress: store.location_address,
      isRegistered: !String(store.store_id).startsWith('visited:'),
    })));
  }
  const registeredStores = (await pool.query(
    `SELECT id, business_name, location_lat, location_lng, location_address
       FROM merchant_profiles
      WHERE COALESCE(business_name, '') <> ''
      AND business_name ILIKE $1
      ORDER BY business_name ASC
      LIMIT 50`,
    [`%${search}%`]
  )).rows;
  const invoiceRows = (await pool.query(
    `SELECT i.id, i.merchant_profile_id, i.merchant_name, i.merchant_key, i.created_at,
            mp.business_name
       FROM invoice_scans i
       LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
      WHERE i.owner_id = $1 AND i.state = 'approved'
      ORDER BY i.created_at DESC`,
    [req.user.userId]
  )).rows;
  const grouped = new Map();
  for (const invoice of invoiceRows) {
    let storeId = invoice.merchant_profile_id;
    let storeName = invoice.business_name || invoice.merchant_name || 'Unknown merchant';
    if (!storeId) {
      storeId = await resolveMerchantProfileIdByKey(pool, invoice.merchant_key || invoice.merchant_name);
      if (storeId) {
        const profile = (await pool.query('SELECT business_name FROM merchant_profiles WHERE id = $1 LIMIT 1', [storeId])).rows[0];
        storeName = profile?.business_name || storeName;
        await pool.query('UPDATE invoice_scans SET merchant_profile_id = $1 WHERE id = $2', [storeId, invoice.id]);
      }
    }
    // A receipt can belong to a real place that has not onboarded yet. Keep it
    // selectable as a visited store using the invoice as a stable reference.
    if (!storeId) storeId = `visited:${invoice.id}`;
    const current = grouped.get(storeId) || { storeId, storeName, interactionsCount: 0, lastInteractedAt: invoice.created_at };
    current.interactionsCount += 1;
    grouped.set(storeId, current);
  }

  const registeredIds = new Set(registeredStores.map((store) => store.id));
  const visitedUnregistered = [...grouped.values()]
    .filter((store) => String(store.storeId).startsWith('visited:'))
    .map((store) => ({ ...store, lastInteractedAt: toIso(store.lastInteractedAt), isRegistered: false }));
  return res.json([
    ...registeredStores.map((store) => ({
      storeId: store.id,
      storeName: store.business_name,
      locationLat: store.location_lat == null ? null : Number(store.location_lat),
      locationLng: store.location_lng == null ? null : Number(store.location_lng),
      locationAddress: store.location_address,
      isRegistered: true,
    })),
    ...visitedUnregistered.filter((store) => !registeredIds.has(store.storeId)),
  ]);
});

app.get('/api/reports/product-options', auth, async (req, res) => {
  const query = String(req.query.q || '').trim();
  if (query.length < 2) return res.json([]);
  const rows = (await pool.query(
    `SELECT DISTINCT ON (LOWER(name)) name, brand_id, brand_name
       FROM (
         SELECT pr.name, pr.brand_id, bp.business_name AS brand_name
           FROM product_registry pr
           JOIN brand_profiles bp ON bp.id = pr.brand_id
          WHERE pr.name ILIKE $1
         UNION ALL
         SELECT li.item_name AS name, bm.brand_id, bp.business_name AS brand_name
           FROM invoice_line_items li
           JOIN invoice_scans i ON i.id = li.invoice_scan_id
           LEFT JOIN brand_matches bm ON bm.invoice_line_item_id = li.id
           LEFT JOIN brand_profiles bp ON bp.id = bm.brand_id
          WHERE i.state = 'approved' AND li.item_name ILIKE $1
       ) products
      WHERE COALESCE(name, '') <> ''
      ORDER BY LOWER(name), brand_id NULLS LAST
      LIMIT 12`,
    [`%${query}%`]
  )).rows;
  return res.json(rows.map((row) => ({
    name: row.name,
    brandId: row.brand_id,
    brandName: row.brand_name,
  })));
});

app.post('/api/reports', auth, async (req, res) => {
  const p = req.body || {};
  const reportType = String(p.reportType || 'other').trim() || 'other';
  let targetStoreId = String(p.targetStoreId || '').trim() || null;
  const targetBrandId = String(p.targetBrandId || '').trim() || null;
  const description = String(p.description || '').trim() || null;
  const imageUrl = String(p.imageUrl || '').trim() || null;
  const productName = String(p.productName || '').trim() || null;
  const locationLat = Number.isFinite(Number(p.locationLat)) ? Number(p.locationLat) : null;
  const locationLng = Number.isFinite(Number(p.locationLng)) ? Number(p.locationLng) : null;
  const locationAddress = String(p.locationAddress || '').trim() || null;

  if (!targetStoreId && !targetBrandId && (locationLat == null || locationLng == null)) {
    return res.status(400).json({ error: 'target_store_or_brand_or_location_required' });
  }

  let matchedBrandId = targetBrandId;
  if (!matchedBrandId && productName) {
    const productMatch = (await pool.query(
      `SELECT pr.brand_id
         FROM product_registry pr
         JOIN brand_profiles bp ON bp.id = pr.brand_id
        WHERE LOWER(pr.name) = LOWER($1)
           OR LOWER(pr.name) LIKE LOWER($2)
        ORDER BY CASE WHEN LOWER(pr.name) = LOWER($1) THEN 0 ELSE 1 END, pr.created_at DESC
        LIMIT 1`,
      [productName, `%${productName}%`]
    )).rows[0];
    matchedBrandId = productMatch?.brand_id || null;
  }

  let storeNameSnapshot = null;
  if (targetStoreId) {
    const visitedInvoiceId = targetStoreId.startsWith('visited:')
      ? targetStoreId.replace(/^visited:/, '')
      : null;
    const allowedStore = visitedInvoiceId
      ? (await pool.query(
          `SELECT i.merchant_profile_id AS store_id, COALESCE(mp.business_name, i.merchant_name, 'Unknown merchant') AS store_name
             FROM invoice_scans i LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
            WHERE i.owner_id = $1 AND i.state = 'approved' AND i.id = $2 LIMIT 1`,
          [req.user.userId, visitedInvoiceId]
        )).rows[0]
      : (await pool.query(
          'SELECT id AS store_id, business_name AS store_name FROM merchant_profiles WHERE id = $1 LIMIT 1',
          [targetStoreId]
        )).rows[0];
    if (!allowedStore) {
      return res.status(404).json({ error: 'store_not_found' });
    }
    storeNameSnapshot = allowedStore.store_name;
    if (visitedInvoiceId) targetStoreId = allowedStore.store_id || null;
    if (!targetStoreId && (locationLat == null || locationLng == null) && !matchedBrandId) {
      return res.status(400).json({ error: 'location_required_for_unregistered_store' });
    }
  }

  let brandNameSnapshot = null;
  if (matchedBrandId) {
    const brand = (await pool.query(
      'SELECT business_name FROM brand_profiles WHERE id = $1 LIMIT 1',
      [matchedBrandId]
    )).rows[0];
    if (!brand) {
      return res.status(404).json({ error: 'brand_not_found' });
    }
    brandNameSnapshot = brand.business_name;
  }

  const reportId = id();
  await pool.query(
    `INSERT INTO reports (
      id, owner_id, report_type, status, target_store_id, target_brand_id,
      description, image_url, target_store_name_snapshot, target_brand_name_snapshot,
      product_name, location_lat, location_lng, location_address, thank_you_sent_at
    ) VALUES (
      $1,$2,$3,'new',$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW()
    )`,
    [
      reportId,
      req.user.userId,
      reportType,
      targetStoreId,
      matchedBrandId,
      description,
      imageUrl,
      storeNameSnapshot,
      brandNameSnapshot,
      productName,
      locationLat,
      locationLng,
      locationAddress,
    ]
  );

  const thankYouMessage = 'We received your report and it is under review.';
  await insertNotification(
    pool,
    req.user.userId,
    'report_thank_you',
    'Thank you for your report',
    thankYouMessage,
    { reportId, targetScreen: 'reports' }
  );

  const recipientIds = new Set();
  if (matchedBrandId) {
    const brandOwner = (await pool.query('SELECT user_id FROM brand_profiles WHERE id = $1 LIMIT 1', [matchedBrandId])).rows[0]?.user_id;
    if (brandOwner) recipientIds.add(brandOwner);
  }
  if (targetStoreId) {
    const storeOwner = (await pool.query('SELECT user_id FROM merchant_profiles WHERE id = $1 LIMIT 1', [targetStoreId])).rows[0]?.user_id;
    if (storeOwner) recipientIds.add(storeOwner);
  }
  for (const recipientId of recipientIds) {
    await insertNotification(
      pool,
      recipientId,
      'new_report_received',
      'New product or store report',
      `A report${productName ? ` about ${productName}` : ''} needs your review.${locationLat != null ? ' The customer included a map location.' : ''}`,
      { reportId, targetScreen: 'reports', productName, locationLat, locationLng, imageUrl }
    );
  }

  const targetName = storeNameSnapshot || brandNameSnapshot || locationAddress || 'Unknown target';
  const confirmationMessage = `Report for ${targetName} created (id: ${reportId}, status: new).`;
  return res.json({
    ok: true,
    id: reportId,
    status: 'new',
    targetName,
    thankYouMessage,
    confirmationMessage,
  });
});

app.get('/api/merchant/reports/inbox', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    const rows = (await client.query(
      `SELECT r.id,
              r.owner_id,
              u.email AS owner_email,
              u.full_name AS owner_name,
              r.report_type,
              r.status,
              r.target_store_id,
              r.target_brand_id,
              r.description,
              r.image_url,
              r.product_name,
              r.location_lat,
              r.location_lng,
              r.location_address,
              r.target_store_name_snapshot,
              r.target_brand_name_snapshot,
              r.reward_granted,
              r.reward_points,
              r.resolution_note,
              r.created_at,
              r.updated_at,
              CASE
                WHEN r.target_store_id = $1 THEN 'store'
                ELSE 'brand_product'
              END AS visibility_reason
         FROM reports r
         LEFT JOIN users u ON u.id = r.owner_id
        WHERE r.target_store_id = $1
           OR (
             r.target_brand_id IS NOT NULL
             AND EXISTS (
               SELECT 1
                 FROM brand_matches bm
                 JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
                 JOIN invoice_scans i ON i.id = li.invoice_scan_id
                WHERE bm.brand_id = r.target_brand_id
                  AND i.merchant_profile_id = $1
                  AND i.state = 'approved'
             )
           )
        ORDER BY r.created_at DESC`,
      [merchantId]
    )).rows;

    return res.json(rows.map((row) => ({
      id: row.id,
      ownerId: row.owner_id,
      ownerEmail: row.owner_email,
      ownerName: row.owner_name,
      reportType: row.report_type,
      status: row.status,
      targetStoreId: row.target_store_id,
      targetBrandId: row.target_brand_id,
      targetStoreName: row.target_store_name_snapshot,
      targetBrandName: row.target_brand_name_snapshot,
      description: row.description,
      imageUrl: row.image_url,
      productName: row.product_name,
      locationLat: row.location_lat == null ? null : Number(row.location_lat),
      locationLng: row.location_lng == null ? null : Number(row.location_lng),
      locationAddress: row.location_address,
      rewardGranted: Boolean(row.reward_granted),
      rewardPoints: Number(row.reward_points || 0),
      resolutionNote: row.resolution_note,
      visibilityReason: row.visibility_reason,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'merchant_reports_inbox_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/brand/reports/inbox', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const rows = (await pool.query(
    `SELECT r.id, r.owner_id, COALESCE(u.full_name, u.email) AS reporter_name,
            u.email AS reporter_email, r.report_type, r.status, r.description,
            r.image_url, r.product_name, r.location_lat, r.location_lng, r.location_address,
            r.target_store_id, r.target_store_name_snapshot,
            mp.user_id AS store_user_id, mp.phone AS store_phone,
            mp.location_lat AS store_lat, mp.location_lng AS store_lng,
            mp.location_address AS store_address, mp.business_name AS store_name,
            r.reward_granted, r.reward_points, r.resolution_note, r.created_at
       FROM reports r
       LEFT JOIN users u ON u.id = r.owner_id
       LEFT JOIN merchant_profiles mp ON mp.id = r.target_store_id
      WHERE r.target_brand_id = $1
      ORDER BY r.created_at DESC`,
    [brandId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id, ownerId: row.owner_id, reporterName: row.reporter_name,
    reporterEmail: row.reporter_email, reportType: row.report_type, status: row.status,
    description: row.description, imageUrl: row.image_url, productName: row.product_name,
    locationLat: row.location_lat == null ? null : Number(row.location_lat),
    locationLng: row.location_lng == null ? null : Number(row.location_lng),
    locationAddress: row.location_address, storeId: row.target_store_id,
    storeName: row.store_name || row.target_store_name_snapshot, storeUserId: row.store_user_id,
    storePhone: row.store_phone, storeLat: row.store_lat == null ? null : Number(row.store_lat),
    storeLng: row.store_lng == null ? null : Number(row.store_lng), storeAddress: row.store_address,
    rewardGranted: Boolean(row.reward_granted), rewardPoints: Number(row.reward_points || 0),
    resolutionNote: row.resolution_note, createdAt: toIso(row.created_at),
  })));
});

app.post('/api/brand/reports/:id/resolve', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const grantReward = Boolean((req.body || {}).grantReward);
  const rewardPoints = Math.max(0, Number((req.body || {}).rewardPoints || 10));
  const resolutionNote = String((req.body || {}).resolutionNote || '').trim() || null;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const report = (await client.query('SELECT * FROM reports WHERE id = $1 AND target_brand_id = $2 FOR UPDATE', [req.params.id, brandId])).rows[0];
    if (!report) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'report_not_found' }); }
    const status = grantReward ? 'reward_granted' : 'accepted';
    await client.query(`UPDATE reports SET status=$2, reward_granted=$3, reward_points=$4, resolved_by_user_id=$5, resolved_at=NOW(), resolution_note=$6, updated_at=NOW() WHERE id=$1`, [report.id, status, grantReward, grantReward ? rewardPoints : 0, req.user.userId, resolutionNote]);
    if (grantReward && rewardPoints > 0) {
      await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [report.owner_id]);
      await client.query('UPDATE point_accounts SET available_points=available_points+$2, lifetime_points=lifetime_points+$2, updated_at=NOW() WHERE owner_id=$1', [report.owner_id, rewardPoints]);
    }
    await insertNotification(client, report.owner_id, grantReward ? 'report_accepted_reward' : 'report_accepted', grantReward ? 'تم قبول البلاغ ومنحك نقاطاً' : 'تم قبول البلاغ', grantReward ? `تم قبول بلاغك ومنحك ${rewardPoints} نقطة.` : 'تمت مراجعة بلاغك وقبوله.', { reportId: report.id, rewardPoints: grantReward ? rewardPoints : 0, targetScreen: 'reports' });
    await client.query('COMMIT');
    return res.json({ ok: true, id: report.id, status, rewardPoints: grantReward ? rewardPoints : 0 });
  } catch (e) { await client.query('ROLLBACK'); return res.status(500).json({ error: 'brand_report_resolve_failed', details: String(e.message || e) }); }
  finally { client.release(); }
});

app.post('/api/merchant/reports/:id/accept', auth, async (req, res) => {
  const reportId = req.params.id;
  const grantReward = Boolean((req.body || {}).grantReward);
  const rewardPoints = Math.max(0, Number((req.body || {}).rewardPoints || 10));
  const resolutionNote = String((req.body || {}).resolutionNote || '').trim() || null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const reportRow = (await client.query(
      `SELECT r.*
         FROM reports r
        WHERE r.id = $1
          AND (
            r.target_store_id = $2
            OR (
              r.target_brand_id IS NOT NULL
              AND EXISTS (
                SELECT 1
                  FROM brand_matches bm
                  JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
                  JOIN invoice_scans i ON i.id = li.invoice_scan_id
                 WHERE bm.brand_id = r.target_brand_id
                   AND i.merchant_profile_id = $2
                   AND i.state = 'approved'
              )
            )
          )
        LIMIT 1`,
      [reportId, merchantId]
    )).rows[0];

    if (!reportRow) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'report_not_found_or_not_visible' });
    }

    const nextStatus = grantReward ? 'reward_granted' : 'accepted';
    await client.query(
      `UPDATE reports
          SET status = $2,
              reward_granted = $3,
              reward_points = $4,
              resolved_by_user_id = $5,
              resolved_at = NOW(),
              resolution_note = $6,
              updated_at = NOW()
        WHERE id = $1`,
      [reportId, nextStatus, grantReward, grantReward ? rewardPoints : 0, req.user.userId, resolutionNote]
    );

    if (grantReward && rewardPoints > 0) {
      await client.query(
        `INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at)
         VALUES ($1, 0, 0, NOW())
         ON CONFLICT (owner_id) DO NOTHING`,
        [reportRow.owner_id]
      );
      await client.query(
        `UPDATE point_accounts
            SET available_points = available_points + $2,
                lifetime_points = lifetime_points + $2,
                updated_at = NOW()
          WHERE owner_id = $1`,
        [reportRow.owner_id, rewardPoints]
      );
    }

    const merchantName = (await client.query(
      'SELECT business_name FROM merchant_profiles WHERE id = $1 LIMIT 1',
      [merchantId]
    )).rows[0]?.business_name || 'Merchant';

    await insertNotification(
      client,
      reportRow.owner_id,
      grantReward ? 'report_accepted_reward' : 'report_accepted',
      grantReward ? 'Report accepted with reward' : 'Report accepted',
      grantReward
        ? `Your report was accepted by ${merchantName}. Reward +${rewardPoints} points added.`
        : `Your report was accepted by ${merchantName}.`,
      { reportId, status: nextStatus, rewardPoints: grantReward ? rewardPoints : 0, targetScreen: 'reports' }
    );

    await client.query('COMMIT');
    return res.json({
      ok: true,
      id: reportId,
      status: nextStatus,
      rewardGranted: grantReward,
      rewardPoints: grantReward ? rewardPoints : 0,
    });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'merchant_report_accept_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/reports/:id/transition', auth, requireAdmin, async (req, res) => {
  const reportId = req.params.id;
  const to = String((req.body || {}).to || '').trim();
  const rewardGranted = Boolean((req.body || {}).rewardGranted);
  const allowed = {
    new: ['under_review'],
    under_review: ['accepted', 'rejected'],
    accepted: ['reward_granted', 'closed'],
    reward_granted: ['closed'],
    rejected: ['closed'],
  };
  const row = (await pool.query('SELECT status FROM reports WHERE id = $1 LIMIT 1', [reportId])).rows[0];
  if (!row) return res.status(404).json({ error: 'report_not_found' });
  const from = row.status;
  if (!((allowed[from] || []).includes(to))) return res.status(400).json({ error: 'invalid_transition', from, to });
  await pool.query(
    'UPDATE reports SET status = $2, reward_granted = $3, updated_at = NOW() WHERE id = $1',
    [reportId, to, rewardGranted]
  );
  if (to === 'reward_granted' || rewardGranted) {
    const ownerRow = (await pool.query('SELECT owner_id FROM reports WHERE id = $1 LIMIT 1', [reportId])).rows[0];
    await insertNotification(
      pool,
      ownerRow?.owner_id,
      'report_reward_granted',
      'Reward granted',
      'A reward was granted for your report.',
      { reportId }
    );
  }
  return res.json({ ok: true, from, to });
});

app.post('/api/escrow/accounts', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const sourceType = String(p.sourceType || '').trim();
  const sourceId = String(p.sourceId || '').trim();
  if (!sourceType || !sourceId) return res.status(400).json({ error: 'sourceType_and_sourceId_required' });
  const escrowId = id();
  await pool.query(
    `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
     VALUES ($1,$2,$3,COALESCE($4,0))`,
    [escrowId, sourceType, sourceId, Number(p.balance || 0)]
  );
  return res.json({ ok: true, id: escrowId });
});

app.post('/api/escrow/settlements', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const escrowAccountId = String(p.escrowAccountId || '').trim();
  const amount = Number(p.amount || 0);
  const settlementType = String(p.settlementType || '').trim();
  if (!escrowAccountId || !Number.isFinite(amount) || amount <= 0 || !settlementType) {
    return res.status(400).json({ error: 'invalid_payload' });
  }
  const settlementId = id();
  await pool.query(
    `INSERT INTO settlements (id, escrow_account_id, amount, settlement_type, status, is_external_transfer_executed)
     VALUES ($1,$2,$3,$4,'internal_accounting_only',FALSE)`,
    [settlementId, escrowAccountId, amount, settlementType]
  );
  return res.json({ ok: true, id: settlementId, execution: 'internal_accounting_only', externalTransferExecuted: false });
});

};
