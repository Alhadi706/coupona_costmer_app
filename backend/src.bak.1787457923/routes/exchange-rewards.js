const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerExchangeRewardsRoutes(app, deps) {
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

app.post('/api/admin/exchange-rates', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const sourceType = normalizeRoleType(p.sourceType);
  const destinationType = normalizeRoleType(p.destinationType);
  const sourceId = String(p.sourceId || '').trim();
  const destinationId = String(p.destinationId || '').trim();
  if (!sourceType || !destinationType || !sourceId || !destinationId) {
    return res.status(400).json({ error: 'invalid_source_or_destination' });
  }

  const client = await pool.connect();
  try {
    let sourcePointValue = Number(p.sourcePointValue || 0);
    let destinationPointValue = Number(p.destinationPointValue || 0);
    if (!Number.isFinite(sourcePointValue) || sourcePointValue <= 0) {
      const sourceRow = sourceType === 'merchant'
        ? (await client.query('SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [sourceId])).rows[0]
        : (await client.query('SELECT point_value FROM brand_profiles WHERE id = $1 LIMIT 1', [sourceId])).rows[0];
      sourcePointValue = Number(sourceRow?.point_value || 0);
    }
    if (!Number.isFinite(destinationPointValue) || destinationPointValue <= 0) {
      const destinationRow = destinationType === 'merchant'
        ? (await client.query('SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [destinationId])).rows[0]
        : (await client.query('SELECT point_value FROM brand_profiles WHERE id = $1 LIMIT 1', [destinationId])).rows[0];
      destinationPointValue = Number(destinationRow?.point_value || 0);
    }

    if (!Number.isFinite(sourcePointValue) || sourcePointValue <= 0 || !Number.isFinite(destinationPointValue) || destinationPointValue <= 0) {
      return res.status(400).json({ error: 'point_values_not_configured' });
    }

    const rate = Number((sourcePointValue / destinationPointValue).toFixed(6));
    const rowId = id();
    await client.query(
      `INSERT INTO exchange_rate_settings (
        id, source_type, source_id, destination_type, destination_id,
        source_point_value, destination_point_value, rate, configured_by, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,NOW()
      )
      ON CONFLICT (source_type, source_id, destination_type, destination_id)
      DO UPDATE SET
        source_point_value = EXCLUDED.source_point_value,
        destination_point_value = EXCLUDED.destination_point_value,
        rate = EXCLUDED.rate,
        configured_by = EXCLUDED.configured_by,
        updated_at = NOW()`,
      [
        rowId,
        sourceType,
        sourceId,
        destinationType,
        destinationId,
        sourcePointValue,
        destinationPointValue,
        rate,
        req.user.userId,
      ]
    );

    return res.json({
      ok: true,
      sourceType,
      sourceId,
      destinationType,
      destinationId,
      sourcePointValue,
      destinationPointValue,
      rate,
      formula: 'destinationPoints = sourcePoints * sourcePointValue / destinationPointValue',
    });
  } catch (e) {
    return res.status(500).json({ error: 'exchange_rate_set_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/admin/exchange-rates', auth, requireAdmin, async (req, res) => {
  const rows = (await pool.query(
    `SELECT *
       FROM exchange_rate_settings
      ORDER BY updated_at DESC
      LIMIT 200`
  )).rows;
  return res.json(rows.map((r) => ({
    id: r.id,
    sourceType: r.source_type,
    sourceId: r.source_id,
    destinationType: r.destination_type,
    destinationId: r.destination_id,
    sourcePointValue: Number(r.source_point_value || 0),
    destinationPointValue: Number(r.destination_point_value || 0),
    rate: Number(r.rate || 0),
    configuredBy: r.configured_by,
    createdAt: toIso(r.created_at),
    updatedAt: toIso(r.updated_at),
  })));
});

app.post('/api/points/exchange', auth, async (req, res) => {
  const p = req.body || {};
  const sourcePoints = Number(p.sourcePoints || 0);
  const sourceType = normalizeRoleType(p.sourceType) || 'merchant';
  const destinationType = normalizeRoleType(p.destinationType) || 'merchant';
  const sourceId = String(p.sourceId || '').trim();
  const destinationId = String(p.destinationId || '').trim();
  if (!Number.isFinite(sourcePoints) || sourcePoints <= 0) {
    return res.status(400).json({ error: 'invalid_payload' });
  }

  let sourcePointValue = Number(p.sourcePointValue || 0);
  let destinationPointValue = Number(p.destinationPointValue || 0);

  const configuredRate = (await pool.query(
    `SELECT source_point_value, destination_point_value, rate
       FROM exchange_rate_settings
      WHERE source_type = $1
        AND source_id = $2
        AND destination_type = $3
        AND destination_id = $4
      LIMIT 1`,
    [sourceType, sourceId, destinationType, destinationId]
  )).rows[0];

  if ((!Number.isFinite(sourcePointValue) || sourcePointValue <= 0) && configuredRate) {
    sourcePointValue = Number(configuredRate.source_point_value || 0);
  }
  if ((!Number.isFinite(destinationPointValue) || destinationPointValue <= 0) && configuredRate) {
    destinationPointValue = Number(configuredRate.destination_point_value || 0);
  }

  if (!Number.isFinite(sourcePointValue) || sourcePointValue <= 0 || !Number.isFinite(destinationPointValue) || destinationPointValue <= 0) {
    return res.status(400).json({ error: 'exchange_rate_not_configured' });
  }

  const destinationPoints = (sourcePoints * sourcePointValue) / destinationPointValue;
  await pool.query(
    `INSERT INTO exchange_transactions (id, owner_id, source_type, source_id, destination_type, destination_id, source_points, destination_points)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
    [
      id(),
      req.user.userId,
      sourceType,
      sourceId,
      destinationType,
      destinationId,
      sourcePoints,
      Number(destinationPoints.toFixed(6)),
    ]
  );
  return res.json({
    ok: true,
    destinationPoints: Number(destinationPoints.toFixed(6)),
    sourcePoints,
    sourcePointValue,
    destinationPointValue,
    formula: 'destinationPoints = sourcePoints * sourcePointValue / destinationPointValue',
    usedConfiguredRate: Boolean(configuredRate),
  });
});

app.post('/api/reward-claims/create', auth, async (req, res) => {
  const p = req.body || {};
  const pointsCost = Number(p.pointsCost || 0);
  if (!Number.isInteger(pointsCost) || pointsCost <= 0) return res.status(400).json({ error: 'invalid_points_cost' });
  const rewardKind = String(p.rewardKind || 'physical');
  const rewardId = String(p.rewardId || '').trim() || null;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (rewardId) {
      const reward = (await client.query(
        `SELECT id, value, kind, source_type, source_id, is_active, quantity_limit, quantity_redeemed, expires_at
           FROM rewards WHERE id = $1 FOR UPDATE`,
        [rewardId]
      )).rows[0];
      if (!reward) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'reward_not_found' }); }
      if (!reward.is_active) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'reward_inactive' }); }
      if (Number(reward.value) !== pointsCost) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'reward_points_mismatch' }); }
      if (reward.expires_at && new Date(reward.expires_at).getTime() <= Date.now()) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'reward_expired' }); }
      if (reward.quantity_limit != null && Number(reward.quantity_redeemed || 0) >= Number(reward.quantity_limit)) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'reward_sold_out' }); }
      await client.query('UPDATE rewards SET quantity_redeemed = quantity_redeemed + 1 WHERE id = $1', [rewardId]);
    }
    const pointAccount = (await client.query(
      'SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE',
      [req.user.userId]
    )).rows[0];
    if (!pointAccount || Number(pointAccount.available_points || 0) < pointsCost) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'insufficient_points' });
    }
  const claimId = id();
  const qr = crypto.randomUUID().replace(/-/g, '');
  const digitalCode = rewardKind === 'digital'
    ? `DG-${crypto.randomUUID().replace(/-/g, '').slice(0, 12).toUpperCase()}`
    : null;
  const expiresAt = rewardKind === 'digital' ? null : new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  await client.query(
    `INSERT INTO reward_claims (
      id, owner_id, reward_id, source_type, source_id, points_cost, reward_kind,
      pickup_qr_code, digital_code, status, redeemed_at, redeemed_by, expires_at
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
    )`,
    [
      claimId,
      req.user.userId,
      rewardId,
      String(p.sourceType || 'merchant'),
      String(p.sourceId || ''),
      pointsCost,
      rewardKind,
      qr,
      digitalCode,
      rewardKind === 'digital' ? 'used' : 'pending_pickup',
      rewardKind === 'digital' ? new Date().toISOString() : null,
      rewardKind === 'digital' ? req.user.userId : null,
      expiresAt,
    ]
  );
  await client.query('UPDATE point_accounts SET available_points = available_points - $2, updated_at = NOW() WHERE owner_id = $1', [req.user.userId, pointsCost]);
  await client.query('COMMIT');
  return res.json({
    ok: true,
    id: claimId,
    pickupQrCode: rewardKind === 'physical' ? qr : null,
    digitalCode,
    status: rewardKind === 'digital' ? 'used' : 'pending_pickup',
    expiresAt,
  });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'reward_claim_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/reward-claims/my', auth, async (req, res) => {
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query(
    `SELECT *
       FROM reward_claims
      WHERE owner_id = $1
      ORDER BY created_at DESC
      LIMIT $2`,
    [req.user.userId, limit]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    ownerId: row.owner_id,
    sourceType: row.source_type,
    sourceId: row.source_id,
    rewardId: row.reward_id,
    pointsCost: Number(row.points_cost || 0),
    rewardKind: row.reward_kind,
    pickupQrCode: row.pickup_qr_code,
    digitalCode: row.digital_code,
    status: row.status,
    expiresAt: toIso(row.expires_at),
    redeemedAt: toIso(row.redeemed_at),
    redeemedBy: row.redeemed_by,
    settlementId: row.settlement_id,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  })));
});

app.post('/api/cashier/redeem-claim', auth, async (req, res) => {
  const qr = String((req.body || {}).pickupQrCode || '').trim();
  if (!qr) return res.status(400).json({ error: 'pickupQrCode_required' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (await client.query('SELECT * FROM reward_claims WHERE pickup_qr_code = $1 FOR UPDATE', [qr])).rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'claim_not_found' });
    }
    if (row.status !== 'pending_pickup') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'already_processed', status: row.status });
    }
    if (row.expires_at && new Date(row.expires_at).getTime() <= Date.now()) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'claim_expired' });
    }
    if (!(await canRedeemClaim(client, req.user, row))) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'cashier_not_authorized' });
    }

    let settlementId = null;
    if (row.reward_kind === 'physical' && row.source_type === 'merchant' && row.source_id) {
      let escrow = (await client.query(
        `SELECT id, balance
           FROM escrow_accounts
          WHERE source_type = 'merchant'
            AND source_id = $1
          ORDER BY created_at ASC
          LIMIT 1`,
        [row.source_id]
      )).rows[0];

      if (!escrow) {
        const escrowId = id();
        await client.query(
          `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
           VALUES ($1,'merchant',$2,0)`,
          [escrowId, row.source_id]
        );
        escrow = { id: escrowId, balance: 0 };
      }

      await client.query(
        `UPDATE escrow_accounts
            SET balance = balance - $2
          WHERE id = $1`,
        [escrow.id, Number(row.points_cost || 0)]
      );

      settlementId = id();
      await client.query(
        `INSERT INTO settlements (id, escrow_account_id, amount, settlement_type)
         VALUES ($1,$2,$3,'reward_claim_redeemed')`,
        [settlementId, escrow.id, Number(row.points_cost || 0)]
      );
    }

    await client.query(
      "UPDATE reward_claims SET status = 'redeemed', redeemed_at = NOW(), redeemed_by = $2, settlement_id = $3, updated_at = NOW() WHERE id = $1",
      [row.id, req.user.userId, settlementId]
    );

    // Coalition cross-redemption: log ledger entry if cashier's merchant differs from reward source
    if (row.source_type === 'merchant' && row.source_id) {
      const cashierMerchantRes = await client.query(
        `SELECT merchant_id FROM cashier_profiles WHERE user_id = $1 LIMIT 1`,
        [req.user.userId]
      );
      const cashierMerchantId = cashierMerchantRes.rows[0]?.merchant_id;
      if (cashierMerchantId && cashierMerchantId !== row.source_id) {
        // Find a shared active coalition
        const coalRes = await client.query(`
          SELECT cm1.coalition_id,
                 COALESCE(csc.monthly_points_cap, 10000) AS cap,
                 (SELECT COALESCE(SUM(cl2.net_points),0)
                    FROM coalition_ledger cl2
                   WHERE cl2.coalition_id = cm1.coalition_id
                     AND cl2.from_merchant_id = $1
                     AND to_char(cl2.created_at,'YYYY-MM') = to_char(NOW(),'YYYY-MM')
                 ) AS used_this_month
            FROM coalition_members cm1
            JOIN coalition_members cm2 ON cm2.coalition_id = cm1.coalition_id AND cm2.merchant_id = $2
            LEFT JOIN coalition_spending_caps csc ON csc.coalition_id = cm1.coalition_id AND csc.merchant_id = $1
           WHERE cm1.merchant_id = $1
             AND EXISTS (SELECT 1 FROM coalitions c WHERE c.id = cm1.coalition_id AND c.is_active = TRUE)
           LIMIT 1
        `, [row.source_id, cashierMerchantId]);

        if (coalRes.rows.length > 0) {
          const { coalition_id, cap, used_this_month } = coalRes.rows[0];
          const points = Number(row.points_cost || 0);
          if (Number(used_this_month) + points <= Number(cap)) {
            const ledgerId = id();
            const period = new Date().toISOString().slice(0, 7); // YYYY-MM
            await client.query(`
              INSERT INTO coalition_ledger (id, coalition_id, from_merchant_id, to_merchant_id, customer_id, reward_claim_id, points_redeemed, net_points)
              VALUES ($1,$2,$3,$4,$5,$6,$7,$7)
            `, [ledgerId, coalition_id, row.source_id, cashierMerchantId, row.owner_id, row.id, points]);
            // Upsert clearinghouse monthly balance
            await client.query(`
              INSERT INTO coalition_clearinghouse (id, coalition_id, from_merchant_id, to_merchant_id, period, total_points)
              VALUES ($1,$2,$3,$4,$5,$6)
              ON CONFLICT (coalition_id, from_merchant_id, to_merchant_id, period)
              DO UPDATE SET total_points = coalition_clearinghouse.total_points + EXCLUDED.total_points
            `, [id(), coalition_id, row.source_id, cashierMerchantId, period, points]);
          }
        }
      }
    }

    await client.query('COMMIT');
    return res.json({ ok: true, status: 'redeemed', settlementId });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'claim_redeem_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/reward-claims/refund-expired/run', auth, requireAdmin, async (_req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const rows = (await client.query(
      `SELECT id, owner_id, points_cost
         FROM reward_claims
        WHERE status = 'pending_pickup'
          AND expires_at IS NOT NULL
          AND expires_at <= NOW()
        FOR UPDATE`
    )).rows;
    for (const row of rows) {
      await client.query("UPDATE reward_claims SET status = 'refunded_as_points', updated_at = NOW() WHERE id = $1", [row.id]);
      await client.query('UPDATE point_accounts SET available_points = available_points + $2, updated_at = NOW() WHERE owner_id = $1', [row.owner_id, row.points_cost]);
    }
    await client.query('COMMIT');
    return res.json({ ok: true, refunded: rows.length });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'claim_refund_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/reward-claims/:id/expire-now', auth, requireAdmin, async (req, res) => {
  const claimId = req.params.id;
  await pool.query(
    `UPDATE reward_claims
        SET expires_at = NOW() - INTERVAL '1 minute',
            updated_at = NOW()
      WHERE id = $1`,
    [claimId]
  );
  return res.json({ ok: true, id: claimId, expiredAt: new Date(Date.now() - 60000).toISOString() });
});

app.get('/api/merchant/escrow/summary', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    let escrow = (await client.query(
      `SELECT id, balance
         FROM escrow_accounts
        WHERE source_type = 'merchant'
          AND source_id = $1
        ORDER BY created_at ASC
        LIMIT 1`,
      [merchantId]
    )).rows[0];

    if (!escrow) {
      const escrowId = id();
      await client.query(
        `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
         VALUES ($1,'merchant',$2,0)`,
        [escrowId, merchantId]
      );
      escrow = { id: escrowId, balance: 0 };
    }

    const settlements = (await client.query(
      `SELECT id, amount, settlement_type, created_at
         FROM settlements
        WHERE escrow_account_id = $1
        ORDER BY created_at DESC
        LIMIT 50`,
      [escrow.id]
    )).rows;

    return res.json({
      ok: true,
      merchantId,
      escrowAccount: {
        id: escrow.id,
        balance: Number(escrow.balance || 0),
      },
      settlements: settlements.map((s) => ({
        id: s.id,
        amount: Number(s.amount || 0),
        settlementType: s.settlement_type,
        createdAt: toIso(s.created_at),
      })),
    });
  } catch (e) {
    return res.status(500).json({ error: 'merchant_escrow_summary_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

};
