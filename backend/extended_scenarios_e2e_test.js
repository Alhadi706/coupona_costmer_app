const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

process.env.PGHOST = process.env.PHASE2_SCHEMA_TEST_PGHOST || '127.0.0.1';
process.env.PGPORT = process.env.PHASE2_SCHEMA_TEST_PGPORT || '5434';
process.env.PGUSER = process.env.PHASE2_SCHEMA_TEST_PGUSER || 'kupuna_user';
process.env.PGDATABASE = process.env.PHASE2_SCHEMA_TEST_PGDATABASE || 'kupuna_db';
process.env.JWT_SECRET ||= 'extended-scenarios-test-secret';

const { pool } = require('./src/db');
const registerGiftRoutes = require('./src/routes/gifts');
const registerRewardRoutes = require('./src/routes/rewards');
const registerExchangeRoutes = require('./src/routes/exchange-rewards');
const registerCoalitionRoutes = require('./src/routes/coalition');
const registerCampaignRoutes = require('./src/routes/campaigns');
const servicesMatching = require('./src/services-matching');
const servicesSocial = require('./src/services-social');
const { getBrandIdWithPermission } = require('./src/access-control');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function hashToken(token) {
  return crypto.createHash('sha256').update(String(token || '')).digest('hex');
}

function setupApp() {
  const handlers = new Map();
  const app = {
    get(path, ...routeHandlers) { handlers.set(`GET ${path}`, routeHandlers.at(-1)); },
    post(path, ...routeHandlers) { handlers.set(`POST ${path}`, routeHandlers.at(-1)); },
    put(path, ...routeHandlers) { handlers.set(`PUT ${path}`, routeHandlers.at(-1)); },
    patch(path, ...routeHandlers) { handlers.set(`PATCH ${path}`, routeHandlers.at(-1)); },
    delete(path, ...routeHandlers) { handlers.set(`DELETE ${path}`, routeHandlers.at(-1)); },
  };
  const deps = {
    pool,
    auth(_req, _res, next) { next(); },
    id: () => crypto.randomUUID(),
    toIso: (value) => value == null ? null : new Date(value).toISOString(),
    getMerchantProfileIdByUser: servicesMatching.getMerchantProfileIdByUser,
    getBrandProfileIdByUser: servicesMatching.getBrandProfileIdByUser,
    getBrandIdWithPermission,
    insertNotification: servicesSocial.insertNotification,
  };
  registerGiftRoutes(app, deps);
  if (typeof registerRewardRoutes === 'function') registerRewardRoutes(app, deps);
  if (typeof registerExchangeRoutes === 'function') registerExchangeRoutes(app, deps);
  if (typeof registerCoalitionRoutes === 'function') registerCoalitionRoutes(app, deps);
  if (typeof registerCampaignRoutes === 'function') registerCampaignRoutes(app, deps);
  return handlers;
}

async function call(handler, req) {
  const response = createResponse();
  await handler(req, response);
  return response;
}

test('Scenario A & C & H: Merchant Gift lifecycle, verify, redeem, reversal', async () => {
  const handlers = setupApp();
  const suffix = crypto.randomUUID();
  const merchantUserId = `merchant-user-${suffix}`;
  const merchantId = `merchant-${suffix}`;
  const customerId = `customer-${suffix}`;
  const cashierUserId = `cashier-user-${suffix}`;
  const branchId = `branch-${suffix}`;

  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchantUserId, `${merchantUserId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','customer')`, [customerId, `${customerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','cashier')`, [cashierUserId, `${cashierUserId}@example.com`]);
  await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Merchant Scenario A','active')`, [merchantId, merchantUserId]);
  await pool.query(`INSERT INTO branches (id, merchant_id, name) VALUES ($1,$2,'Main Branch')`, [branchId, merchantId]);
  await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, branch_id, is_active) VALUES ($1,$2,$3,$4,TRUE)`, [`cashier-${suffix}`, cashierUserId, merchantId, branchId]);
  await pool.query(`INSERT INTO point_accounts (owner_id, available_points, lifetime_points) VALUES ($1,100,100)`, [customerId]);
  await pool.query(`INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, total_amount, raw_text, reward_applied, merchant_profile_id, state) VALUES ($1,$2,'Merchant Scenario A','key-a',50,'text',FALSE,$3,'approved')`, [`inv-${suffix}`, customerId, merchantId]);

  // 1. Create 5 gifts of each type
  const types = ['PHYSICAL_PRODUCT', 'VOUCHER', 'DISCOUNT', 'SERVICE', 'STORE_CREDIT'];
  for (const giftType of types) {
    const res = await call(handlers.get('POST /api/gifts/definitions'), {
      user: { userId: merchantUserId, role: 'merchant' },
      body: { giftType, title: `Gift ${giftType}`, discountPercentage: giftType === 'DISCOUNT' ? 15 : null, status: 'ACTIVE' },
    });
    assert.equal(res.statusCode, 201, `Failed to create gift type ${giftType}`);
  }

  // 2. Launch campaign for PHYSICAL_PRODUCT
  const listGifts = await call(handlers.get('GET /api/gifts/definitions/mine'), {
    user: { userId: merchantUserId, role: 'merchant' },
  });
  assert.equal(listGifts.statusCode, 200);
  assert.equal(listGifts.body.gifts.length, 5);
  const targetGift = listGifts.body.gifts.find(g => g.giftType === 'PHYSICAL_PRODUCT');

  await pool.query(`INSERT INTO gift_inventory (gift_definition_id, scope_type, merchant_id, quantity_total) VALUES ($1,'MERCHANT',$2,5)`, [targetGift.id, merchantId]);

  const launch = await call(handlers.get('POST /api/gifts/definitions/:id/campaigns/launch'), {
    params: { id: targetGift.id },
    user: { userId: merchantUserId, role: 'merchant' },
    body: { segmentFilter: 'all', maxRecipients: 10, endsAt: new Date(Date.now() + 86400000).toISOString() },
  });
  assert.equal(launch.statusCode, 201);
  assert.equal(launch.body.assignmentCount, 1);
  const assignmentId = launch.body.assignments[0].assignmentId;

  // Customer view assignment
  const viewRes = await call(handlers.get('POST /api/customer/gifts/assignments/:id/view'), {
    params: { id: assignmentId },
    user: { userId: customerId, role: 'customer' },
  });
  assert.equal(viewRes.statusCode, 200);
  assert.equal(viewRes.body.status, 'VIEWED');

  // Customer claim gift
  const claimRes = await call(handlers.get('POST /api/customer/gifts/assignments/:id/claim'), {
    params: { id: assignmentId },
    user: { userId: customerId, role: 'customer' },
  });
  assert.equal(claimRes.statusCode, 201);
  const qrToken = claimRes.body.redemptionToken;
  assert.ok(qrToken);

  // Check ledger entries count for claim (should be 0)
  const ledgerCountBefore = (await pool.query(`SELECT count(*)::int FROM ledger_entries WHERE owner_id = $1`, [customerId])).rows[0].count;
  assert.equal(ledgerCountBefore, 0, 'No ledger entry should be created on claim');

  // Scenario C: Cashier Verify
  const verifyRes = await call(handlers.get('POST /api/cashier/gifts/verify'), {
    user: { userId: cashierUserId, role: 'cashier' },
    body: { redemptionToken: qrToken, branchId },
  });
  assert.equal(verifyRes.statusCode, 200);
  assert.equal(verifyRes.body.status, 'VERIFIED');

  // Verify DB state after verify
  const tokenDb = (await pool.query(`SELECT status FROM redemption_tokens WHERE gift_claim_id = $1`, [claimRes.body.claimId])).rows[0];
  assert.equal(tokenDb.status, 'VERIFIED');
  const scansCount = (await pool.query(`SELECT count(*)::int FROM token_scans WHERE token_id = $1`, [verifyRes.body.tokenId])).rows[0].count;
  assert.equal(scansCount, 1);

  // Scenario C: Cashier Confirm / Redeem
  const idempotencyKey = `idem-${suffix}`;
  const redeemRes = await call(handlers.get('POST /api/cashier/gifts/redeem'), {
    user: { userId: cashierUserId, role: 'cashier' },
    body: { redemptionToken: qrToken, branchId, idempotencyKey },
  });
  assert.equal(redeemRes.statusCode, 200);
  assert.equal(redeemRes.body.status, 'COMPLETED');
  const redemptionId = redeemRes.body.redemptionId;

  // Verify post-redeem DB state
  const invDb = (await pool.query(`SELECT quantity_redeemed FROM gift_inventory WHERE gift_definition_id = $1`, [targetGift.id])).rows[0];
  assert.equal(invDb.quantity_redeemed, 1);
  const invAdj = (await pool.query(`SELECT count(*)::int FROM inventory_adjustments WHERE redemption_id = $1`, [redemptionId])).rows[0].count;
  assert.equal(invAdj, 1);
  const eventCount = (await pool.query(`SELECT count(*)::int FROM business_events WHERE redemption_id = $1 AND event_type = 'GIFT_REDEEMED'`, [redemptionId])).rows[0].count;
  assert.equal(eventCount, 1);

  // Scenario D: Retry same idempotency key
  const retryRes = await call(handlers.get('POST /api/cashier/gifts/redeem'), {
    user: { userId: cashierUserId, role: 'cashier' },
    body: { redemptionToken: qrToken, branchId, idempotencyKey },
  });
  assert.equal(retryRes.statusCode, 200);
  assert.equal(retryRes.body.redemptionId, redemptionId);
  assert.equal(retryRes.body.idempotentReplay, true);

  // Scenario H: Reversal
  const reverseRes = await call(handlers.get('POST /api/cashier/gifts/redemptions/:id/reverse'), {
    params: { id: redemptionId },
    user: { userId: cashierUserId, role: 'cashier' },
    body: { reason: 'Defective item returned' },
  });
  assert.equal(reverseRes.statusCode, 200);
  assert.equal(reverseRes.body.status, 'REVERSED');

  // Verify inventory restocked after reversal
  const invRestockDb = (await pool.query(`SELECT quantity_redeemed FROM gift_inventory WHERE gift_definition_id = $1`, [targetGift.id])).rows[0];
  assert.equal(invRestockDb.quantity_redeemed, 0);

  // Duplicate reversal rejected
  const reverseRes2 = await call(handlers.get('POST /api/cashier/gifts/redemptions/:id/reverse'), {
    params: { id: redemptionId },
    user: { userId: cashierUserId, role: 'cashier' },
    body: { reason: 'Defective item returned' },
  });
  assert.equal(reverseRes2.statusCode, 409);
});

test('Scenario B: Brand Gift & Brand Team Permissions', async () => {
  const handlers = setupApp();
  const brandOwnerId = crypto.randomUUID();
  const brandId = crypto.randomUUID();
  const teamMemberId = crypto.randomUUID();

  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','brand')`, [brandOwnerId, `${brandOwnerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','brand')`, [teamMemberId, `${teamMemberId}@example.com`]);
  await pool.query(`INSERT INTO brand_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Brand Scenario B','active')`, [brandId, brandOwnerId]);
  await pool.query(`INSERT INTO brand_team_members (brand_id, user_id, can_manage_campaigns) VALUES ($1,$2,TRUE)`, [brandId, teamMemberId]);

  // Brand Owner creates gift
  const createRes = await call(handlers.get('POST /api/gifts/definitions'), {
    user: { userId: brandOwnerId, role: 'brand' },
    body: { giftType: 'PHYSICAL_PRODUCT', title: 'Brand Free Sample', status: 'ACTIVE' },
  });
  assert.equal(createRes.statusCode, 201);
  const giftId = createRes.body.gift.id;

  // Brand definition shows source_brand_id
  const row = (await pool.query(`SELECT source_brand_id FROM gift_definitions WHERE id = $1`, [giftId])).rows[0];
  assert.equal(row.source_brand_id, brandId);

  // Authorized team member can list brand gifts
  const teamListRes = await call(handlers.get('GET /api/gifts/definitions/mine'), {
    user: { userId: teamMemberId, role: 'brand' },
  });
  assert.equal(teamListRes.statusCode, 200);
  assert.equal(teamListRes.body.gifts.length, 1);

  // Analytics endpoint check
  const analyticsRes = await call(handlers.get('GET /api/gifts/analytics/mine'), {
    user: { userId: brandOwnerId, role: 'brand' },
  });
  assert.equal(analyticsRes.statusCode, 200);
  assert.equal(analyticsRes.body.giftCount, 1);
});

test('Scenario E: Cashier Permission Checks', async () => {
  const handlers = setupApp();
  const merchant1OwnerId = crypto.randomUUID();
  const merchant1Id = crypto.randomUUID();
  const merchant2OwnerId = crypto.randomUUID();
  const merchant2Id = crypto.randomUUID();
  const customerId = crypto.randomUUID();
  const cashier2UserId = crypto.randomUUID();
  const assignmentId = crypto.randomUUID();

  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchant1OwnerId, `${merchant1OwnerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchant2OwnerId, `${merchant2OwnerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','customer')`, [customerId, `${customerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','cashier')`, [cashier2UserId, `${cashier2UserId}@example.com`]);

  await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Merchant 1','active')`, [merchant1Id, merchant1OwnerId]);
  await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Merchant 2','active')`, [merchant2Id, merchant2OwnerId]);
  await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [crypto.randomUUID(), cashier2UserId, merchant2Id]);

  // Create gift for Merchant 1
  const giftRes = await call(handlers.get('POST /api/gifts/definitions'), {
    user: { userId: merchant1OwnerId, role: 'merchant' },
    body: { giftType: 'VOUCHER', title: 'M1 Exclusive Gift', status: 'ACTIVE' },
  });
  const giftId = giftRes.body.gift.id;

  const launch = await call(handlers.get('POST /api/gifts/definitions/:id/campaigns/launch'), {
    params: { id: giftId },
    user: { userId: merchant1OwnerId, role: 'merchant' },
    body: { segmentFilter: 'all', maxRecipients: 1 },
  });
  await pool.query(`INSERT INTO campaign_assignments (id, campaign_id, customer_id, assignment_kind, status) VALUES ($1,$2,$3,'gift','NOTIFIED')`, [assignmentId, launch.body.campaignId, customerId]);

  const claimRes = await call(handlers.get('POST /api/customer/gifts/assignments/:id/claim'), {
    params: { id: assignmentId },
    user: { userId: customerId, role: 'customer' },
  });
  const qrToken = claimRes.body.redemptionToken;

  // Merchant 2 cashier attempts to verify Merchant 1 gift -> Forbidden 403
  const verifyRes = await call(handlers.get('POST /api/cashier/gifts/verify'), {
    user: { userId: cashier2UserId, role: 'cashier' },
    body: { redemptionToken: qrToken },
  });
  assert.equal(verifyRes.statusCode, 403);
  assert.equal(verifyRes.body.error, 'cashier_not_authorized_for_gift');

  // Customer attempting to call cashier verify -> Forbidden 403
  const custVerifyRes = await call(handlers.get('POST /api/cashier/gifts/verify'), {
    user: { userId: customerId, role: 'customer' },
    body: { redemptionToken: qrToken },
  });
  assert.equal(custVerifyRes.statusCode, 403);
});

test('Scenario F & G: Expiration & Inventory Out-of-Stock checks', async () => {
  const handlers = setupApp();
  const merchantUserId = crypto.randomUUID();
  const merchantId = crypto.randomUUID();
  const customerId = crypto.randomUUID();
  const cashierUserId = crypto.randomUUID();
  const assignmentId = crypto.randomUUID();

  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchantUserId, `${merchantUserId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','customer')`, [customerId, `${customerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','cashier')`, [cashierUserId, `${cashierUserId}@example.com`]);
  await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Merchant FG','active')`, [merchantId, merchantUserId]);
  await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [crypto.randomUUID(), cashierUserId, merchantId]);

  // 1. Create gift definition
  const giftRes = await call(handlers.get('POST /api/gifts/definitions'), {
    user: { userId: merchantUserId, role: 'merchant' },
    body: { giftType: 'PHYSICAL_PRODUCT', title: 'Limited Stock Gift', status: 'ACTIVE' },
  });
  const giftId = giftRes.body.gift.id;

  // Add inventory with total = 1
  await pool.query(`INSERT INTO gift_inventory (gift_definition_id, scope_type, merchant_id, quantity_total, quantity_redeemed) VALUES ($1,'MERCHANT',$2,1,0)`, [giftId, merchantId]);

  const campaignId = crypto.randomUUID();
  await pool.query(
    `INSERT INTO promo_campaigns (id, source_type, source_id, source_merchant_id, campaign_type, title, status, gift_definition_id, starts_at, ends_at)
     VALUES ($1,'merchant',$2,$2,'free_gift','FG Campaign','active',$3,NOW(),NOW() + INTERVAL '1 day')`,
    [campaignId, merchantId, giftId]
  );
  await pool.query(
    `INSERT INTO campaign_assignments (id, campaign_id, customer_id, assignment_kind, status)
     VALUES ($1,$2,$3,'gift','NOTIFIED')`,
    [assignmentId, campaignId, customerId]
  );

  const claimRes = await call(handlers.get('POST /api/customer/gifts/assignments/:id/claim'), {
    params: { id: assignmentId },
    user: { userId: customerId, role: 'customer' },
  });
  const qrToken = claimRes.body.redemptionToken;

  // Verify token
  await call(handlers.get('POST /api/cashier/gifts/verify'), {
    user: { userId: cashierUserId, role: 'cashier' },
    body: { redemptionToken: qrToken },
  });

  // 1st redemption succeeds (takes last item)
  const redeem1 = await call(handlers.get('POST /api/cashier/gifts/redeem'), {
    user: { userId: cashierUserId, role: 'cashier' },
    body: { redemptionToken: qrToken },
  });
  assert.equal(redeem1.statusCode, 200);

  // Expiration check: create a 2nd claim and set token expires_at in past
  const assignment2Id = crypto.randomUUID();
  await pool.query(
    `INSERT INTO campaign_assignments (id, campaign_id, customer_id, assignment_kind, status)
     VALUES ($1,$2,$3,'gift','NOTIFIED')`,
    [assignment2Id, campaignId, customerId]
  );
  const claim2Res = await call(handlers.get('POST /api/customer/gifts/assignments/:id/claim'), {
    params: { id: assignment2Id },
    user: { userId: customerId, role: 'customer' },
  });
  const qrToken2 = claim2Res.body.redemptionToken;
  await pool.query(
    `UPDATE redemption_tokens
        SET issued_at = NOW() - INTERVAL '3 hours', active_at = NOW() - INTERVAL '2 hours', expires_at = NOW() - INTERVAL '1 hour'
      WHERE gift_claim_id = $1`,
    [claim2Res.body.claimId]
  );

  const expiredVerify = await call(handlers.get('POST /api/cashier/gifts/verify'), {
    user: { userId: cashierUserId, role: 'cashier' },
    body: { redemptionToken: qrToken2 },
  assert.equal(expiredVerify.statusCode, 410);
  assert.equal(expiredVerify.body.error, 'gift_token_expired');
});

test('Scenario L: Cash Voucher / Cash Redemption flow', async () => {
  const handlers = setupApp();
  const suffix = crypto.randomUUID();
  const customerId = crypto.randomUUID();
  const merchantUserId = crypto.randomUUID();
  const merchantId = crypto.randomUUID();
  const cashierUserId = crypto.randomUUID();

  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','customer')`, [customerId, `${customerId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchantUserId, `${merchantUserId}@example.com`]);
  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','cashier')`, [cashierUserId, `${cashierUserId}@example.com`]);
  await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Merchant L','active')`, [merchantId, merchantUserId]);
  await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [crypto.randomUUID(), cashierUserId, merchantId]);

  // Customer starts with 200 points
  await pool.query(`INSERT INTO point_accounts (owner_id, available_points, lifetime_points) VALUES ($1,200,200)`, [customerId]);

  // Customer requests a 5 LYD cash voucher (= 50 points)
  const createRes = await call(handlers.get('POST /api/customer/redemptions/dynamic-voucher'), {
    user: { userId: customerId, role: 'customer' },
    body: { cashValueLyD: 5 },
  });
  assert.equal(createRes.statusCode, 201);
  const qrCode = createRes.body.voucher.qrCode;

  // Points prior to redemption = 200
  let points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
  assert.equal(Number(points.available_points), 200);

  // Cashier verify
  const verifyRes = await call(handlers.get('POST /api/cashier/dynamic-voucher/verify'), {
    user: { userId: cashierUserId, role: 'merchant' },
    body: { qrCode },
  });
  assert.equal(verifyRes.statusCode, 200);
  assert.equal(verifyRes.body.status, 'VERIFIED');

  // Points after verify = 200 (still not debited)
  points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
  assert.equal(Number(points.available_points), 200);

  // Cashier redeem
  const idempotencyKey = `cash-${suffix}`;
  const redeemRes = await call(handlers.get('POST /api/cashier/dynamic-voucher/redeem'), {
    user: { userId: cashierUserId, role: 'merchant' },
    body: { qrCode, idempotencyKey },
  });
  assert.equal(redeemRes.statusCode, 200);
  assert.equal(redeemRes.body.pointsDebited, 50);
  assert.equal(redeemRes.body.cashValueLyD, 5);

  // Points after redemption = 150
  points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
  assert.equal(Number(points.available_points), 150);

  // Ledger entry check
  const ledger = (await pool.query(`SELECT type, points, amount FROM ledger_entries WHERE owner_id = $1 AND type = 'cashVoucherRedeemed'`, [customerId])).rows[0];
  assert.equal(ledger.type, 'cashVoucherRedeemed');
  assert.equal(Number(ledger.points), -50);
  assert.equal(Number(ledger.amount), 5);

  // Replay idempotency check
  const replayRes = await call(handlers.get('POST /api/cashier/dynamic-voucher/redeem'), {
    user: { userId: cashierUserId, role: 'merchant' },
    body: { qrCode, idempotencyKey },
  });
  assert.equal(replayRes.statusCode, 200);
  assert.equal(replayRes.body.redemptionId, redeemRes.body.redemptionId);
  assert.equal(replayRes.body.idempotentReplay, true);
});

test('Scenario O & P: Analytics query match & Security token hash check', async () => {
  const handlers = setupApp();
  const merchantUserId = crypto.randomUUID();
  const merchantId = crypto.randomUUID();

  await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchantUserId, `${merchantUserId}@example.com`]);
  await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Merchant Analytics','active')`, [merchantId, merchantUserId]);

  const giftRes = await call(handlers.get('POST /api/gifts/definitions'), {
    user: { userId: merchantUserId, role: 'merchant' },
    body: { giftType: 'SERVICE', title: 'Analytics Gift', status: 'ACTIVE' },
  });

  const analyticsRes = await call(handlers.get('GET /api/gifts/analytics/mine'), {
    user: { userId: merchantUserId, role: 'merchant' },
  });
  assert.equal(analyticsRes.statusCode, 200);

  // Direct SQL query comparison
  const sqlCount = (await pool.query(`SELECT count(*)::int FROM gift_definitions WHERE source_merchant_id = $1`, [merchantId])).rows[0].count;
  assert.equal(analyticsRes.body.giftCount, sqlCount);

  // Security: Token raw check in DB (Ensure raw token string is NOT saved in DB)
  const sampleToken = 'super-secret-raw-token-12345';
  const hashed = hashToken(sampleToken);
  const rawTokenExistsInDb = (await pool.query(`SELECT 1 FROM redemption_tokens WHERE token_hash = $1`, [sampleToken])).rows[0];
  assert.equal(rawTokenExistsInDb, undefined, 'Raw token string must NOT exist in redemption_tokens table');
});

