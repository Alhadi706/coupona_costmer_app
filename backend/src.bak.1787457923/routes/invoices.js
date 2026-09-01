const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerInvoicesRoutes(app, deps) {
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

app.post('/api/invoices/scan-v2', auth, async (req, res) => {
  const p = req.body || {};
  const ownerId = req.user.userId;
  const invoiceDate = parseFlexibleDate(p.invoiceDate || p.date);
  if (!invoiceDate) return res.status(400).json({ error: 'invalid_invoice_date' });
  const ageHours = (Date.now() - invoiceDate.getTime()) / (1000 * 60 * 60);
  if (ageHours > 48) {
    await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'invoice_older_than_48h', JSON.stringify({ invoiceDate: p.invoiceDate || p.date })]);
    return res.status(400).json({ error: 'invoice_too_old' });
  }

  const limit = await getIntSetting(pool, 'daily_invoice_limit', 10);
  const daily = (await pool.query(
    `SELECT COUNT(*)::int AS c
       FROM invoice_scans
      WHERE owner_id = $1
        AND created_at >= date_trunc('day', NOW())`,
    [ownerId]
  )).rows[0]?.c || 0;
  if (daily >= limit) {
    await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'daily_invoice_limit_reached', JSON.stringify({ daily, limit })]);
    return res.status(400).json({ error: 'daily_invoice_limit_reached' });
  }

  const invoiceNumber = String(p.invoiceNumber || '').trim();
  if (invoiceNumber) {
    const exists = (await pool.query('SELECT 1 FROM invoice_scans WHERE invoice_number = $1 LIMIT 1', [invoiceNumber])).rows[0];
    if (exists) {
      await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'duplicate_reference_any_account', JSON.stringify({ invoiceNumber })]);
      return res.status(409).json({ error: 'duplicate_reference' });
    }
  }

  const rawImageHash = String(p.imageHash || '').trim();
  if (rawImageHash) {
    const similar = (await pool.query('SELECT 1 FROM invoice_scans WHERE image_hash = $1 LIMIT 1', [rawImageHash])).rows[0];
    if (similar) {
      await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'suspected_image_modification', JSON.stringify({ imageHash: rawImageHash })]);
      return res.status(409).json({ error: 'suspected_image_modification' });
    }
  }

  const retentionMonths = await getIntSetting(pool, 'invoice_retention_months', 24);
  const retentionDate = new Date();
  retentionDate.setMonth(retentionDate.getMonth() + retentionMonths);
  const merchantProfileId = String(p.merchantProfileId || '').trim() || null;
  const branchId = String(p.branchId || '').trim() || null;

  const scanId = id();
  await pool.query(
    `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, invoice_number, order_number, invoice_date, total_amount, currency, category, raw_text, reward_applied, image_hash, retention_expires_at, merchant_profile_id, branch_id, state)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,COALESCE($9,'SAR'),COALESCE($10,'general'),COALESCE($11,''),FALSE,$12,$13,$14,$15,'processing')`,
    [
      scanId,
      ownerId,
      p.merchantName || null,
      normalizeMerchantKey(p.merchantName || p.merchantKey || 'merchant'),
      invoiceNumber || null,
      p.orderNumber || null,
      invoiceDate.toISOString().slice(0, 10),
      p.totalAmount || null,
      p.currency || 'SAR',
      p.category || 'general',
      p.rawText || '',
      rawImageHash || null,
      retentionDate.toISOString(),
      merchantProfileId,
      branchId,
    ]
  );

  return res.json({ ok: true, id: scanId, state: 'processing' });
});

app.post('/api/admin/data-retention/run', auth, requireAdmin, async (_req, res) => {
  try {
    await pool.query("UPDATE invoice_scans SET raw_text = '' WHERE retention_expires_at IS NOT NULL AND retention_expires_at < NOW()");
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'retention_purge_failed', details: String(e.message || e) });
  }
});

app.post('/api/brand/products', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
    const p = req.body || {};
    const productId = id();
    await client.query(
      'INSERT INTO product_registry (id, brand_id, name, image_url, barcode) VALUES ($1,$2,$3,$4,$5)',
      [productId, brandId, String(p.name || '').trim(), p.imageUrl || null, p.barcode || null]
    );
    return res.json({ ok: true, id: productId });
  } catch (e) {
    return res.status(500).json({ error: 'product_create_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/line-items', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const items = Array.isArray((req.body || {}).items) ? req.body.items : [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const access = await canManageInvoice(client, req.user, invoiceId);
    if (!access.allowed) {
      await client.query('ROLLBACK');
      return res.status(access.status).json({ error: access.error });
    }
    const createdLineItemIds = [];
    for (const item of items) {
      const lineId = id();
      createdLineItemIds.push(lineId);
      await client.query(
        'INSERT INTO invoice_line_items (id, invoice_scan_id, item_name, quantity, unit_price, line_total) VALUES ($1,$2,$3,$4,$5,$6)',
        [lineId, invoiceId, String(item.name || '').trim(), item.quantity || null, item.unitPrice || null, item.lineTotal || null]
      );
    }
    await client.query('COMMIT');
    return res.json({ ok: true, count: items.length, lineItemIds: createdLineItemIds });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'invoice_line_items_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/brand-matches', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const matches = Array.isArray((req.body || {}).matches) ? req.body.matches : [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const access = await canManageInvoice(client, req.user, invoiceId);
    if (!access.allowed) {
      await client.query('ROLLBACK');
      return res.status(access.status).json({ error: access.error });
    }
    for (const match of matches) {
      const lineItemId = String(match.invoiceLineItemId || '').trim();
      const brandId = String(match.brandId || '').trim();
      if (!lineItemId || !brandId) continue;
      await client.query(
        `INSERT INTO brand_matches (id, invoice_line_item_id, brand_id, product_id, confidence)
         VALUES ($1, $2, $3, $4, COALESCE($5, 0))`,
        [id(), lineItemId, brandId, match.productId || null, Number(match.confidence || 0)]
      );
    }
    await client.query('COMMIT');
    return res.json({ ok: true, count: matches.length, invoiceId });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'brand_match_persist_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/state-transition', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const to = String((req.body || {}).to || '').trim();
  const note = String((req.body || {}).note || (req.body || {}).reason || '').trim();
  const allowed = {
    uploaded: ['processing'],
    processing: ['approved', 'rejected', 'manual_review'],
    manual_review: ['approved', 'rejected'],
    rejected: ['disputed'],
    disputed: ['dispute_upheld', 'dispute_denied'],
    dispute_upheld: ['approved'],
    dispute_denied: ['closed_rejected'],
  };
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const access = await canManageInvoice(client, req.user, invoiceId, to);
    if (!access.allowed) {
      await client.query('ROLLBACK');
      return res.status(access.status).json({ error: access.error });
    }
    const row = (await client.query('SELECT state FROM invoice_scans WHERE id = $1 LIMIT 1', [invoiceId])).rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'invoice_not_found' });
    }
    const from = row.state || 'uploaded';
    const list = allowed[from] || [];
    if (!list.includes(to)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'invalid_transition', from, to });
    }

    await client.query(
      `UPDATE invoice_scans
          SET state = $2,
              review_note = COALESCE(NULLIF($3, ''), review_note)
        WHERE id = $1`,
      [invoiceId, to, note]
    );

    const invoiceRow = (await client.query(
      'SELECT owner_id, merchant_profile_id FROM invoice_scans WHERE id = $1 LIMIT 1',
      [invoiceId]
    )).rows[0];

    let awards = null;
    if (invoiceRow) {
      if (to === 'approved') {
        awards = await applyInvoiceApprovalRewards(client, invoiceId, invoiceRow.owner_id, invoiceRow.merchant_profile_id);
        if (invoiceRow.merchant_profile_id) {
          await joinCustomerToMerchantCommunity(client, invoiceRow.owner_id, invoiceRow.merchant_profile_id);
        }
        await joinCustomerToBrandCommunities(client, invoiceRow.owner_id, invoiceId);
        await insertNotification(
          client,
          invoiceRow.owner_id,
          'invoice_approved',
          'Invoice approved',
          'Your invoice has been approved.',
          { invoiceId }
        );
      }
      if (to === 'rejected') {
        await insertNotification(
          client,
          invoiceRow.owner_id,
          'invoice_rejected',
          'Invoice rejected',
          'Your invoice has been rejected. You can dispute it if needed.',
          { invoiceId, note: note || null }
        );
      }
    }

    await client.query('COMMIT');
    return res.json({ ok: true, from, to, note: note || null, awards });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'invoice_transition_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/disputes', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const ownerId = req.user.userId;
  const reason = String((req.body || {}).reason || '').trim();
  const evidence = String((req.body || {}).evidence || '').trim() || null;
  if (!reason) return res.status(400).json({ error: 'reason_required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const invoice = (await client.query(
      'SELECT owner_id, state FROM invoice_scans WHERE id = $1 LIMIT 1',
      [invoiceId]
    )).rows[0];
    if (!invoice) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'invoice_not_found' });
    }
    if (invoice.owner_id !== ownerId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'invoice_owner_required' });
    }
    if (invoice.state !== 'rejected') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'invoice_not_rejected' });
    }

    const disputeId = id();
    await client.query(
      `INSERT INTO disputes (id, owner_id, invoice_scan_id, status, reason)
       VALUES ($1,$2,$3,'new',$4)`,
      [disputeId, ownerId, invoiceId, evidence ? `${reason}\n${evidence}` : reason]
    );
    await client.query(
      `UPDATE invoice_scans
          SET state = 'disputed',
              review_note = COALESCE(review_note, '') || CASE WHEN review_note IS NULL OR review_note = '' THEN '' ELSE E'\n' END || $2
        WHERE id = $1`,
      [invoiceId, `DISPUTE: ${reason}`]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, id: disputeId, status: 'new' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'create_dispute_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/invoices/disputes', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    const status = String(req.query.status || 'new').trim() || 'new';
    const rows = (await client.query(
      `SELECT d.id,
              d.invoice_scan_id,
              d.status,
              d.reason,
              d.created_at,
              d.updated_at,
              s.owner_id,
              s.invoice_number,
              s.total_amount,
              s.state,
              s.merchant_name,
              COALESCE(u.full_name, u.email) AS owner_label
         FROM disputes d
         JOIN invoice_scans s ON s.id = d.invoice_scan_id
         LEFT JOIN users u ON u.id = s.owner_id
        WHERE s.merchant_profile_id = $1
          AND d.status = $2
        ORDER BY d.created_at DESC
        LIMIT 100`,
      [merchantId, status]
    )).rows;
    return res.json(rows.map((r) => ({
      id: r.id,
      invoiceId: r.invoice_scan_id,
      status: r.status,
      reason: r.reason,
      createdAt: toIso(r.created_at),
      updatedAt: toIso(r.updated_at),
      ownerId: r.owner_id,
      ownerLabel: r.owner_label,
      merchantName: r.merchant_name,
      invoiceNumber: r.invoice_number,
      totalAmount: r.total_amount == null ? null : Number(r.total_amount),
      invoiceState: r.state,
    })));
  } catch (e) {
    return res.status(500).json({ error: 'merchant_disputes_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/invoices/disputes/:id/resolve', auth, async (req, res) => {
  const disputeId = req.params.id;
  const decision = String((req.body || {}).decision || '').trim().toLowerCase();
  const resolutionNote = String((req.body || {}).reason || '').trim();
  if (!['upheld', 'denied'].includes(decision)) {
    return res.status(400).json({ error: 'invalid_decision' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const row = (await client.query(
      `SELECT d.id,
              d.owner_id,
              d.invoice_scan_id,
              d.status,
              s.owner_id AS invoice_owner_id,
              s.merchant_profile_id
         FROM disputes d
         JOIN invoice_scans s ON s.id = d.invoice_scan_id
        WHERE d.id = $1
        LIMIT 1`,
      [disputeId]
    )).rows[0];

    if (!row) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'dispute_not_found' });
    }
    if (row.merchant_profile_id !== merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_scope_denied' });
    }
    if (row.status !== 'new') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'dispute_already_resolved' });
    }

    let toState = 'closed_rejected';
    let awards = null;
    if (decision === 'upheld') {
      toState = 'approved';
      awards = await applyInvoiceApprovalRewards(client, row.invoice_scan_id, row.invoice_owner_id, merchantId);
      await joinCustomerToMerchantCommunity(client, row.invoice_owner_id, merchantId);
      await joinCustomerToBrandCommunities(client, row.invoice_owner_id, row.invoice_scan_id);
      await insertNotification(
        client,
        row.invoice_owner_id,
        'invoice_approved',
        'Invoice approved after dispute',
        'Your dispute was accepted and the invoice has been approved.',
        { invoiceId: row.invoice_scan_id, disputeId: row.id }
      );
    } else {
      await insertNotification(
        client,
        row.invoice_owner_id,
        'invoice_dispute_denied',
        'Invoice dispute denied',
        'Your dispute was reviewed and denied.',
        { invoiceId: row.invoice_scan_id, disputeId: row.id }
      );
    }

    await client.query(
      `UPDATE disputes
          SET status = $2,
              reason = CASE
                WHEN $3 = '' THEN reason
                WHEN reason IS NULL OR reason = '' THEN $3
                ELSE reason || E'\nRESOLUTION: ' || $3
              END,
              updated_at = NOW()
        WHERE id = $1`,
      [disputeId, decision, resolutionNote]
    );
    await client.query(
      `UPDATE invoice_scans
          SET state = $2,
              review_note = COALESCE(review_note, '') || CASE WHEN review_note IS NULL OR review_note = '' THEN '' ELSE E'\n' END || $3
        WHERE id = $1`,
      [row.invoice_scan_id, toState, `DISPUTE_${decision.toUpperCase()}: ${resolutionNote || 'resolved'}`]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, disputeId, decision, invoiceId: row.invoice_scan_id, toState, awards });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'resolve_dispute_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

};
