const { createCampaign, launchCampaign, redeemCoupon } = require('../promotion-campaign-service');
const { resolveSegment } = require('../customer-segmentation-service');

module.exports = function registerCampaignRoutes(app, deps) {
  const { pool, auth, getMerchantProfileIdByUser, getBrandProfileIdByUser, insertNotification, toIso } = deps;

  async function resolveSource(req) {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (merchantId) {
      const { rows: [m] } = await pool.query('SELECT business_name FROM merchant_profiles WHERE id = $1', [merchantId]);
      return { sourceType: 'merchant', sourceId: merchantId, sourceName: m?.business_name || 'Merchant' };
    }
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (brandId) {
      const { rows: [b] } = await pool.query('SELECT business_name FROM brand_profiles WHERE id = $1', [brandId]);
      return { sourceType: 'brand', sourceId: brandId, sourceName: b?.business_name || 'Brand' };
    }
    return null;
  }

  app.post('/api/campaigns', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const p = req.body || {};
    const campaignType = String(p.campaignType || '').trim();
    if (!['free_gift', 'early_access_discount', 'raffle'].includes(campaignType)) {
      return res.status(400).json({ error: 'invalid_campaign_type' });
    }
    const startsAt = new Date(p.startsAt);
    const endsAt = new Date(p.endsAt);
    if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime()) || endsAt <= startsAt) {
      return res.status(400).json({ error: 'invalid_validity_window' });
    }
    if (campaignType === 'early_access_discount' && !(Number(p.discountPercentage) > 0)) {
      return res.status(400).json({ error: 'discount_percentage_required' });
    }
    const maxCampaignSpend = Number(p.maxCampaignSpend || 0);
    const estimatedCostPerRecipient = Number(p.estimatedCostPerRecipient || 0);
    if (maxCampaignSpend > 0 && !(estimatedCostPerRecipient > 0)) {
      return res.status(400).json({ error: 'campaign_cost_estimate_required' });
    }
    const partnerMerchantId = String(p.partnerMerchantId || '').trim();
    if (partnerMerchantId && source.sourceType !== 'brand') {
      return res.status(400).json({ error: 'partner_store_only_for_brand_campaign' });
    }
    if (partnerMerchantId) {
      const partner = (await pool.query('SELECT 1 FROM merchant_profiles WHERE id = $1 AND status = \'active\' LIMIT 1', [partnerMerchantId])).rows[0];
      if (!partner) return res.status(404).json({ error: 'partner_store_not_found' });
    }

    const launchMode = ['draft', 'scheduled'].includes(String(p.launchMode || ''))
      ? String(p.launchMode)
      : 'active';
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const campaign = await createCampaign(client, {
        sourceType: source.sourceType,
        sourceId: source.sourceId,
        campaignType,
        title: p.title,
        description: p.description,
        discountPercentage: p.discountPercentage,
        giftDescription: p.giftDescription,
        minInvoiceAmount: p.minInvoiceAmount,
        segmentFilter: p.segmentFilter,
        segmentParams: {
          ...(p.segmentParams || {}),
          ...(partnerMerchantId ? {partnerMerchantId} : {}),
          ...(Number(p.maxRecipients) > 0 ? {maxRecipients: Math.floor(Number(p.maxRecipients))} : {}),
          ...(maxCampaignSpend > 0 ? {maxCampaignSpend, estimatedCostPerRecipient} : {}),
        },
        startsAt,
        endsAt,
        usageLimitPerCustomer: p.usageLimitPerCustomer,
        status: launchMode === 'active' ? 'draft' : launchMode,
      });
      const launch = launchMode === 'active'
        ? await launchCampaign(client, campaign.id, insertNotification, source.sourceName)
        : {segmentSize: 0, dispatched: [], tickets: []};
      await client.query('COMMIT');
      return res.json({
        ok: true,
        campaign: { ...campaign, starts_at: toIso(campaign.starts_at), ends_at: toIso(campaign.ends_at) },
        segmentSize: launch.segmentSize || 0,
        dispatched: launch.dispatched.map((d) => ({ customerId: d.customerId, qrCode: d.qrCode })),
        raffleTickets: (launch.tickets || []).map((t) => ({ customerId: t.customerId, ticketNumber: t.ticketNumber })),
      });
    } catch (e) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'campaign_create_failed', details: String(e.message || e) });
    } finally {
      client.release();
    }
  });

  app.post('/api/campaigns/preview', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const p = req.body || {};
    const segmentParams = {
      ...(p.segmentParams || {}),
      ...(p.partnerMerchantId ? {partnerMerchantId: String(p.partnerMerchantId)} : {}),
      ...(Number(p.maxCampaignSpend) > 0 ? {
        maxCampaignSpend: Number(p.maxCampaignSpend),
        estimatedCostPerRecipient: Number(p.estimatedCostPerRecipient),
      } : {}),
    };
    const client = await pool.connect();
    try {
      const segment = await resolveSegment(client, source.sourceType, source.sourceId, String(p.segmentFilter || 'all'), segmentParams);
      const maxRecipients = Number(p.maxRecipients || 0);
      const maxSpend = Number(p.maxCampaignSpend || 0);
      const costPerRecipient = Number(p.estimatedCostPerRecipient || 0);
      if (maxSpend > 0 && !(costPerRecipient > 0)) return res.status(400).json({error: 'campaign_cost_estimate_required'});
      const limits = [maxRecipients, maxSpend > 0 ? Math.floor(maxSpend / costPerRecipient) : 0]
        .filter((limit) => Number.isInteger(limit) && limit > 0);
      const dispatchSize = limits.length ? Math.min(segment.length, ...limits) : segment.length;
      return res.json({
        ok: true,
        segmentSize: segment.length,
        dispatchSize,
        budgetCap: maxSpend > 0 ? Math.floor(maxSpend / costPerRecipient) : null,
        estimatedSpend: maxSpend > 0 ? Number((dispatchSize * costPerRecipient).toFixed(2)) : null,
        launchable: dispatchSize > 0,
      });
    } finally {
      client.release();
    }
  });

  app.get('/api/campaigns/customers', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const partnerMerchantId = String(req.query.partnerMerchantId || '').trim();
    if (partnerMerchantId && source.sourceType !== 'brand') {
      return res.status(400).json({ error: 'partner_store_only_for_brand_campaign' });
    }
    const query = String(req.query.query || '').trim();
    const limit = Math.max(1, Math.min(100, Number(req.query.limit || 50)));
    const client = await pool.connect();
    try {
      const sourceCustomers = await resolveSegment(client, source.sourceType, source.sourceId, 'all', {
        ...(partnerMerchantId ? {partnerMerchantId} : {}),
      });
      const customerIds = sourceCustomers.map((customer) => customer.customerId);
      if (!customerIds.length) return res.json({ customers: [] });
      const { rows } = await client.query(
        `SELECT id, COALESCE(NULLIF(full_name, ''), email) AS name, email
           FROM users
          WHERE id = ANY($1::text[])
            AND ($2 = '' OR full_name ILIKE '%' || $2 || '%' OR email ILIKE '%' || $2 || '%')
          ORDER BY COALESCE(NULLIF(full_name, ''), email) ASC
          LIMIT $3`,
        [customerIds, query, limit]
      );
      return res.json({ customers: rows.map((row) => ({id: row.id, name: row.name, email: row.email})) });
    } finally {
      client.release();
    }
  });

  app.post('/api/campaigns/:id/launch', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const owned = (await client.query('SELECT id FROM promo_campaigns WHERE id = $1 AND source_type = $2 AND source_id = $3', [req.params.id, source.sourceType, source.sourceId])).rows[0];
      if (!owned) { await client.query('ROLLBACK'); return res.status(404).json({error: 'campaign_not_found'}); }
      const launch = await launchCampaign(client, req.params.id, insertNotification, source.sourceName);
      await client.query('COMMIT');
      return res.json({ok: true, segmentSize: launch.segmentSize || 0});
    } catch (error) {
      await client.query('ROLLBACK');
      const code = String(error.message || error);
      return res.status(code === 'campaign_not_launchable' ? 409 : 500).json({error: code});
    } finally {
      client.release();
    }
  });

  app.patch('/api/campaigns/:id/status', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const status = String((req.body || {}).status || '');
    if (!['paused', 'draft'].includes(status)) return res.status(400).json({error: 'invalid_campaign_status'});
    const row = (await pool.query(
      `UPDATE promo_campaigns SET status = $4, paused_at = CASE WHEN $4 = 'paused' THEN NOW() ELSE paused_at END
        WHERE id = $1 AND source_type = $2 AND source_id = $3 AND status IN ('active','draft','scheduled') RETURNING id, status`,
      [req.params.id, source.sourceType, source.sourceId, status]
    )).rows[0];
    if (!row) return res.status(404).json({error: 'campaign_not_found_or_transition_denied'});
    return res.json({ok: true, campaign: row});
  });

  app.get('/api/campaigns/mine', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const { rows } = await pool.query(
      `SELECT p.*,
              COUNT(c.id)::int AS issued_count,
              COUNT(c.id) FILTER (WHERE c.status = 'redeemed')::int AS redeemed_count
         FROM promo_campaigns p
         LEFT JOIN promo_campaign_coupons c ON c.campaign_id = p.id
        WHERE p.source_type = $1 AND p.source_id = $2
        GROUP BY p.id
        ORDER BY p.created_at DESC`,
      [source.sourceType, source.sourceId]
    );
    return res.json({ campaigns: rows.map((row) => ({...row, conversionRate: Number(row.issued_count || 0) > 0 ? Number((Number(row.redeemed_count || 0) / Number(row.issued_count) * 100).toFixed(2)) : 0})) });
  });

  app.get('/api/customer/campaigns/my-coupons', auth, async (req, res) => {
    const { rows } = await pool.query(`
      SELECT c.id, c.qr_code, c.status, c.issued_at, c.redeemed_at,
             p.title, p.campaign_type, p.discount_percentage, p.gift_description, p.starts_at, p.ends_at
        FROM promo_campaign_coupons c
        JOIN promo_campaigns p ON p.id = c.campaign_id
       WHERE c.customer_id = $1
       ORDER BY c.issued_at DESC
    `, [req.user.userId]);
    return res.json({ coupons: rows });
  });

  app.get('/api/customer/campaigns/my-raffle-tickets', auth, async (req, res) => {
    const { rows } = await pool.query(`
      SELECT t.id, t.ticket_number, t.created_at,
             p.title, p.description, p.starts_at, p.ends_at, p.status
        FROM raffle_tickets t
        JOIN promo_campaigns p ON p.id = t.campaign_id
       WHERE t.customer_id = $1
       ORDER BY t.created_at DESC
    `, [req.user.userId]);
    return res.json({ tickets: rows });
  });

  app.post('/api/merchant/campaigns/redeem', auth, async (req, res) => {
    let merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) {
      merchantId = (await pool.query(
        `SELECT merchant_id
           FROM cashier_profiles
          WHERE user_id = $1 AND is_active = TRUE
          LIMIT 1`,
        [req.user.userId]
      )).rows[0]?.merchant_id;
    }
    if (!merchantId) return res.status(403).json({ error: 'cashier_not_authorized' });
    const qrCode = String((req.body || {}).qrCode || '').trim();
    if (!qrCode) return res.status(400).json({ error: 'qr_code_required' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await redeemCoupon(client, qrCode, merchantId, req.user.userId);
      if (!result.ok) {
        await client.query('ROLLBACK');
        return res.status(result.status).json({ error: result.error });
      }
      await client.query('COMMIT');
      return res.json(result);
    } catch (e) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'coupon_redeem_failed', details: String(e.message || e) });
    } finally {
      client.release();
    }
  });
};
