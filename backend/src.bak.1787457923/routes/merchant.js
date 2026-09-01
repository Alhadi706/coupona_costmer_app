const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerMerchantRoutes(app, deps) {
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

app.get('/api/merchant/profile', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    const row = (await client.query(
      `SELECT id, user_id, business_name, commercial_registration, status, point_value
         FROM merchant_profiles
        WHERE id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0];
    if (!row) return res.status(404).json({ error: 'merchant_profile_not_found' });

    return res.json({
      id: row.id,
      userId: row.user_id,
      businessName: row.business_name,
      commercialRegistration: row.commercial_registration,
      status: row.status,
      pointValue: row.point_value == null ? null : Number(row.point_value),
    });
  } catch (e) {
    return res.status(500).json({ error: 'merchant_profile_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/merchant/settings/point-value', auth, async (req, res) => {
  const pointValue = Number((req.body || {}).pointValue);
  if (!Number.isFinite(pointValue) || pointValue <= 0) {
    return res.status(400).json({ error: 'invalid_point_value' });
  }

  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    await client.query(
      `UPDATE merchant_profiles
          SET point_value = $2
        WHERE id = $1`,
      [merchantId, pointValue]
    );
    return res.json({ ok: true, id: merchantId, pointValue });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'merchant_point_value_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/brand/profile', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });

    const row = (await client.query(
      `SELECT id, user_id, business_name, commercial_registration, status, point_value
         FROM brand_profiles
        WHERE id = $1
        LIMIT 1`,
      [brandId]
    )).rows[0];
    if (!row) return res.status(404).json({ error: 'brand_profile_not_found' });

    return res.json({
      id: row.id,
      userId: row.user_id,
      businessName: row.business_name,
      commercialRegistration: row.commercial_registration,
      status: row.status,
      pointValue: row.point_value == null ? null : Number(row.point_value),
    });
  } catch (e) {
    return res.status(500).json({ error: 'brand_profile_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/brand/settings/point-value', auth, async (req, res) => {
  const pointValue = Number((req.body || {}).pointValue);
  if (!Number.isFinite(pointValue) || pointValue <= 0) {
    return res.status(400).json({ error: 'invalid_point_value' });
  }

  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });

    await client.query(
      `UPDATE brand_profiles
          SET point_value = $2
        WHERE id = $1`,
      [brandId, pointValue]
    );
    return res.json({ ok: true, id: brandId, pointValue });
  } catch (e) {
    return res.status(500).json({ error: 'brand_point_value_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/branches', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);
    const p = req.body || {};
    const name = String(p.name || '').trim();
    const latitude = Number(p.latitude);
    const longitude = Number(p.longitude);
    if (!name) return res.status(400).json({ error: 'branch_name_required' });
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return res.status(400).json({ error: 'branch_geo_location_required' });
    }
    const branchId = id();
    await client.query(
      `INSERT INTO branches (id, merchant_id, name, address, location, latitude, longitude, category, working_hours, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,COALESCE($10,'active'))`,
      [
        branchId,
        merchantId,
        name,
        p.address || null,
        p.location || null,
        latitude,
        longitude,
        p.category || null,
        p.workingHours || null,
        p.status || null,
      ]
    );
    return res.status(201).json({
      ok: true,
      id: branchId,
      latitude,
      longitude,
      category: p.category || null,
      workingHours: p.workingHours || null,
    });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'branch_create_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/branches', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    const rows = (await client.query('SELECT * FROM branches WHERE merchant_id = $1 ORDER BY created_at DESC', [merchantId])).rows;
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: 'branch_list_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/merchant/branches/:id', auth, async (req, res) => {
  const branchId = String(req.params.id || '').trim();
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);
    const p = req.body || {};
    const result = await client.query(
      `UPDATE branches
          SET name = COALESCE($1, name), address = COALESCE($2, address),
              working_hours = COALESCE($3, working_hours), phone = COALESCE($4, phone),
              updated_at = NOW()
        WHERE id = $5 AND merchant_id = $6
        RETURNING *`,
      [p.name == null ? null : String(p.name).trim(), p.address == null ? null : String(p.address).trim(), p.workingHours == null ? null : String(p.workingHours).trim(), p.phone == null ? null : String(p.phone).trim(), branchId, merchantId]
    );
    if (!result.rowCount) return res.status(404).json({ error: 'branch_not_found' });
    return res.json({ ok: true, branch: result.rows[0] });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) return res.status(403).json({ error: 'merchant_subscription_read_only' });
    return res.status(500).json({ error: 'branch_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/branches/:id/managers', auth, async (req, res) => {
  const branchId = String(req.params.id || '').trim();
  const userId = String((req.body || {}).userId || '').trim();
  const client = await pool.connect();
  try {
    if (!branchId) return res.status(400).json({ error: 'branchId_required' });
    if (!userId) return res.status(400).json({ error: 'userId_required' });
    const branch = (await client.query('SELECT * FROM branches WHERE id = $1 LIMIT 1', [branchId])).rows[0];
    if (!branch) return res.status(404).json({ error: 'branch_not_found' });
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId || branch.merchant_id !== merchantId) return res.status(403).json({ error: 'forbidden' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    await client.query(
      `INSERT INTO branch_manager_permissions (branch_id, user_id)
       VALUES ($1,$2)
       ON CONFLICT (branch_id, user_id) DO NOTHING`,
      [branchId, userId]
    );
    return res.json({ ok: true });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'manager_add_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/cashiers/bind', auth, async (req, res) => {
  const p = req.body || {};
  let cashierUserId = String(p.cashierUserId || '').trim();
  const cashierPhone = String(p.cashierPhone || '').trim();
  const branchId = String(p.branchId || '').trim();
  if (!branchId || (!cashierUserId && !cashierPhone)) {
    return res.status(400).json({ error: 'cashierUserId_or_cashierPhone_and_branchId_required' });
  }
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    const branch = (await client.query('SELECT id, merchant_id FROM branches WHERE id = $1 LIMIT 1', [branchId])).rows[0];
    if (!branch) return res.status(404).json({ error: 'branch_not_found' });
    if (branch.merchant_id !== merchantId) return res.status(403).json({ error: 'forbidden' });

    if (!cashierUserId && cashierPhone) {
      const userByPhone = (await client.query(
        'SELECT id FROM users WHERE phone = $1 LIMIT 1',
        [cashierPhone]
      )).rows[0];
      if (!userByPhone) return res.status(404).json({ error: 'cashier_phone_not_found' });
      cashierUserId = userByPhone.id;
    }

    const existing = (await client.query(
      'SELECT id FROM cashier_profiles WHERE user_id = $1 AND branch_id = $2 LIMIT 1',
      [cashierUserId, branchId]
    )).rows[0];
    if (existing) {
      await client.query('UPDATE cashier_profiles SET is_active = TRUE WHERE id = $1', [existing.id]);
      return res.json({ ok: true, id: existing.id, reactivated: true });
    }

    const cashierId = id();
    await client.query(
      `INSERT INTO cashier_profiles (id, user_id, merchant_id, branch_id, is_active)
       VALUES ($1,$2,$3,$4,TRUE)`,
      [cashierId, cashierUserId, merchantId, branchId]
    );
    return res.json({ ok: true, id: cashierId, cashierUserId, cashierPhone: cashierPhone || null });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'cashier_bind_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/merchant/branches/:id/managers/:userId/permissions', auth, async (req, res) => {
  const branchId = req.params.id;
  const managerId = req.params.userId;
  const p = req.body || {};
  const client = await pool.connect();
  try {
    const branch = (await client.query('SELECT * FROM branches WHERE id = $1 LIMIT 1', [branchId])).rows[0];
    if (!branch) return res.status(404).json({ error: 'branch_not_found' });
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId || branch.merchant_id !== merchantId) return res.status(403).json({ error: 'forbidden' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    await client.query(
      `UPDATE branch_manager_permissions
          SET can_review_invoices = COALESCE($3, can_review_invoices),
              can_create_offers = COALESCE($4, can_create_offers),
              can_manage_group = COALESCE($5, can_manage_group),
              can_view_reports = COALESCE($6, can_view_reports),
              can_view_settlements = COALESCE($7, can_view_settlements),
              can_add_cashiers = COALESCE($8, can_add_cashiers),
              can_reply_reports = COALESCE($9, can_reply_reports),
              can_edit_point_value = COALESCE($10, can_edit_point_value)
        WHERE branch_id = $1 AND user_id = $2`,
      [
        branchId,
        managerId,
        p.canReviewInvoices,
        p.canCreateOffers,
        p.canManageGroup,
        p.canViewReports,
        p.canViewSettlements,
        p.canAddCashiers,
        p.canReplyReports,
        p.canEditPointValue,
      ]
    );
    return res.json({ ok: true });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'permissions_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/manager/scope', auth, async (req, res) => {
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    const rows = (await client.query(
      `SELECT
         bmp.branch_id,
         b.name AS branch_name,
         mp.id AS merchant_id,
         mp.business_name AS merchant_name,
         bmp.can_review_invoices,
         bmp.can_create_offers,
         bmp.can_manage_group,
         bmp.can_view_reports,
         bmp.can_view_settlements,
         bmp.can_add_cashiers,
         bmp.can_reply_reports,
         bmp.can_edit_point_value
       FROM branch_manager_permissions bmp
       JOIN branches b ON b.id = bmp.branch_id
       JOIN merchant_profiles mp ON mp.id = b.merchant_id
      WHERE bmp.user_id = $1
      ORDER BY b.created_at DESC`,
      [userId]
    )).rows;

    const sections = {
      invoiceReview: rows.some((r) => r.can_review_invoices === true),
      offers: rows.some((r) => r.can_create_offers === true),
      groupManagement: rows.some((r) => r.can_manage_group === true),
      reports: rows.some((r) => r.can_view_reports === true),
      settlements: rows.some((r) => r.can_view_settlements === true),
      cashierManagement: rows.some((r) => r.can_add_cashiers === true),
      reportReplies: rows.some((r) => r.can_reply_reports === true),
      pointValueEdit: rows.some((r) => r.can_edit_point_value === true),
    };

    return res.json({
      manager: rows.length > 0,
      sections,
      branches: rows.map((r) => ({
        branchId: r.branch_id,
        branchName: r.branch_name,
        merchantId: r.merchant_id,
        merchantName: r.merchant_name,
      })),
    });
  } catch (e) {
    return res.status(500).json({ error: 'manager_scope_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/manager/invoices/review-queue', auth, async (req, res) => {
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    const managedMerchantRows = (await client.query(
      `SELECT DISTINCT b.merchant_id
         FROM branch_manager_permissions bmp
         JOIN branches b ON b.id = bmp.branch_id
        WHERE bmp.user_id = $1
          AND bmp.can_review_invoices = TRUE`,
      [userId]
    )).rows;

    if (!managedMerchantRows.length) {
      return res.status(403).json({ error: 'manager_invoice_review_permission_required' });
    }

    const merchantIds = managedMerchantRows.map((r) => r.merchant_id);
    const invoiceRows = (await client.query(
      `SELECT id, owner_id, merchant_name, invoice_number, invoice_date, total_amount, currency, state, created_at
         FROM invoice_scans
        WHERE merchant_profile_id = ANY($1::text[])
          AND state IN ('processing', 'approved', 'rejected', 'disputed')
        ORDER BY created_at DESC
        LIMIT 100`,
      [merchantIds]
    )).rows;

    return res.json(invoiceRows.map((r) => ({
      id: r.id,
      ownerId: r.owner_id,
      merchantName: r.merchant_name,
      invoiceNumber: r.invoice_number,
      invoiceDate: r.invoice_date,
      totalAmount: r.total_amount,
      currency: r.currency,
      state: r.state,
      createdAt: toIso(r.created_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'manager_invoice_queue_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/brand/team-members', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
    const p = req.body || {};
    const userId = String(p.userId || '').trim();
    if (!userId) return res.status(400).json({ error: 'userId_required' });
    await client.query(
      `INSERT INTO brand_team_members (brand_id, user_id, can_manage_products, can_view_geo_distribution)
       VALUES ($1,$2,COALESCE($3,FALSE),COALESCE($4,FALSE))
       ON CONFLICT (brand_id, user_id)
       DO UPDATE SET
         can_manage_products = EXCLUDED.can_manage_products,
         can_view_geo_distribution = EXCLUDED.can_view_geo_distribution`,
      [brandId, userId, p.canManageProducts, p.canViewGeoDistribution]
    );
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'brand_team_member_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

};
