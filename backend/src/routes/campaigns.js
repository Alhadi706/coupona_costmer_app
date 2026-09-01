const { createCampaign, launchCampaign, redeemCoupon } = require('../promotion-campaign-service');

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
        segmentParams: p.segmentParams,
        startsAt,
        endsAt,
        usageLimitPerCustomer: p.usageLimitPerCustomer,
      });
      const launch = await launchCampaign(client, campaign.id, insertNotification, source.sourceName);
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

  app.get('/api/campaigns/mine', auth, async (req, res) => {
    const source = await resolveSource(req);
    if (!source) return res.status(403).json({ error: 'merchant_or_brand_profile_required' });
    const { rows } = await pool.query(
      'SELECT * FROM promo_campaigns WHERE source_type = $1 AND source_id = $2 ORDER BY created_at DESC',
      [source.sourceType, source.sourceId]
    );
    return res.json({ campaigns: rows });
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
