const crypto = require('crypto');

function generateQrCode() {
  return crypto.randomUUID().replace(/-/g, '');
}

function formatValidityWindow(startsAt, endsAt) {
  const fmt = (d) => new Date(d).toISOString().slice(0, 10);
  return `${fmt(startsAt)} - ${fmt(endsAt)}`;
}

function buildCampaignMessage(campaign, sourceName) {
  const customMessage = String(campaign.description || '').trim();
  const noPurchaseDisclosure = 'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك أو نشاطك المكتسب من مشترياتك العادية.';
  if (customMessage) {
    return campaign.campaign_type === 'raffle' && !customMessage.includes('لا حاجة لأي شراء إضافي')
      ? `${customMessage} ${noPurchaseDisclosure}`
      : customMessage;
  }
  const window = formatValidityWindow(campaign.starts_at, campaign.ends_at);
  if (campaign.campaign_type === 'early_access_discount') {
    return `أهلاً بك! بصفتك زبوناً مميزاً لدى ${sourceName}، يمكنك التسوق بخصم ${Number(campaign.discount_percentage)}% خلال الفترة ${window} قبل فتح التخفيض للجمهور.`;
  }
  if (campaign.campaign_type === 'free_gift') {
    return `شتقنالك! امسح كوبون الـ QR المرفق عند الكاشير في ${sourceName} واحصل على هديتك المجانية: ${campaign.gift_description || ''} (صالح حتى ${new Date(campaign.ends_at).toISOString().slice(0, 10)}).`;
  }
  return `تهانينا! أنت مؤهل للانضمام إلى سحب ${sourceName}: ${campaign.title}. ${noPurchaseDisclosure}`;
}

// Issues a single-use QR coupon + in-app notification to every customer in the resolved segment.
async function dispatchCampaignToSegment(client, campaign, customerIds, insertNotification, sourceName) {
  const dispatched = [];
  for (const customerId of customerIds) {
    const qrCode = generateQrCode();
    const couponId = require('./helpers').id();
    await client.query(`
      INSERT INTO promo_campaign_coupons (id, campaign_id, customer_id, qr_code, status)
      VALUES ($1, $2, $3, $4, 'issued')
    `, [couponId, campaign.id, customerId, qrCode]);

    const message = buildCampaignMessage(campaign, sourceName);
    if (insertNotification) {
      await insertNotification(client, customerId, 'promo_campaign', campaign.title, message, {
        campaignId: campaign.id,
        campaignType: campaign.campaign_type,
        qrCode,
        startsAt: campaign.starts_at,
        endsAt: campaign.ends_at,
      });
    }
    dispatched.push({ customerId, couponId, qrCode });
  }
  return dispatched;
}

module.exports = { generateQrCode, buildCampaignMessage, dispatchCampaignToSegment };
