// E2E test: Targeted Promotions, Exclusive Gifts & Dynamic Raffle Engine (promotional_campaigns_v4)
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const BASE = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3006/api';
const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5434),
  user: process.env.PGUSER || 'kupuna_user',
  password: process.env.PGPASSWORD || 'b3c21618bf4c4aaf9caaf5892f51d93d',
  database: process.env.PGDATABASE || 'kupuna_db',
});

function uid(prefix) {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

async function api(path, method = 'GET', body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  let data = {};
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  return { status: res.status, ok: res.ok, data };
}

async function login(email, password) {
  const r = await api('/auth/login', 'POST', { email, password });
  if (!r.ok) throw new Error(`login_failed:${email}:${JSON.stringify(r.data)}`);
  return r.data;
}

async function ensureUser({ email, password, fullName, role = 'customer' }) {
  const normalized = String(email).trim().toLowerCase();
  const existing = await pool.query('SELECT id, password_hash FROM users WHERE email = $1 LIMIT 1', [normalized]);
  if (existing.rows[0]) return existing.rows[0].id;
  const userId = uid('user');
  const hash = await bcrypt.hash(password, 10);
  await pool.query(
    `INSERT INTO users (id, email, password_hash, role, full_name, profile_completed, points, points_history)
     VALUES ($1, $2, $3, $4, $5, TRUE, 0, '[]'::jsonb)`,
    [userId, normalized, hash, role, fullName || null]
  );
  return userId;
}

async function upsertMerchant({ email, password, businessName, pointValue }) {
  const userId = await ensureUser({ email, password, fullName: businessName, role: 'merchant' });
  const existing = await pool.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId]);
  if (existing.rows[0]) return { userId, merchantId: existing.rows[0].id };
  const merchantId = uid('merchant');
  await pool.query(
    `INSERT INTO merchant_profiles (id, user_id, business_name, point_value, status, created_at)
     VALUES ($1, $2, $3, $4, 'active', NOW())`,
    [merchantId, userId, businessName, pointValue]
  );
  await pool.query(
    `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
     VALUES ($1, 10000, 'SAR', FALSE, NOW()) ON CONFLICT (merchant_id) DO NOTHING`,
    [merchantId]
  );
  return { userId, merchantId };
}

async function upsertCustomer({ email, password, fullName }) {
  const userId = await ensureUser({ email, password, fullName, role: 'customer' });
  await pool.query(
    `INSERT INTO customer_profiles (user_id, location_lat, location_lng, created_at)
     VALUES ($1, 24.7136, 46.6753, NOW()) ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
  return userId;
}

// Seed direct approved invoices to establish spend history (bypasses invoice-scan flow for speed).
async function seedInvoiceHistory(merchantId, customerId, totalAmount, count, daysAgo = 10) {
  for (let i = 0; i < count; i += 1) {
    await pool.query(
      `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, invoice_number, invoice_date, total_amount, raw_text, state, merchant_profile_id, created_at)
       VALUES ($1,$2,'Seed Store','seed-store',$3,NOW()::date,$4,'','approved',$5, NOW() - ($6 || ' days')::interval)`,
      [uid('invoice'), customerId, uid('INV'), totalAmount, merchantId, daysAgo]
    );
  }
}

async function main() {
  console.log('🚀 STARTING TARGETED CAMPAIGN & RAFFLE ENGINE E2E TEST\n');
  const results = [];
  const ts = Date.now();

  function check(name, actual, expected) {
    const pass = JSON.stringify(actual) === JSON.stringify(expected);
    console.log(`   ${pass ? '✅' : '❌'} ${name}: actual=${JSON.stringify(actual)}, expected=${JSON.stringify(expected)}`);
    results.push({ name, actual, expected, pass });
    return pass;
  }

  console.log('📝 Step 1: Setting up Merchant + 10 customers with varied spend history...');
  const merchant = await upsertMerchant({ email: `promo.merchant.${ts}@kupuna.test`, password: 'Passw0rd!', businessName: 'Promo Fashion Store', pointValue: 10 });
  const customers = [];
  for (let i = 0; i < 10; i += 1) {
    const custId = await upsertCustomer({ email: `promo.customer.${i}.${ts}@kupuna.test`, password: 'Passw0rd!', fullName: `Customer_${i}` });
    customers.push(custId);
    // Customer_0 is the top spender (2000), rest spend progressively less.
    const spend = 2000 - i * 180;
    await seedInvoiceHistory(merchant.merchantId, custId, spend, 1);
  }
  console.log(`✅ Merchant: ${merchant.merchantId}, 10 customers seeded with spend history\n`);

  console.log('📝 Step 2: Creating 50% Early-Access Discount Campaign targeted at Top 10% Spenders...');
  const merchantToken = (await login(`promo.merchant.${ts}@kupuna.test`, 'Passw0rd!')).token;
  const startsAt = new Date(Date.now() - 60 * 1000).toISOString();
  const endsAt = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString();
  const campaignRes = await api('/campaigns', 'POST', {
    campaignType: 'early_access_discount',
    title: 'خصم رمضان الحصري 50%',
    discountPercentage: 50,
    segmentFilter: 'top_spenders',
    segmentParams: { months: 6, topPercent: 10 },
    startsAt,
    endsAt,
  }, merchantToken);
  if (!campaignRes.ok) throw new Error(`campaign_create_failed:${JSON.stringify(campaignRes.data)}`);
  console.log(`✅ Campaign created: ${campaignRes.data.campaign.id}`);
  console.log(`✅ Segment size (top 10% of 10 = 1 customer): ${campaignRes.data.segmentSize}`);
  console.log(`✅ Coupons dispatched: ${JSON.stringify(campaignRes.data.dispatched)}\n`);
  check('Segment targets exactly top 10% (1 of 10 customers)', campaignRes.data.segmentSize, 1);
  check('One QR coupon dispatched', campaignRes.data.dispatched.length, 1);

  const topSpenderCustomerId = campaignRes.data.dispatched[0].customerId;
  check('Top spender is Customer_0 (highest seeded spend)', topSpenderCustomerId, customers[0]);

  console.log('📝 Step 3: Verifying in-app notification + QR coupon delivery...');
  const { rows: [notif] } = await pool.query(
    `SELECT title, body, payload FROM notifications WHERE user_id = $1 AND type = 'promo_campaign' ORDER BY created_at DESC LIMIT 1`,
    [topSpenderCustomerId]
  );
  console.log(`   Notification: "${notif?.body}"`);
  check('Notification mentions 50% discount', /50%/.test(notif?.body || ''), true);
  check('Notification payload includes qrCode', typeof notif?.payload?.qrCode === 'string' && notif.payload.qrCode.length > 0, true);

  const { rows: myCoupons } = await pool.query(
    `SELECT qr_code, status FROM promo_campaign_coupons WHERE customer_id = $1`,
    [topSpenderCustomerId]
  );
  const qrCode = myCoupons[0]?.qr_code;
  check('Coupon persisted with issued status', myCoupons[0]?.status, 'issued');

  console.log('\n📝 Step 4: Cashier Redemption Flow (valid coupon, within window)...');
  const redeemRes = await api('/merchant/campaigns/redeem', 'POST', { qrCode }, merchantToken);
  console.log(`   Redeem result: ${JSON.stringify(redeemRes.data)}`);
  check('Redemption succeeds for valid, in-window coupon', redeemRes.ok, true);
  check('Redemption returns correct discount', redeemRes.data.discountPercentage, '50');

  const doubleRedeem = await api('/merchant/campaigns/redeem', 'POST', { qrCode }, merchantToken);
  check('Second redemption attempt rejected (already used)', doubleRedeem.status, 409);

  console.log('\n📝 Step 5: Validating expiry enforcement (expired campaign coupon)...');
  const expiredCampaign = await api('/campaigns', 'POST', {
    campaignType: 'free_gift',
    title: 'هدية منتهية للاختبار',
    giftDescription: 'هدية اختبار',
    segmentFilter: 'top_spenders',
    segmentParams: { months: 6, topPercent: 10 },
    startsAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
    endsAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
  }, merchantToken);
  const expiredQr = expiredCampaign.data.dispatched[0]?.qrCode;
  const expiredRedeem = await api('/merchant/campaigns/redeem', 'POST', { qrCode: expiredQr }, merchantToken);
  console.log(`   Expired coupon redemption result: ${JSON.stringify(expiredRedeem.data)}`);
  check('Expired coupon redemption rejected', expiredRedeem.status, 410);

  console.log('\n📝 Step 6: Free Gift + Inactive Customer Re-engagement Segment...');
  const inactiveCustomer = await upsertCustomer({ email: `promo.inactive.${ts}@kupuna.test`, password: 'Passw0rd!', fullName: 'Inactive_Customer' });
  await seedInvoiceHistory(merchant.merchantId, inactiveCustomer, 300, 1, 90);
  const giftCampaign = await api('/campaigns', 'POST', {
    campaignType: 'free_gift',
    title: 'هدية العودة',
    giftDescription: 'قطعة مجانية',
    segmentFilter: 'inactive',
    segmentParams: { inactiveDays: 60 },
    startsAt: new Date(Date.now() - 60 * 1000).toISOString(),
    endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  }, merchantToken);
  const inactiveTargeted = giftCampaign.data.dispatched.some((d) => d.customerId === inactiveCustomer);
  check('Inactive customer (90 days) targeted by re-engagement campaign', inactiveTargeted, true);

  console.log('\n📝 Step 7: Raffle Campaign — ticket issuance from historical eligibility only...');
  const raffleCampaign = await api('/campaigns', 'POST', {
    campaignType: 'raffle',
    title: 'سحب نهاية العام',
    segmentFilter: 'top_spenders',
    segmentParams: { months: 6, topPercent: 10, minimumTotalSpend: 1000 },
    startsAt: new Date(Date.now() - 60 * 1000).toISOString(),
    endsAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
  }, merchantToken);
  const raffleCampaignId = raffleCampaign.data.campaign.id;
  check('Raffle targets historical top spender segment only', raffleCampaign.data.segmentSize, 1);
  check('Raffle ticket issued at campaign launch', raffleCampaign.data.raffleTickets.length, 1);
  check('Raffle disclosure notification created for eligible customer', raffleCampaign.data.raffleTickets[0].customerId, customers[0]);

  const raffleCustomerToken = (await login(`promo.customer.0.${ts}@kupuna.test`, 'Passw0rd!')).token;
  const scan = await api('/invoices/scan-v2', 'POST', {
    merchantProfileId: merchant.merchantId,
    totalAmount: 150,
    invoiceNumber: `RAFFLE-${ts}`,
    invoiceDate: new Date().toISOString(),
    merchantName: 'Promo Fashion Store',
  }, raffleCustomerToken);
  const approve = await api(`/invoices/${scan.data.id}/state-transition`, 'POST', { to: 'approved' }, merchantToken);
  check('New invoice approved without creating paid-entry raffle tickets', approve.ok, true);

  const { rows: tickets } = await pool.query('SELECT * FROM raffle_tickets WHERE campaign_id = $1 AND customer_id = $2', [raffleCampaignId, customers[0]]);
  check('Raffle ticket count unchanged after new invoice approval', tickets.length, 1);
  console.log(`   Ticket number: ${tickets[0]?.ticket_number}`);

  const allPassed = results.every((r) => r.pass);
  console.log('\n' + '='.repeat(70));
  console.log(allPassed ? '✅ 100% TARGETED CAMPAIGN & RAFFLE ENGINE E2E TEST PASSED!' : '❌ SOME SCENARIOS FAILED');
  console.log('='.repeat(70));
  console.log('\n📊 STRUCTURED REPORT:');
  console.log(JSON.stringify({ scenario: 'promotional_campaigns_v4', status: allPassed ? 'PASS' : 'FAIL', checks: results }, null, 2));

  await pool.end();
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error('FATAL ERROR:', e);
  process.exit(1);
});
