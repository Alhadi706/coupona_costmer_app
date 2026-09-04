const crypto = require('crypto');

function hashToken(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex');
}

function newToken() {
  return crypto.randomBytes(32).toString('base64url');
}

module.exports = function registerGiftRoutes(app, deps) {
  const {
    pool,
    auth,
    id,
    toIso,
    getMerchantProfileIdByUser,
    getBrandProfileIdByUser,
    getBrandIdWithPermission,
    insertNotification,
  } = deps;
  const { resolveSegment } = require('../customer-segmentation-service');

  async function resolveSource(client, userId) {
    const merchantId = await getMerchantProfileIdByUser(client, userId);
    if (merchantId) return { sourceType: 'merchant', sourceId: merchantId, sourceMerchantId: merchantId, sourceBrandId: null, sourceCoalitionId: null };
    const brandId = await getBrandProfileIdByUser(client, userId) || await getBrandIdWithPermission(client, userId, 'can_manage_campaigns');
    if (brandId) return { sourceType: 'brand', sourceId: brandId, sourceMerchantId: null, sourceBrandId: brandId, sourceCoalitionId: null };
    return null;
  }

  async function getSourceName(client, source) {
    if (source.sourceMerchantId) {
      return (await client.query('SELECT business_name FROM merchant_profiles WHERE id = $1 LIMIT 1', [source.sourceMerchantId])).rows[0]?.business_name || 'Merchant';
    }
    if (source.sourceBrandId) {
      return (await client.query('SELECT business_name FROM brand_profiles WHERE id = $1 LIMIT 1', [source.sourceBrandId])).rows[0]?.business_name || 'Brand';
    }
    return 'Source';
  }

  async function getFulfillerMerchantId(client, userId) {
    const merchantId = await getMerchantProfileIdByUser(client, userId);
    if (merchantId) return merchantId;
    return (await client.query(
      `SELECT merchant_id FROM cashier_profiles WHERE user_id = $1 AND is_active = TRUE LIMIT 1`,
      [userId]
    )).rows[0]?.merchant_id || null;
  }

  async function canFulfillGift(client, user, gift, branchId, fulfillerMerchantId) {
    if (user.isSystemOwner || user.role === 'admin') return true;
    if (!fulfillerMerchantId) return false;
    if (gift.source_merchant_id && gift.source_merchant_id === fulfillerMerchantId) return true;
    const location = (await client.query(
      `SELECT 1
         FROM gift_fulfillment_locations gfl
         LEFT JOIN branches b ON b.id = gfl.branch_id
        WHERE gfl.gift_definition_id = $1
          AND gfl.is_active = TRUE
          AND (gfl.merchant_id = $2 OR b.merchant_id = $2)
          AND ($3::text IS NULL OR gfl.branch_id IS NULL OR gfl.branch_id = $3)
        LIMIT 1`,
      [gift.id, fulfillerMerchantId, branchId || null]
    )).rows[0];
    if (location) return true;
    if (!gift.source_coalition_id) return false;
    const coalitionMember = (await client.query(
      `SELECT 1
         FROM coalition_fulfillment_members
        WHERE coalition_id = $1
          AND merchant_id = $2
          AND is_active = TRUE
          AND fulfillment_scope IN ('GIFT', 'BOTH')
          AND (gift_definition_id IS NULL OR gift_definition_id = $3)
          AND ($4::text IS NULL OR branch_id IS NULL OR branch_id = $4)
        LIMIT 1`,
      [gift.source_coalition_id, fulfillerMerchantId, gift.id, branchId || null]
    )).rows[0];
    return Boolean(coalitionMember);
  }

  function mapGift(row) {
    return {
      id: row.id || row.gift_definition_id,
      giftType: row.gift_type,
      title: row.title,
      description: row.description,
      imageUrl: row.image_url,
      valueAmount: row.value_amount == null ? null : Number(row.value_amount),
      discountPercentage: row.discount_percentage,
      terms: row.terms,
      pickupInstructions: row.pickup_instructions,
      status: row.status,
      startsAt: toIso(row.starts_at),
      expiresAt: toIso(row.expires_at),
      createdAt: toIso(row.created_at),
    };
  }

  app.post('/api/gifts/definitions', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      const source = await resolveSource(client, req.user.userId);
      if (!source) return res.status(403).json({ error: 'merchant_or_brand_role_required' });
      const body = req.body || {};
      const giftType = String(body.giftType || body.gift_type || '').trim().toUpperCase();
      const title = String(body.title || '').trim();
      if (!['PHYSICAL_PRODUCT', 'VOUCHER', 'DISCOUNT', 'SERVICE', 'STORE_CREDIT'].includes(giftType)) return res.status(400).json({ error: 'invalid_gift_type' });
      if (!title) return res.status(400).json({ error: 'gift_title_required' });
      const discountPercentage = body.discountPercentage ?? body.discount_percentage ?? null;
      if (giftType === 'DISCOUNT' && !(Number(discountPercentage) >= 0 && Number(discountPercentage) <= 100)) return res.status(400).json({ error: 'discount_percentage_required' });
      const created = (await client.query(
        `INSERT INTO gift_definitions (
          source_merchant_id, source_brand_id, source_coalition_id, product_id,
          gift_type, title, description, image_url, value_amount, discount_percentage,
          terms, pickup_instructions, status, starts_at, expires_at, created_by_user_id, snapshot_json
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17::jsonb)
        RETURNING *`,
        [
          source.sourceMerchantId,
          source.sourceBrandId,
          source.sourceCoalitionId,
          String(body.productId || '').trim() || null,
          giftType,
          title,
          String(body.description || '').trim() || null,
          String(body.imageUrl || body.image_url || '').trim() || null,
          body.valueAmount ?? body.value_amount ?? null,
          discountPercentage,
          String(body.terms || '').trim() || null,
          String(body.pickupInstructions || body.pickup_instructions || '').trim() || null,
          ['DRAFT', 'ACTIVE', 'PAUSED'].includes(String(body.status || '').toUpperCase()) ? String(body.status).toUpperCase() : 'DRAFT',
          body.startsAt || body.starts_at || null,
          body.expiresAt || body.expires_at || null,
          req.user.userId,
          JSON.stringify({ title, giftType, description: body.description || null, valueAmount: body.valueAmount ?? body.value_amount ?? null }),
        ]
      )).rows[0];
      return res.status(201).json({ ok: true, gift: mapGift(created) });
    } catch (error) {
      return res.status(500).json({ error: 'gift_definition_create_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.get('/api/gifts/definitions/mine', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      const source = await resolveSource(client, req.user.userId);
      if (!source) return res.status(403).json({ error: 'merchant_or_brand_role_required' });
      const rows = source.sourceType === 'merchant'
        ? (await client.query(
          `SELECT * FROM gift_definitions
            WHERE source_merchant_id = $1
            ORDER BY created_at DESC`,
          [source.sourceMerchantId]
        )).rows
        : (await client.query(
          `SELECT * FROM gift_definitions
            WHERE source_brand_id = $1
            ORDER BY created_at DESC`,
          [source.sourceBrandId]
        )).rows;
      return res.json({ gifts: rows.map(mapGift) });
    } finally {
      client.release();
    }
  });

  app.get('/api/gifts/analytics/mine', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      const source = await resolveSource(client, req.user.userId);
      if (!source) return res.status(403).json({ error: 'merchant_or_brand_role_required' });
      const rows = source.sourceType === 'merchant'
        ? (await client.query(
          `SELECT
             COUNT(DISTINCT gd.id)::int AS gift_count,
             COUNT(DISTINCT gd.id) FILTER (WHERE gd.status = 'ACTIVE')::int AS active_gift_count,
             COUNT(DISTINCT pc.id)::int AS campaign_count,
             COUNT(DISTINCT ca.id)::int AS assignment_count,
             COUNT(DISTINCT ca.id) FILTER (WHERE ca.status = 'VIEWED')::int AS viewed_count,
             COUNT(DISTINCT gc.id)::int AS claim_count,
             COUNT(DISTINCT r.id) FILTER (WHERE r.status = 'COMPLETED')::int AS redeemed_count,
             COUNT(DISTINCT r.id) FILTER (WHERE r.status = 'REVERSED')::int AS reversed_count
           FROM gift_definitions gd
           LEFT JOIN promo_campaigns pc ON pc.gift_definition_id = gd.id
           LEFT JOIN campaign_assignments ca ON ca.campaign_id = pc.id
           LEFT JOIN gift_claims gc ON gc.assignment_id = ca.id
           LEFT JOIN redemptions r ON r.gift_claim_id = gc.id
          WHERE gd.source_merchant_id = $1`,
          [source.sourceMerchantId]
        )).rows
        : (await client.query(
          `SELECT
             COUNT(DISTINCT gd.id)::int AS gift_count,
             COUNT(DISTINCT gd.id) FILTER (WHERE gd.status = 'ACTIVE')::int AS active_gift_count,
             COUNT(DISTINCT pc.id)::int AS campaign_count,
             COUNT(DISTINCT ca.id)::int AS assignment_count,
             COUNT(DISTINCT ca.id) FILTER (WHERE ca.status = 'VIEWED')::int AS viewed_count,
             COUNT(DISTINCT gc.id)::int AS claim_count,
             COUNT(DISTINCT r.id) FILTER (WHERE r.status = 'COMPLETED')::int AS redeemed_count,
             COUNT(DISTINCT r.id) FILTER (WHERE r.status = 'REVERSED')::int AS reversed_count
           FROM gift_definitions gd
           LEFT JOIN promo_campaigns pc ON pc.gift_definition_id = gd.id
           LEFT JOIN campaign_assignments ca ON ca.campaign_id = pc.id
           LEFT JOIN gift_claims gc ON gc.assignment_id = ca.id
           LEFT JOIN redemptions r ON r.gift_claim_id = gc.id
          WHERE gd.source_brand_id = $1`,
          [source.sourceBrandId]
        )).rows;
      const analytics = rows[0] || {};
      const assignments = Number(analytics.assignment_count || 0);
      const redeemed = Number(analytics.redeemed_count || 0);
      return res.json({
        ok: true,
        giftCount: Number(analytics.gift_count || 0),
        activeGiftCount: Number(analytics.active_gift_count || 0),
        campaignCount: Number(analytics.campaign_count || 0),
        assignmentCount: assignments,
        viewedCount: Number(analytics.viewed_count || 0),
        claimedCount: Number(analytics.claim_count || 0),
        redeemedCount: redeemed,
        reversedCount: Number(analytics.reversed_count || 0),
        redemptionRate: assignments > 0 ? Number(((redeemed / assignments) * 100).toFixed(2)) : 0,
      });
    } finally {
      client.release();
    }
  });

  app.post('/api/gifts/definitions/:id/campaigns/launch', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const source = await resolveSource(client, req.user.userId);
      if (!source) { await client.query('ROLLBACK'); return res.status(403).json({ error: 'merchant_or_brand_role_required' }); }
      const gift = (await client.query(
        `SELECT * FROM gift_definitions
          WHERE id = $1
            AND status IN ('DRAFT', 'ACTIVE')
            AND (source_merchant_id IS NOT DISTINCT FROM $2)
            AND (source_brand_id IS NOT DISTINCT FROM $3)
          FOR UPDATE`,
        [req.params.id, source.sourceMerchantId, source.sourceBrandId]
      )).rows[0];
      if (!gift) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'gift_not_found' }); }
      const body = req.body || {};
      const startsAt = new Date(body.startsAt || body.starts_at || Date.now());
      const endsAt = new Date(body.endsAt || body.ends_at || gift.expires_at || Date.now() + 7 * 24 * 60 * 60 * 1000);
      if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime()) || endsAt <= startsAt) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'invalid_validity_window' }); }
      const segmentFilter = String(body.segmentFilter || body.segment_filter || 'all');
      const segmentParams = body.segmentParams && typeof body.segmentParams === 'object' ? body.segmentParams : {};
      const segment = await resolveSegment(client, source.sourceType, source.sourceId, segmentFilter, segmentParams);
      const maxRecipients = Math.max(0, Math.floor(Number(body.maxRecipients || body.max_recipients || 0)));
      const customerIds = segment.map((entry) => entry.customerId).slice(0, maxRecipients > 0 ? maxRecipients : segment.length);
      const campaignId = id();
      const sourceName = await getSourceName(client, source);
      await client.query(
        `INSERT INTO promo_campaigns (
          id, source_type, source_id, source_merchant_id, source_brand_id, source_coalition_id,
          campaign_type, title, description, gift_description, segment_filter, segment_params,
          starts_at, ends_at, status, launched_at, gift_definition_id
        ) VALUES ($1,$2,$3,$4,$5,$6,'free_gift',$7,$8,$9,$10,$11::jsonb,$12,$13,'active',NOW(),$14)`,
        [campaignId, source.sourceType, source.sourceId, source.sourceMerchantId, source.sourceBrandId, source.sourceCoalitionId, String(body.title || gift.title).trim(), String(body.description || gift.description || '').trim() || null, gift.description || gift.title, segmentFilter, JSON.stringify(segmentParams), startsAt.toISOString(), endsAt.toISOString(), gift.id]
      );
      const assignments = [];
      for (const customerId of customerIds) {
        const assignment = (await client.query(
          `INSERT INTO campaign_assignments (campaign_id, customer_id, assignment_kind, status, notified_at, expires_at, snapshot_json)
           VALUES ($1,$2,'gift','NOTIFIED',NOW(),$3,$4::jsonb)
           ON CONFLICT DO NOTHING
           RETURNING id`,
          [campaignId, customerId, endsAt.toISOString(), JSON.stringify({ giftId: gift.id, title: gift.title, giftType: gift.gift_type, sourceName })]
        )).rows[0];
        if (assignment) {
          assignments.push({ assignmentId: assignment.id, customerId });
          await insertNotification(client, customerId, 'gift_assigned', gift.title, gift.description || `لديك هدية جديدة من ${sourceName}.`, { campaignId, giftId: gift.id, assignmentId: assignment.id, targetScreen: 'gifts_rewards' });
        }
      }
      await client.query("UPDATE gift_definitions SET status = 'ACTIVE', updated_at = NOW() WHERE id = $1", [gift.id]);
      await client.query(
        `INSERT INTO business_events (event_type, aggregate_type, aggregate_id, source_merchant_id, source_brand_id, source_coalition_id, payload)
         VALUES ('GIFT_CAMPAIGN_LAUNCHED', 'promo_campaigns', $1, $2, $3, $4, $5::jsonb)`,
        [campaignId, source.sourceMerchantId, source.sourceBrandId, source.sourceCoalitionId, JSON.stringify({ giftId: gift.id, assignmentCount: assignments.length })]
      );
      await client.query('COMMIT');
      return res.status(201).json({ ok: true, campaignId, assignmentCount: assignments.length, assignments });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'gift_campaign_launch_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.get('/api/customer/gifts/assignments', auth, async (req, res) => {
    const rows = (await pool.query(
      `SELECT ca.id AS assignment_id, ca.status AS assignment_status, ca.assigned_at, ca.notified_at,
              ca.viewed_at, ca.claimed_at, ca.redeemed_at, ca.expires_at,
              gd.id AS gift_id, gd.gift_type, gd.title, gd.description, gd.image_url,
              gd.value_amount, gd.discount_percentage, gd.terms, gd.pickup_instructions,
              pc.id AS campaign_id, pc.title AS campaign_title
         FROM campaign_assignments ca
         JOIN promo_campaigns pc ON pc.id = ca.campaign_id
         JOIN gift_definitions gd ON gd.id = pc.gift_definition_id
        WHERE ca.customer_id = $1 AND ca.assignment_kind = 'gift'
        ORDER BY ca.assigned_at DESC`,
      [req.user.userId]
    )).rows;
    return res.json({ assignments: rows.map((row) => ({ assignmentId: row.assignment_id, status: row.assignment_status, assignedAt: toIso(row.assigned_at), notifiedAt: toIso(row.notified_at), viewedAt: toIso(row.viewed_at), claimedAt: toIso(row.claimed_at), redeemedAt: toIso(row.redeemed_at), expiresAt: toIso(row.expires_at), campaignId: row.campaign_id, campaignTitle: row.campaign_title, gift: mapGift({ id: row.gift_id, gift_type: row.gift_type, title: row.title, description: row.description, image_url: row.image_url, value_amount: row.value_amount, discount_percentage: row.discount_percentage, terms: row.terms, pickup_instructions: row.pickup_instructions, status: null, starts_at: null, expires_at: row.expires_at, created_at: null }) })) });
  });

  app.post('/api/customer/gifts/assignments/:id/view', auth, async (req, res) => {
    const updated = (await pool.query(
      `UPDATE campaign_assignments
          SET status = CASE WHEN status = 'NOTIFIED' THEN 'VIEWED' ELSE status END,
              viewed_at = COALESCE(viewed_at, NOW()), updated_at = NOW()
        WHERE id = $1 AND customer_id = $2 AND status IN ('NOTIFIED', 'VIEWED', 'CLAIMED')
        RETURNING id, status, viewed_at`,
      [req.params.id, req.user.userId]
    )).rows[0];
    if (!updated) return res.status(404).json({ error: 'gift_assignment_not_found' });
    return res.json({ ok: true, assignmentId: updated.id, status: updated.status, viewedAt: toIso(updated.viewed_at) });
  });

  app.post('/api/customer/gifts/assignments/:id/claim', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const assignment = (await client.query(
        `SELECT ca.*, gd.id AS gift_definition_id, gd.title, gd.gift_type, gd.description, gd.status AS gift_status,
                gd.expires_at AS gift_expires_at, pc.status AS campaign_status, pc.ends_at
           FROM campaign_assignments ca
           JOIN promo_campaigns pc ON pc.id = ca.campaign_id
           JOIN gift_definitions gd ON gd.id = pc.gift_definition_id
          WHERE ca.id = $1 AND ca.customer_id = $2
          FOR UPDATE`,
        [req.params.id, req.user.userId]
      )).rows[0];
      if (!assignment) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'gift_assignment_not_found' }); }
      if (!['NOTIFIED', 'VIEWED', 'CLAIMED'].includes(assignment.status)) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_assignment_not_claimable', status: assignment.status }); }
      if (assignment.campaign_status !== 'active' || assignment.gift_status !== 'ACTIVE') { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_not_active' }); }
      const expiresAt = assignment.expires_at || assignment.gift_expires_at || assignment.ends_at;
      if (expiresAt && new Date(expiresAt).getTime() <= Date.now()) { await client.query('ROLLBACK'); return res.status(410).json({ error: 'gift_assignment_expired' }); }
      let claim = (await client.query(`SELECT * FROM gift_claims WHERE assignment_id = $1 AND status IN ('CLAIMED', 'TOKENIZED', 'VERIFIED', 'REDEEMED') LIMIT 1`, [assignment.id])).rows[0];
      if (!claim) {
        claim = (await client.query(
          `INSERT INTO gift_claims (assignment_id, customer_id, gift_definition_id, status, expires_at, snapshot_json)
           VALUES ($1,$2,$3,'CLAIMED',$4,$5::jsonb) RETURNING *`,
          [assignment.id, req.user.userId, assignment.gift_definition_id, expiresAt, JSON.stringify({ title: assignment.title, giftType: assignment.gift_type, description: assignment.description })]
        )).rows[0];
      }
      const rawToken = newToken();
      const token = (await client.query(
        `INSERT INTO redemption_tokens (gift_claim_id, purpose, token_hash, status, active_at, expires_at)
         VALUES ($1,'REDEMPTION',$2,'ACTIVE',NOW(),$3)
         ON CONFLICT DO NOTHING RETURNING id`,
        [claim.id, hashToken(rawToken), expiresAt]
      )).rows[0];
      if (!token) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'active_gift_token_exists' }); }
      await client.query("UPDATE gift_claims SET status = 'TOKENIZED', tokenized_at = NOW(), updated_at = NOW() WHERE id = $1", [claim.id]);
      await client.query("UPDATE campaign_assignments SET status = 'CLAIMED', claimed_at = COALESCE(claimed_at, NOW()), updated_at = NOW() WHERE id = $1", [assignment.id]);
      await client.query(`INSERT INTO business_events (event_type, aggregate_type, aggregate_id, customer_id, payload) VALUES ('GIFT_CLAIMED', 'gift_claims', $1, $2, $3::jsonb)`, [String(claim.id), req.user.userId, JSON.stringify({ assignmentId: assignment.id, giftDefinitionId: assignment.gift_definition_id, tokenId: token.id })]);
      await client.query('COMMIT');
      return res.status(201).json({ ok: true, claimId: claim.id, assignmentId: assignment.id, redemptionToken: rawToken, expiresAt: toIso(expiresAt) });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'gift_claim_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/cashier/gifts/verify', auth, async (req, res) => {
    const qrToken = String((req.body || {}).redemptionToken || (req.body || {}).qrToken || '').trim();
    const branchId = String((req.body || {}).branchId || '').trim() || null;
    if (!qrToken) return res.status(400).json({ error: 'redemption_token_required' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const row = (await client.query(
        `SELECT rt.id AS token_id, rt.gift_claim_id, rt.status AS token_status, rt.expires_at AS token_expires_at,
                gc.customer_id, gc.status AS claim_status,
                gd.id AS gift_definition_id, gd.gift_type, gd.title, gd.description, gd.image_url,
                gd.value_amount, gd.discount_percentage, gd.terms, gd.pickup_instructions,
                gd.status AS gift_status, gd.starts_at, gd.expires_at AS gift_expires_at,
                gd.source_merchant_id, gd.source_brand_id, gd.source_coalition_id,
                ca.status AS assignment_status
           FROM redemption_tokens rt
           JOIN gift_claims gc ON gc.id = rt.gift_claim_id
           JOIN campaign_assignments ca ON ca.id = gc.assignment_id
           JOIN gift_definitions gd ON gd.id = gc.gift_definition_id
          WHERE rt.token_hash = $1 FOR UPDATE`,
        [hashToken(qrToken)]
      )).rows[0];
      if (!row) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'gift_token_not_found' }); }
      if (!['ACTIVE', 'SCANNED', 'VERIFIED'].includes(row.token_status)) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_token_not_active', status: row.token_status }); }
      if (row.token_expires_at && new Date(row.token_expires_at).getTime() <= Date.now()) { await client.query("UPDATE redemption_tokens SET status = 'EXPIRED', updated_at = NOW() WHERE id = $1", [row.token_id]); await client.query('COMMIT'); return res.status(410).json({ error: 'gift_token_expired' }); }
      const fulfillerMerchantId = await getFulfillerMerchantId(client, req.user.userId);
      if (!(await canFulfillGift(client, req.user, row, branchId, fulfillerMerchantId))) { await client.query('ROLLBACK'); return res.status(403).json({ error: 'cashier_not_authorized_for_gift' }); }
      await client.query(`INSERT INTO token_scans (token_id, scanned_by_user_id, status, verification_result, device_metadata) VALUES ($1,$2,'VERIFIED','gift_verified',$3::jsonb)`, [row.token_id, req.user.userId, JSON.stringify((req.body || {}).deviceMetadata || {})]);
      await client.query("UPDATE redemption_tokens SET status = 'VERIFIED', scanned_at = COALESCE(scanned_at, NOW()), verified_at = NOW(), updated_at = NOW() WHERE id = $1", [row.token_id]);
      await client.query("UPDATE gift_claims SET status = 'VERIFIED', verified_at = NOW(), updated_at = NOW() WHERE id = $1", [row.gift_claim_id]);
      await client.query(`INSERT INTO business_events (event_type, aggregate_type, aggregate_id, customer_id, payload) VALUES ('QR_SCANNED', 'redemption_tokens', $1, $2, $3::jsonb)`, [String(row.token_id), row.customer_id, JSON.stringify({ giftClaimId: row.gift_claim_id, scannedBy: req.user.userId })]);
      await client.query('COMMIT');
      return res.json({ ok: true, tokenId: row.token_id, claimId: row.gift_claim_id, customerId: row.customer_id, gift: mapGift(row), status: 'VERIFIED' });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'gift_verify_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/cashier/gifts/redeem', auth, async (req, res) => {
    const body = req.body || {};
    const qrToken = String(body.redemptionToken || body.qrToken || '').trim();
    const branchId = String(body.branchId || '').trim() || null;
    const idempotencyKey = String(body.idempotencyKey || '').trim() || null;
    if (!qrToken) return res.status(400).json({ error: 'redemption_token_required' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      let redemptionRequestId = null;
      if (idempotencyKey) {
        redemptionRequestId = (await client.query(
          'SELECT register_redemption_request($1,$2,$3,$4) AS id',
          [req.user.userId, idempotencyKey, 'GIFT_REDEMPTION', hashToken(qrToken)]
        )).rows[0]?.id || null;
        const existingRequest = (await client.query(
          'SELECT status, response_json FROM redemption_requests WHERE id = $1 FOR UPDATE',
          [redemptionRequestId]
        )).rows[0];
        if (existingRequest?.status === 'COMPLETED' && existingRequest.response_json) {
          await client.query('COMMIT');
          return res.json({ ...existingRequest.response_json, idempotentReplay: true });
        }
      }
      const row = (await client.query(
        `SELECT rt.id AS token_id, rt.gift_claim_id, rt.status AS token_status, rt.expires_at AS token_expires_at,
                gc.customer_id, gc.assignment_id,
                gd.id AS gift_definition_id, gd.gift_type, gd.title, gd.description, gd.image_url,
                gd.value_amount, gd.discount_percentage, gd.terms, gd.pickup_instructions,
                gd.status AS gift_status, gd.starts_at, gd.expires_at AS gift_expires_at,
                gd.source_merchant_id, gd.source_brand_id, gd.source_coalition_id,
                ca.status AS assignment_status
           FROM redemption_tokens rt
           JOIN gift_claims gc ON gc.id = rt.gift_claim_id
           JOIN campaign_assignments ca ON ca.id = gc.assignment_id
           JOIN gift_definitions gd ON gd.id = gc.gift_definition_id
          WHERE rt.token_hash = $1 FOR UPDATE`,
        [hashToken(qrToken)]
      )).rows[0];
      if (!row) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'gift_token_not_found' }); }
      if (row.token_status !== 'VERIFIED') { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_token_not_verified', status: row.token_status }); }
      if (row.token_expires_at && new Date(row.token_expires_at).getTime() <= Date.now()) { await client.query('ROLLBACK'); return res.status(410).json({ error: 'gift_token_expired' }); }
      const fulfillerMerchantId = await getFulfillerMerchantId(client, req.user.userId);
      if (!(await canFulfillGift(client, req.user, row, branchId, fulfillerMerchantId))) { await client.query('ROLLBACK'); return res.status(403).json({ error: 'cashier_not_authorized_for_gift' }); }
      const completed = (await client.query(`SELECT id FROM redemptions WHERE gift_claim_id = $1 AND status = 'COMPLETED' LIMIT 1`, [row.gift_claim_id])).rows[0];
      if (completed) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_already_redeemed', redemptionId: completed.id }); }
      const inventory = (await client.query(
        `SELECT gi.*
           FROM gift_inventory gi
          WHERE gi.gift_definition_id = $1
            AND (
              gi.scope_type = 'GLOBAL'
              OR (gi.scope_type = 'BRANCH' AND gi.branch_id = $2)
              OR (gi.scope_type = 'MERCHANT' AND gi.merchant_id = $3)
              OR (gi.scope_type = 'COALITION_MEMBER' AND gi.merchant_id = $3)
            )
          ORDER BY CASE gi.scope_type
            WHEN 'BRANCH' THEN 1
            WHEN 'MERCHANT' THEN 2
            WHEN 'COALITION_MEMBER' THEN 3
            ELSE 4
          END
          LIMIT 1
          FOR UPDATE`,
        [row.gift_definition_id, branchId, fulfillerMerchantId]
      )).rows[0];
      if (inventory) {
        const inventoryUpdate = await client.query(
          `UPDATE gift_inventory
              SET quantity_redeemed = quantity_redeemed + 1, updated_at = NOW()
            WHERE id = $1 AND quantity_redeemed < quantity_total`,
          [inventory.id]
        );
        if (inventoryUpdate.rowCount !== 1) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_out_of_stock' }); }
      }
      const redemption = (await client.query(
        `INSERT INTO redemptions (token_id, gift_claim_id, redemption_kind, customer_id, fulfilled_by_user_id, fulfiller_merchant_id, request_actor_user_id, idempotency_key, status, completed_at, snapshot_json)
         VALUES ($1,$2,'GIFT',$3,$4,$5,$4,$6,'COMPLETED',NOW(),$7::jsonb) RETURNING id`,
        [row.token_id, row.gift_claim_id, row.customer_id, req.user.userId, fulfillerMerchantId, idempotencyKey, JSON.stringify({ giftDefinitionId: row.gift_definition_id, title: row.title, inventoryId: inventory?.id || null })]
      )).rows[0];
      if (inventory) {
        await client.query(
          `INSERT INTO inventory_adjustments (redemption_id, gift_inventory_id, adjustment_type, quantity_delta, actor_user_id, reason)
           VALUES ($1,$2,'REDEEMED',-1,$3,'gift redeemed')`,
          [redemption.id, inventory.id, req.user.userId]
        );
      }
      await client.query("UPDATE redemption_tokens SET status = 'USED', used_at = NOW(), updated_at = NOW() WHERE id = $1", [row.token_id]);
      await client.query("UPDATE gift_claims SET status = 'REDEEMED', redeemed_at = NOW(), updated_at = NOW() WHERE id = $1", [row.gift_claim_id]);
      await client.query("UPDATE campaign_assignments SET status = 'REDEEMED', redeemed_at = NOW(), updated_at = NOW() WHERE id = $1", [row.assignment_id]);
      const event = (await client.query(
        `INSERT INTO business_events (event_type, aggregate_type, aggregate_id, customer_id, source_merchant_id, source_brand_id, source_coalition_id, redemption_id, payload)
         VALUES ('GIFT_REDEEMED', 'redemptions', $1, $2, $3, $4, $5, $6, $7::jsonb) RETURNING id`,
        [String(redemption.id), row.customer_id, row.source_merchant_id, row.source_brand_id, row.source_coalition_id, redemption.id, JSON.stringify({ giftClaimId: row.gift_claim_id, giftDefinitionId: row.gift_definition_id, fulfilledBy: req.user.userId })]
      )).rows[0];
      await client.query(
        `INSERT INTO audit_logs (actor_user_id, actor_role, entity_type, entity_id, action, previous_state, new_state, reason, request_id, device_metadata)
         VALUES ($1,$2,'gift_claims',$3,'GIFT_REDEEMED',$4::jsonb,$5::jsonb,$6,$7,$8::jsonb)`,
        [req.user.userId, req.user.role || null, String(row.gift_claim_id), JSON.stringify({ status: 'VERIFIED' }), JSON.stringify({ status: 'REDEEMED', redemptionId: redemption.id }), String(body.reason || '').trim() || null, idempotencyKey, JSON.stringify(body.deviceMetadata || {})]
      );
      await insertNotification(client, row.customer_id, 'gift_redeemed', row.title, 'تم استلام هديتك بنجاح.', { giftDefinitionId: row.gift_definition_id, giftClaimId: row.gift_claim_id, redemptionId: redemption.id, businessEventId: event.id, targetScreen: 'gifts_rewards' });
      const responseBody = { ok: true, redemptionId: redemption.id, status: 'COMPLETED' };
      if (redemptionRequestId) {
        await client.query(
          `UPDATE redemption_requests
              SET status = 'COMPLETED', redemption_id = $2, response_json = $3::jsonb, updated_at = NOW()
            WHERE id = $1`,
          [redemptionRequestId, redemption.id, JSON.stringify(responseBody)]
        );
      }
      await client.query('COMMIT');
      return res.json(responseBody);
    } catch (error) {
      await client.query('ROLLBACK');
      if (error?.code === '23505') return res.status(409).json({ error: 'duplicate_gift_redemption' });
      return res.status(500).json({ error: 'gift_redeem_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/cashier/gifts/redemptions/:id/reverse', auth, async (req, res) => {
    const body = req.body || {};
    const reason = String(body.reason || '').trim();
    if (!reason) return res.status(400).json({ error: 'reversal_reason_required' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const redemption = (await client.query(
        `SELECT r.*, gd.source_merchant_id, gd.source_brand_id, gd.source_coalition_id, gd.title
           FROM redemptions r
           JOIN gift_claims gc ON gc.id = r.gift_claim_id
           JOIN gift_definitions gd ON gd.id = gc.gift_definition_id
          WHERE r.id = $1
          FOR UPDATE`,
        [req.params.id]
      )).rows[0];
      if (!redemption || redemption.redemption_kind !== 'GIFT') { await client.query('ROLLBACK'); return res.status(404).json({ error: 'gift_redemption_not_found' }); }
      if (redemption.status !== 'COMPLETED') { await client.query('ROLLBACK'); return res.status(409).json({ error: 'gift_redemption_not_reversible', status: redemption.status }); }
      const actorMerchantId = await getFulfillerMerchantId(client, req.user.userId);
      const allowed = req.user.isSystemOwner || req.user.role === 'admin'
        || redemption.fulfilled_by_user_id === req.user.userId
        || (actorMerchantId && (actorMerchantId === redemption.fulfiller_merchant_id || actorMerchantId === redemption.source_merchant_id));
      if (!allowed) { await client.query('ROLLBACK'); return res.status(403).json({ error: 'gift_reversal_not_authorized' }); }
      const existing = (await client.query('SELECT id FROM reversals WHERE redemption_id = $1 LIMIT 1', [redemption.id])).rows[0];
      if (existing) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'redemption_already_reversed', reversalId: existing.id }); }

      const redeemedInventory = (await client.query(
        `SELECT gift_inventory_id
           FROM inventory_adjustments
          WHERE redemption_id = $1
            AND gift_inventory_id IS NOT NULL
            AND adjustment_type = 'REDEEMED'
          ORDER BY created_at ASC
          LIMIT 1
          FOR UPDATE`,
        [redemption.id]
      )).rows[0];
      let inventoryAdjustmentId = null;
      if (redeemedInventory?.gift_inventory_id) {
        await client.query(
          `UPDATE gift_inventory
              SET quantity_redeemed = GREATEST(quantity_redeemed - 1, 0), updated_at = NOW()
            WHERE id = $1`,
          [redeemedInventory.gift_inventory_id]
        );
        inventoryAdjustmentId = (await client.query(
          `INSERT INTO inventory_adjustments (redemption_id, gift_inventory_id, adjustment_type, quantity_delta, actor_user_id, reason)
           VALUES ($1,$2,'REVERSAL_RESTOCK',1,$3,$4)
           RETURNING id`,
          [redemption.id, redeemedInventory.gift_inventory_id, req.user.userId, reason]
        )).rows[0].id;
      }

      const reversal = (await client.query(
        `INSERT INTO reversals (redemption_id, actor_user_id, reason, status, inventory_adjustment_id)
         VALUES ($1,$2,$3,'APPROVED',$4)
         RETURNING id`,
        [redemption.id, req.user.userId, reason, inventoryAdjustmentId]
      )).rows[0];
      await client.query("UPDATE redemptions SET status = 'REVERSED', updated_at = NOW() WHERE id = $1", [redemption.id]);
      const event = (await client.query(
        `INSERT INTO business_events (event_type, aggregate_type, aggregate_id, customer_id, source_merchant_id, source_brand_id, source_coalition_id, redemption_id, payload)
         VALUES ('REDEMPTION_REVERSED', 'reversals', $1, $2, $3, $4, $5, $6, $7::jsonb)
         RETURNING id`,
        [String(reversal.id), redemption.customer_id, redemption.source_merchant_id, redemption.source_brand_id, redemption.source_coalition_id, redemption.id, JSON.stringify({ reversalId: reversal.id, reason, giftClaimId: redemption.gift_claim_id })]
      )).rows[0];
      await client.query(
        `INSERT INTO audit_logs (actor_user_id, actor_role, entity_type, entity_id, action, previous_state, new_state, reason, request_id, device_metadata)
         VALUES ($1,$2,'redemptions',$3,'GIFT_REDEMPTION_REVERSED',$4::jsonb,$5::jsonb,$6,$7,$8::jsonb)`,
        [req.user.userId, req.user.role || null, String(redemption.id), JSON.stringify({ status: 'COMPLETED' }), JSON.stringify({ status: 'REVERSED', reversalId: reversal.id }), reason, String(body.idempotencyKey || '').trim() || null, JSON.stringify(body.deviceMetadata || {})]
      );
      await insertNotification(client, redemption.customer_id, 'gift_redemption_reversed', redemption.title, 'تم عكس عملية استلام الهدية.', { redemptionId: redemption.id, reversalId: reversal.id, businessEventId: event.id, targetScreen: 'gifts_rewards' });
      await client.query('COMMIT');
      return res.json({ ok: true, reversalId: reversal.id, redemptionId: redemption.id, status: 'REVERSED' });
    } catch (error) {
      await client.query('ROLLBACK');
      if (error?.code === '23505') return res.status(409).json({ error: 'redemption_already_reversed' });
      return res.status(500).json({ error: 'gift_reversal_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });
};