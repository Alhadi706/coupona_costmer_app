const { id } = require('./helpers');
const { resolveSegment } = require('./customer-segmentation-service');
const { dispatchCampaignToSegment } = require('./targeted-dispatch-service');

async function createCampaign(client, params) {
  const campaignId = id();
  await client.query(`
    INSERT INTO promo_campaigns (
      id, source_type, source_id, campaign_type, title, description,
      discount_percentage, gift_description, min_invoice_amount,
      segment_filter, segment_params, starts_at, ends_at, usage_limit_per_customer
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12,$13,$14)
  `, [
    campaignId, params.sourceType, params.sourceId, params.campaignType, params.title, params.description || null,
    params.discountPercentage || null, params.giftDescription || null, params.minInvoiceAmount || 0,
    params.segmentFilter || 'all', JSON.stringify(params.segmentParams || {}),
    params.startsAt, params.endsAt, params.usageLimitPerCustomer || 1,
  ]);
  const { rows: [campaign] } = await client.query('SELECT * FROM promo_campaigns WHERE id = $1', [campaignId]);
  return campaign;
}

// Resolves the target segment and dispatches QR coupons + notifications in one atomic step.
async function launchCampaign(client, campaignId, insertNotification, sourceName) {
  const { rows: [campaign] } = await client.query('SELECT * FROM promo_campaigns WHERE id = $1 FOR UPDATE', [campaignId]);
  if (!campaign) throw new Error('campaign_not_found');
  const segment = await resolveSegment(client, campaign.source_type, campaign.source_id, campaign.segment_filter, campaign.segment_params);
  const customerIds = segment.map((s) => s.customerId);
  if (campaign.campaign_type === 'raffle') {
    const tickets = await issueRaffleTicketsForCustomers(client, campaign, customerIds, insertNotification, sourceName);
    return { campaign, dispatched: [], tickets, segmentSize: customerIds.length, note: 'raffle_tickets_issued_from_historical_eligibility' };
  }
  const dispatched = await dispatchCampaignToSegment(client, campaign, customerIds, insertNotification, sourceName);
  return { campaign, dispatched, segmentSize: customerIds.length };
}

async function redeemCoupon(client, qrCode, cashierMerchantId, redeemedByUserId) {
  const { rows: [coupon] } = await client.query(
    'SELECT * FROM promo_campaign_coupons WHERE qr_code = $1 FOR UPDATE',
    [qrCode]
  );
  if (!coupon) return { ok: false, status: 404, error: 'coupon_not_found' };
  if (coupon.status !== 'issued') return { ok: false, status: 409, error: 'coupon_already_used' };

  const { rows: [campaign] } = await client.query('SELECT * FROM promo_campaigns WHERE id = $1', [coupon.campaign_id]);
  if (!campaign) return { ok: false, status: 404, error: 'campaign_not_found' };
  if (campaign.source_type === 'merchant' && cashierMerchantId && campaign.source_id !== cashierMerchantId) {
    return { ok: false, status: 403, error: 'coupon_not_valid_for_this_store' };
  }
  const now = new Date();
  if (now < new Date(campaign.starts_at) || now > new Date(campaign.ends_at)) {
    await client.query(`UPDATE promo_campaign_coupons SET status = 'expired' WHERE id = $1`, [coupon.id]);
    return { ok: false, status: 410, error: 'coupon_expired' };
  }

  await client.query(`
    UPDATE promo_campaign_coupons
       SET status = 'redeemed', redeemed_at = NOW(), redeemed_by = $2
     WHERE id = $1
  `, [coupon.id, redeemedByUserId || null]);

  return {
    ok: true,
    campaignType: campaign.campaign_type,
    discountPercentage: campaign.discount_percentage,
    giftDescription: campaign.gift_description,
    customerId: coupon.customer_id,
  };
}

async function issueRaffleTicketsForCustomers(client, campaign, customerIds, insertNotification, sourceName) {
  const tickets = [];
  for (const customerId of customerIds) {
    const { rows: [{ c: existingCount }] } = await client.query(
      'SELECT COUNT(*)::int AS c FROM raffle_tickets WHERE campaign_id = $1',
      [campaign.id]
    );
    const ticketNumber = `${campaign.id.slice(-6).toUpperCase()}-${String(existingCount + 1).padStart(6, '0')}`;
    const ticketId = id();
    await client.query(
      'INSERT INTO raffle_tickets (id, campaign_id, customer_id, invoice_id, ticket_number) VALUES ($1,$2,$3,NULL,$4)',
      [ticketId, campaign.id, customerId, ticketNumber]
    );
    if (insertNotification) {
      await insertNotification(client, customerId, 'promo_raffle_ticket', campaign.title,
        `تهانينا! حصلت على تذكرة رقمية للسحب لدى ${sourceName}. لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك أو نشاطك المكتسب من مشترياتك العادية.`,
        { campaignId: campaign.id, ticketId, ticketNumber });
    }
    tickets.push({ customerId, ticketId, ticketNumber });
  }
  return tickets;
}

// Retained for compatibility; new raffle entries are issued only from historical eligibility at campaign launch.
async function issueRaffleTicketsForInvoice(client, sourceType, sourceId, customerId, invoiceId, invoiceAmount) {
  return [];
}

module.exports = { createCampaign, launchCampaign, redeemCoupon, issueRaffleTicketsForCustomers, issueRaffleTicketsForInvoice };
