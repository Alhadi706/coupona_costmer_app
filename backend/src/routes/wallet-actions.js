const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerWalletActionsRoutes(app, deps) {
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

app.post('/api/wallet/cashback-v2', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const userId = req.user.userId;
    const p = req.body || {};
    const merchantId = String(p.merchantId || '').trim();
    const purchaseAmount = Number(p.purchaseAmount || 0);
    if (!merchantId || !Number.isFinite(purchaseAmount) || purchaseAmount <= 0) {
      return res.status(400).json({ error: 'invalid_payload' });
    }

    const merchant = (await client.query('SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [merchantId])).rows[0];
    const pointValue = Number(merchant?.point_value || 0);

    await client.query(
      `INSERT INTO customer_merchant_fraction_balance (customer_id, merchant_id, fraction_balance)
       VALUES ($1,$2,0)
       ON CONFLICT (customer_id, merchant_id) DO NOTHING`,
      [userId, merchantId]
    );

    const bal = (await client.query(
      'SELECT fraction_balance FROM customer_merchant_fraction_balance WHERE customer_id = $1 AND merchant_id = $2 FOR UPDATE',
      [userId, merchantId]
    )).rows[0];

    const calc = calculatePointsWithFraction(purchaseAmount, pointValue, bal?.fraction_balance || 0);

    await client.query(
      'UPDATE customer_merchant_fraction_balance SET fraction_balance = $3, updated_at = NOW() WHERE customer_id = $1 AND merchant_id = $2',
      [userId, merchantId, calc.newFraction]
    );

    await client.query(
      `INSERT INTO points_ledger_merchant (id, customer_id, merchant_id, points_delta, fraction_before, fraction_after, status, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,'active',NOW() + INTERVAL '12 months')`,
      [id(), userId, merchantId, calc.points, Number(bal?.fraction_balance || 0), calc.newFraction]
    );

    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW() WHERE owner_id = $1', [userId, calc.points]);
    await client.query('UPDATE users SET points = points + $2, points_history = points_history || to_jsonb($2::int) WHERE id = $1', [userId, calc.points]);
    await insertNotification(
      client,
      userId,
      'points_confirmed',
      'Points added',
      `You earned ${calc.points} point(s).`,
      { merchantId, points: calc.points, fraction: calc.newFraction }
    );

    return res.json({ ok: true, points: calc.points, fraction: calc.newFraction });
  } catch (e) {
    return res.status(500).json({ error: 'cashback_v2_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/wallet/refund-deduction', auth, async (req, res) => {
  const userId = req.user.userId;
  const points = Number((req.body || {}).points || 0);
  if (!Number.isFinite(points) || points <= 0) {
    return res.status(400).json({ error: 'invalid_points' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE point_accounts SET available_points = GREATEST(available_points - $2, 0), updated_at = NOW() WHERE owner_id = $1', [userId, points]);
    await client.query('UPDATE users SET points = GREATEST(points - $2, 0) WHERE id = $1', [userId, points]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'refundDeduction', 0, points, 'refund']);
    await client.query('COMMIT');
    return res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'refund_deduction_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/points/expire/run', auth, requireAdmin, async (_req, res) => {
  try {
    const expiringSoonRows = (await pool.query(
      `SELECT customer_id, merchant_id, expires_at
         FROM points_ledger_merchant
        WHERE status = 'active'
          AND expires_at > NOW()
          AND expires_at <= NOW() + INTERVAL '7 days'
        ORDER BY expires_at ASC
        LIMIT 500`
    )).rows;
    for (const row of expiringSoonRows) {
      await insertNotification(
        pool,
        row.customer_id,
        'points_expiry_soon',
        'Points expiring soon',
        'Some of your merchant points will expire within 7 days.',
        { merchantId: row.merchant_id, expiresAt: toIso(row.expires_at) }
      );
    }

    await pool.query("UPDATE points_ledger_merchant SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()");
    await pool.query("UPDATE points_ledger_brand SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()");
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'points_expire_failed', details: String(e.message || e) });
  }
});

// Issues a short-lived, single-use signed token identifying the calling customer,
// meant to be rendered as a QR code and scanned by a cashier to grant points.
// Signed with POS_GRANT_TOKEN_SECRET (independent of the session JWT_SECRET) so it
// cannot be replayed as a login/session token, and cannot be forged without the secret.
app.post('/api/customer/pos-qr-token', auth, async (req, res) => {
  const customerId = req.user.userId;
  const nonce = id();
  const token = jwt.sign(
    { customerId, nonce, purpose: 'pos_grant' },
    POS_GRANT_TOKEN_SECRET,
    { expiresIn: POS_GRANT_TOKEN_TTL_SECONDS }
  );
  return res.json({
    token,
    expiresInSeconds: POS_GRANT_TOKEN_TTL_SECONDS,
    expiresAt: new Date(Date.now() + POS_GRANT_TOKEN_TTL_SECONDS * 1000).toISOString(),
  });
});

app.post('/api/cashier/grant-points', auth, async (req, res) => {
  const userId = req.user.userId;
  const p = req.body || {};
  const branchId = String(p.branchId || '').trim();
  const qrToken = String(p.qrToken || '').trim();
  const manualOverride = p.manualOverride === true;
  const manualOverrideReason = String(p.manualOverrideReason || '').trim();
  const purchaseAmount = Number(p.purchaseAmount || 0);

  if (!branchId || !Number.isFinite(purchaseAmount) || purchaseAmount <= 0) {
    return res.status(400).json({ error: 'invalid_payload' });
  }

  // Primary path: a real, signed, single-use QR token scanned from the customer's device.
  // Fallback path: manual customerId entry, only allowed when explicitly flagged as an
  // override (camera failure etc.) — every manual grant is logged for merchant/admin review.
  let customerId = '';
  let tokenNonce = '';
  if (qrToken) {
    let decoded;
    try {
      decoded = jwt.verify(qrToken, POS_GRANT_TOKEN_SECRET);
    } catch (e) {
      if (e && e.name === 'TokenExpiredError') {
        return res.status(400).json({ error: 'qr_token_expired' });
      }
      return res.status(400).json({ error: 'qr_token_invalid' });
    }
    if (decoded.purpose !== 'pos_grant' || !decoded.customerId || !decoded.nonce) {
      return res.status(400).json({ error: 'qr_token_invalid' });
    }
    customerId = String(decoded.customerId);
    tokenNonce = String(decoded.nonce);
    // Consume the nonce immediately and atomically: a second scan of the same QR, whether
    // concurrent or after this request finishes, always fails the unique-key insert below.
    try {
      await pool.query(
        'INSERT INTO pos_grant_token_uses (nonce, customer_id) VALUES ($1,$2)',
        [tokenNonce, customerId]
      );
    } catch (_e) {
      return res.status(409).json({ error: 'qr_token_already_used' });
    }
  } else if (manualOverride) {
    customerId = String(p.customerId || '').trim();
    if (!customerId || !manualOverrideReason) {
      return res.status(400).json({ error: 'manual_override_reason_required' });
    }
  } else {
    return res.status(400).json({ error: 'qr_token_or_manual_override_required' });
  }

  const cashier = (await pool.query(
    'SELECT * FROM cashier_profiles WHERE user_id = $1 AND branch_id = $2 AND is_active = TRUE LIMIT 1',
    [userId, branchId]
  )).rows[0];
  if (!cashier) return res.status(403).json({ error: 'cashier_not_authorized' });
  const merchantId = cashier.merchant_id;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const merchant = (await client.query('SELECT business_name, point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [merchantId])).rows[0];
    const pointValue = Number(merchant?.point_value || 0);

    // Fraud control parity with the OCR invoice path: same daily-limit rule applies
    // to POS/cashier-granted purchases, since both paths feed the same Points Engine.
    const dailyLimit = await getIntSetting(pool, 'daily_invoice_limit', 10);
    const dailyCount = (await client.query(
      `SELECT COUNT(*)::int AS c
         FROM invoice_scans
        WHERE owner_id = $1
          AND created_at >= date_trunc('day', NOW())`,
      [customerId]
    )).rows[0]?.c || 0;
    if (dailyCount >= dailyLimit) {
      await client.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), customerId, 'daily_invoice_limit_reached', JSON.stringify({ dailyCount, dailyLimit, source: 'cashier_grant' })]);
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'daily_invoice_limit_reached' });
    }

    if (manualOverride) {
      await client.query(
        'INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)',
        [id(), customerId, 'pos_manual_override_used', JSON.stringify({ branchId, purchaseAmount, reason: manualOverrideReason, cashierUserId: userId })]
      );
    }

    await client.query(
      `INSERT INTO customer_merchant_fraction_balance (customer_id, merchant_id, fraction_balance)
       VALUES ($1,$2,0)
       ON CONFLICT (customer_id, merchant_id) DO NOTHING`,
      [customerId, merchantId]
    );

    const bal = (await client.query(
      'SELECT fraction_balance FROM customer_merchant_fraction_balance WHERE customer_id = $1 AND merchant_id = $2 FOR UPDATE',
      [customerId, merchantId]
    )).rows[0];

    const calc = calculatePointsWithFraction(purchaseAmount, pointValue, bal?.fraction_balance || 0);
    await client.query(
      'UPDATE customer_merchant_fraction_balance SET fraction_balance = $3, updated_at = NOW() WHERE customer_id = $1 AND merchant_id = $2',
      [customerId, merchantId, calc.newFraction]
    );

    // Record the POS sale itself as an approved invoice_scans row (category='pos') so it
    // is included in merchant/admin "sales" analytics exactly like an OCR-approved invoice.
    // Previously this endpoint only wrote to points_ledger_merchant, which meant cashier-
    // granted points showed up in "pointsAwarded" while "sales" stayed at 0 for the same purchase.
    const scanId = id();
    await client.query(
      `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, invoice_date, total_amount, currency, category, raw_text, reward_applied, merchant_profile_id, branch_id, state, pos_manual_override)
       VALUES ($1,$2,$3,$4,CURRENT_DATE,$5,'SAR','pos',$8,TRUE,$6,$7,'approved',$9)`,
      [
        scanId, customerId, merchant?.business_name || null, normalizeMerchantKey(merchant?.business_name || 'merchant'),
        purchaseAmount, merchantId, branchId,
        manualOverride ? `Cashier-entered POS purchase (manual override): ${manualOverrideReason}` : 'Cashier-entered POS purchase (QR scan)',
        manualOverride,
      ]
    );

    await client.query(
      `INSERT INTO points_ledger_merchant (id, customer_id, merchant_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months')`,
      [id(), customerId, merchantId, scanId, calc.points, Number(bal?.fraction_balance || 0), calc.newFraction]
    );
    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [customerId]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW() WHERE owner_id = $1', [customerId, calc.points]);
    await client.query('UPDATE users SET points = points + $2, points_history = points_history || to_jsonb($2::int) WHERE id = $1', [customerId, calc.points]);

    // Update coalition point balances if merchant is in any coalitions
    const { rows: coalitions } = await client.query(
      `SELECT coalition_id FROM coalition_members WHERE merchant_id = $1`,
      [merchantId]
    );
    
    for (const coalition of coalitions) {
      await client.query(`
        INSERT INTO customer_merchant_point_balances (customer_id, merchant_id, coalition_id, points_balance)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (customer_id, merchant_id, coalition_id)
        DO UPDATE SET 
          points_balance = customer_merchant_point_balances.points_balance + EXCLUDED.points_balance,
          last_updated = NOW()
      `, [customerId, merchantId, coalition.coalition_id, calc.points]);
    }

    await insertNotification(
      client,
      customerId,
      'points_confirmed',
      'Points added',
      `Cashier granted ${calc.points} point(s).`,
      { merchantId, branchId, points: calc.points, fraction: calc.newFraction }
    );

    await client.query('COMMIT');
    return res.json({ ok: true, points: calc.points, fraction: calc.newFraction });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'cashier_grant_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});


};
