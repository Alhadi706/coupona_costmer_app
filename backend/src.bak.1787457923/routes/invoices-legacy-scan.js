const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerInvoicesLegacyScanRoutes(app, deps) {
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

app.post('/api/invoices/scan', auth, async (req, res) => {
  const p = req.body || {};
  const rawText = String(p.rawText || '').trim();
  if (!rawText) {
    return res.status(400).json({ error: 'raw_text_required' });
  }

  const ownerId = req.user.userId;
  const merchantName = String(p.merchantName || '').trim() || 'غير معروف';
  const merchantKey = normalizeMerchantKey(merchantName);
  const invoiceNumber = String(p.invoiceNumber || '').trim() || null;
  const orderNumber = String(p.orderNumber || '').trim() || null;
  const invoiceDate = String(p.invoiceDate || '').trim() || null;
  const category = String(p.category || 'general').trim() || 'general';
  const currency = String(p.currency || 'SAR').trim() || 'SAR';
  const items = Array.isArray(p.items) ? p.items : [];
  const imageBase64 = String(p.imageBase64 || '').trim();

  const amountRaw = p.totalAmount;
  const amount = amountRaw == null ? null : Number(amountRaw);
  const totalAmount = Number.isFinite(amount) && amount > 0 ? amount : null;
  const parsedDate = parseFlexibleDate(invoiceDate);
  const parsedDateIso = parsedDate ? parsedDate.toISOString().slice(0, 10) : null;
  const invoiceFingerprint = buildInvoiceFingerprint({
    merchantKey,
    invoiceNumber,
    orderNumber,
    invoiceDate: parsedDateIso,
    totalAmount,
    category,
    rawText,
    items,
  });

  if (parsedDate) {
    const now = new Date();
    const days = Math.floor((now.getTime() - parsedDate.getTime()) / (1000 * 60 * 60 * 24));
    if (days > 45) {
      return res.json({ ok: false, tooOld: true, maxAgeDays: 45 });
    }
  }

  const customerRow = (await pool.query('SELECT email FROM users WHERE id = $1', [ownerId])).rows[0];
  const customerEmail = customerRow ? String(customerRow.email || '').toLowerCase() : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const duplicate = (await client.query(
      `SELECT id
         FROM invoice_scans
        WHERE owner_id = $1
          AND invoice_fingerprint = $2
        LIMIT 1`,
      [ownerId, invoiceFingerprint]
    )).rows[0];

    const legacyDuplicate = duplicate || (await client.query(
      `SELECT id
         FROM invoice_scans
        WHERE owner_id = $1
          AND merchant_key = $2
          AND COALESCE(invoice_number, '') = COALESCE($3, '')
          AND COALESCE(order_number, '') = COALESCE($4, '')
          AND COALESCE(invoice_date::text, '') = COALESCE($5, '')
          AND COALESCE(total_amount::text, '') = COALESCE($6::text, '')
        LIMIT 1`,
      [ownerId, merchantKey, invoiceNumber, orderNumber, parsedDateIso, totalAmount]
    )).rows[0];

    if (duplicate || legacyDuplicate) {
      await client.query('ROLLBACK');
      return res.json({ ok: false, duplicate: true, duplicateId: (duplicate || legacyDuplicate).id });
    }

    const merchantProfileId = await resolveMerchantProfileIdByKey(client, merchantKey);

    const scanId = id();
    
    let originalImagePath = null;
    if (imageBase64) {
      try {
        const buffer = Buffer.from(imageBase64, 'base64');
        const filename = `${scanId}.jpg`;
        const filepath = path.join(INVOICES_UPLOAD_DIR, filename);
        fs.writeFileSync(filepath, buffer);
        originalImagePath = `uploads/invoices/${filename}`;
      } catch (err) {
        console.error('Failed to save invoice image:', err);
      }
    }

    await client.query(
      `INSERT INTO invoice_scans (
        id, owner_id, merchant_name, merchant_key, invoice_fingerprint, invoice_number, order_number, invoice_date,
        total_amount, currency, category, raw_text, reward_applied, branch_id, merchant_profile_id, original_image_path
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16
      )`,
      [
        scanId,
        ownerId,
        merchantName,
        merchantKey,
        invoiceFingerprint,
        invoiceNumber,
        orderNumber,
        parsedDateIso,
        totalAmount,
        currency,
        category,
        rawText,
        false,
        String(p.branchId || '').trim() || null,
        merchantProfileId,
        originalImagePath,
      ]
    );

    // Persist each purchased item so it survives beyond the scan: needed both to let
    // brand-owned products earn brand points below, and for future purchase analytics.
    const savedLineItems = [];
    for (const rawItem of items) {
      const name = String((rawItem && rawItem.name) || '').trim();
      if (!name) continue;
      let quantity = Number(rawItem && rawItem.quantity);
      let unitPrice = Number(rawItem && rawItem.unitPrice);
      let lineTotal = Number(rawItem && rawItem.lineTotal);
      quantity = Number.isFinite(quantity) && quantity > 0 ? Math.round(quantity) : null;
      unitPrice = Number.isFinite(unitPrice) && unitPrice > 0 ? Number(unitPrice.toFixed(2)) : null;
      lineTotal = Number.isFinite(lineTotal) && lineTotal > 0 ? Number(lineTotal.toFixed(2)) : null;
      if (unitPrice == null && quantity != null && lineTotal != null && quantity > 0) {
        unitPrice = Number((lineTotal / quantity).toFixed(2));
      }
      if (lineTotal == null && quantity != null && unitPrice != null) {
        lineTotal = Number((quantity * unitPrice).toFixed(2));
      }
      const lineItemId = id();
      await client.query(
        'INSERT INTO invoice_line_items (id, invoice_scan_id, item_name, quantity, unit_price, line_total) VALUES ($1,$2,$3,$4,$5,$6)',
        [lineItemId, scanId, name, quantity, unitPrice, lineTotal]
      );
      savedLineItems.push({ id: lineItemId, name });
    }

    for (const lineItem of savedLineItems) {
      const match = await autoMatchLineItemToBrand(client, lineItem.name);
      if (match) {
        await client.query(
          'INSERT INTO brand_matches (id, invoice_line_item_id, brand_id, product_id, confidence) VALUES ($1,$2,$3,$4,$5)',
          [id(), lineItem.id, match.brandId, match.productId, 0.5]
        );
      }
    }

    // Award points: prefer the real merchant/brand split (uses each party's own point_value
    // and the actual matched line-item amounts) and only fall back to the flat generic
    // cashback rate when neither the merchant nor any brand could be resolved, so existing
    // un-onboarded shops keep earning points exactly as before.
    let awards = null;
    let fallbackReward = null;
    let rewardApplied = false;
    if (totalAmount != null && totalAmount > 0) {
      awards = await applyInvoiceApprovalRewards(client, scanId, ownerId, merchantProfileId);
      const splitPoints = (awards.merchantPoints || 0) + (awards.brandPoints || 0);
      if (splitPoints > 0) {
        rewardApplied = true;
      } else {
        const cashback = Number((totalAmount * 0.05).toFixed(2));
        const earnedPoints = Math.floor(totalAmount);
        await client.query("INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,'SAR',NOW()) ON CONFLICT (owner_id) DO NOTHING", [ownerId]);
        await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [ownerId]);
        await client.query('UPDATE wallet_accounts SET balance = balance + $1, updated_at = NOW() WHERE owner_id = $2', [cashback, ownerId]);
        await client.query('UPDATE point_accounts SET available_points = available_points + $1, lifetime_points = lifetime_points + $1, updated_at = NOW() WHERE owner_id = $2', [earnedPoints, ownerId]);
        await client.query('UPDATE users SET points = points + $1, points_history = points_history || to_jsonb($2::int) WHERE id = $3', [earnedPoints, earnedPoints, ownerId]);
        const reference = invoiceNumber ? `invoice:${invoiceNumber}` : (orderNumber ? `order:${orderNumber}` : `invoice:${scanId}`);
        await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), ownerId, 'cashbackEarned', cashback, 0, reference]);
        await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), ownerId, 'pointsEarned', 0, earnedPoints, reference]);
        fallbackReward = { cashback, earnedPoints };
        rewardApplied = earnedPoints > 0;
      }
      if (rewardApplied) {
        await client.query('UPDATE invoice_scans SET reward_applied = TRUE WHERE id = $1', [scanId]);
      }
    }

    if (customerEmail && totalAmount != null) {
      await client.query(
        'INSERT INTO activity_logs (id, customer_email, amount, transaction_date) VALUES ($1,$2,$3,NOW())',
        [id(), customerEmail, totalAmount]
      );
    }

    await client.query('COMMIT');
    return res.json({
      ok: true,
      id: scanId,
      ownerId,
      merchantName,
      merchantKey,
      merchantProfileId,
      orderNumber,
      totalAmount,
      category,
      rewardApplied,
      awards,
      fallbackReward,
      itemsSaved: savedLineItems.length,
    });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'save_invoice_scan_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/analyze-ai', auth, async (req, res) => {
  const p = req.body || {};
  const rawText = String(p.rawText || '').trim();
  const imageBase64 = String(p.imageBase64 || '').trim();
  const mimeType = String(p.mimeType || 'image/jpeg').trim() || 'image/jpeg';

  if (!rawText && !imageBase64) {
    return res.status(400).json({ error: 'raw_text_or_image_required' });
  }

  try {
    const result = await analyzeInvoiceWithGemini({ rawText, imageBase64, mimeType });
    return res.json(result);
  } catch (e) {
    return res.status(500).json({
      ok: false,
      error: 'analyze_invoice_ai_failed',
      details: String(e.message || e),
    });
  }
});

app.get('/api/invoices/my', auth, async (req, res) => {
  const ownerId = req.user.userId;
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query(
    `SELECT *
       FROM invoice_scans
      WHERE owner_id = $1
      ORDER BY created_at DESC
      LIMIT $2`,
    [ownerId, limit]
  )).rows;

  res.json(rows.map((row) => ({
    id: row.id,
    ownerId: row.owner_id,
    branchId: row.branch_id,
    merchantName: row.merchant_name,
    merchantKey: row.merchant_key,
    invoiceNumber: row.invoice_number,
    orderNumber: row.order_number,
    invoiceDate: row.invoice_date,
    totalAmount: row.total_amount == null ? null : Number(row.total_amount),
    currency: row.currency,
    category: row.category,
    state: row.state,
    reviewNote: row.review_note,
    rewardApplied: Boolean(row.reward_applied),
    rawText: row.raw_text,
    createdAt: toIso(row.created_at),
  })));
});

};
