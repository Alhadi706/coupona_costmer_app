const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

process.env.PGHOST = process.env.PHASE2_SCHEMA_TEST_PGHOST || '127.0.0.1';
process.env.PGPORT = process.env.PHASE2_SCHEMA_TEST_PGPORT || '5434';
process.env.PGUSER = process.env.PHASE2_SCHEMA_TEST_PGUSER || 'kupuna_user';
process.env.PGDATABASE = process.env.PHASE2_SCHEMA_TEST_PGDATABASE || 'kupuna_db';
process.env.JWT_SECRET ||= 'gift-flow-e2e-test-secret';

const { pool } = require('./src/db');
const registerGiftRoutes = require('./src/routes/gifts');
const servicesMatching = require('./src/services-matching');
const servicesSocial = require('./src/services-social');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function createGiftHandlers() {
  const handlers = new Map();
  const app = {
    get(path, ...routeHandlers) { handlers.set(`GET ${path}`, routeHandlers.at(-1)); },
    post(path, ...routeHandlers) { handlers.set(`POST ${path}`, routeHandlers.at(-1)); },
  };
  registerGiftRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    id: () => crypto.randomUUID(),
    toIso: (value) => value == null ? null : new Date(value).toISOString(),
    getMerchantProfileIdByUser: servicesMatching.getMerchantProfileIdByUser,
    getBrandProfileIdByUser: servicesMatching.getBrandProfileIdByUser,
    getBrandIdWithPermission: async () => null,
    insertNotification: servicesSocial.insertNotification,
  });
  return handlers;
}

async function call(handler, req) {
  const response = createResponse();
  await handler(req, response);
  return response;
}

test('gift flow creates assignment claim token and redemption without points debit', async (testContext) => {
  const suffix = crypto.randomUUID();
  const merchantUserId = `merchant-user-${suffix}`;
  const merchantId = `merchant-${suffix}`;
  const customerId = `customer-${suffix}`;
  const cashierUserId = `cashier-user-${suffix}`;
  const cashierProfileId = `cashier-${suffix}`;
  const invoiceId = `invoice-${suffix}`;
  const handlers = createGiftHandlers();

  try {
    await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchantUserId, `${merchantUserId}@example.com`]);
    await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','customer')`, [customerId, `${customerId}@example.com`]);
    await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [cashierUserId, `${cashierUserId}@example.com`]);
    await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Phase 2 Merchant','active')`, [merchantId, merchantUserId]);
    await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [cashierProfileId, cashierUserId, merchantId]);
    await pool.query(`INSERT INTO point_accounts (owner_id, available_points, lifetime_points) VALUES ($1,123,123)`, [customerId]);
    await pool.query(
      `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, total_amount, raw_text, reward_applied, merchant_profile_id, state)
       VALUES ($1,$2,'Phase 2 Merchant','phase-2-merchant',10,'test',FALSE,$3,'approved')`,
      [invoiceId, customerId, merchantId]
    );

    const createGift = await call(handlers.get('POST /api/gifts/definitions'), {
      user: { userId: merchantUserId, role: 'merchant' },
      body: { giftType: 'VOUCHER', title: 'E2E Free Gift', description: 'No points gift', status: 'ACTIVE' },
    });
    assert.equal(createGift.statusCode, 201);
    const giftId = createGift.body.gift.id;
    await pool.query(
      `INSERT INTO gift_inventory (gift_definition_id, scope_type, quantity_total)
       VALUES ($1,'GLOBAL',1)`,
      [giftId]
    );

    const launch = await call(handlers.get('POST /api/gifts/definitions/:id/campaigns/launch'), {
      params: { id: giftId },
      user: { userId: merchantUserId, role: 'merchant' },
      body: { segmentFilter: 'all', maxRecipients: 1, endsAt: new Date(Date.now() + 86400000).toISOString() },
    });
    assert.equal(launch.statusCode, 201);
    assert.equal(launch.body.assignmentCount, 1);
    const assignmentId = launch.body.assignments[0].assignmentId;

    const claim = await call(handlers.get('POST /api/customer/gifts/assignments/:id/claim'), {
      params: { id: assignmentId },
      user: { userId: customerId, role: 'customer' },
      body: {},
    });
    assert.equal(claim.statusCode, 201);
    assert.ok(claim.body.redemptionToken);

    const verify = await call(handlers.get('POST /api/cashier/gifts/verify'), {
      user: { userId: cashierUserId, role: 'merchant' },
      body: { redemptionToken: claim.body.redemptionToken },
    });
    assert.equal(verify.statusCode, 200);
    assert.equal(verify.body.status, 'VERIFIED');

    const redeem = await call(handlers.get('POST /api/cashier/gifts/redeem'), {
      user: { userId: cashierUserId, role: 'merchant' },
      body: { redemptionToken: claim.body.redemptionToken, idempotencyKey: `redeem-${suffix}` },
    });
    assert.equal(redeem.statusCode, 200);
    assert.equal(redeem.body.status, 'COMPLETED');

    const replay = await call(handlers.get('POST /api/cashier/gifts/redeem'), {
      user: { userId: cashierUserId, role: 'merchant' },
      body: { redemptionToken: claim.body.redemptionToken, idempotencyKey: `redeem-${suffix}` },
    });
    assert.equal(replay.statusCode, 200);
    assert.equal(replay.body.redemptionId, redeem.body.redemptionId);
    assert.equal(replay.body.idempotentReplay, true);

    const pointAccount = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
    assert.equal(Number(pointAccount.available_points), 123);
    const ledgerCount = (await pool.query('SELECT COUNT(*)::int AS c FROM ledger_entries WHERE owner_id = $1', [customerId])).rows[0].c;
    assert.equal(ledgerCount, 0);
    const redemption = (await pool.query('SELECT redemption_kind, status FROM redemptions WHERE id = $1', [redeem.body.redemptionId])).rows[0];
    assert.deepEqual(redemption, { redemption_kind: 'GIFT', status: 'COMPLETED' });
    const inventory = (await pool.query('SELECT quantity_redeemed FROM gift_inventory WHERE gift_definition_id = $1', [giftId])).rows[0];
    assert.equal(Number(inventory.quantity_redeemed), 1);
    const adjustments = (await pool.query('SELECT COUNT(*)::int AS c FROM inventory_adjustments WHERE redemption_id = $1', [redeem.body.redemptionId])).rows[0].c;
    assert.equal(adjustments, 1);

    const analytics = await call(handlers.get('GET /api/gifts/analytics/mine'), {
      user: { userId: merchantUserId, role: 'merchant' },
      body: {},
    });
    assert.equal(analytics.statusCode, 200);
    assert.equal(analytics.body.giftCount, 1);
    assert.equal(analytics.body.campaignCount, 1);
    assert.equal(analytics.body.assignmentCount, 1);
    assert.equal(analytics.body.redeemedCount, 1);

    const reverse = await call(handlers.get('POST /api/cashier/gifts/redemptions/:id/reverse'), {
      params: { id: redeem.body.redemptionId },
      user: { userId: cashierUserId, role: 'merchant' },
      body: { reason: 'E2E reversal' },
    });
    assert.equal(reverse.statusCode, 200);
    assert.equal(reverse.body.status, 'REVERSED');
    const reversedRedemption = (await pool.query('SELECT status FROM redemptions WHERE id = $1', [redeem.body.redemptionId])).rows[0];
    assert.equal(reversedRedemption.status, 'REVERSED');
    const reversedInventory = (await pool.query('SELECT quantity_redeemed FROM gift_inventory WHERE gift_definition_id = $1', [giftId])).rows[0];
    assert.equal(Number(reversedInventory.quantity_redeemed), 0);
    const postReversalLedgerCount = (await pool.query('SELECT COUNT(*)::int AS c FROM ledger_entries WHERE owner_id = $1', [customerId])).rows[0].c;
    assert.equal(postReversalLedgerCount, 0);
  } catch (error) {
    if (error.code === 'ECONNREFUSED' || /password authentication failed/i.test(String(error.message || ''))) {
      testContext.skip(`PostgreSQL unavailable: ${error.message}`);
      return;
    }
    throw error;
  } finally {
    await pool.query('DELETE FROM notifications WHERE user_id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.query('DELETE FROM business_events WHERE customer_id = $1 OR aggregate_id IN (SELECT id::text FROM redemptions WHERE customer_id = $1)', [customerId]).catch(() => {});
    await pool.query('DELETE FROM audit_logs WHERE actor_user_id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.query('DELETE FROM redemption_requests WHERE actor_user_id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.query('DELETE FROM reversals WHERE redemption_id IN (SELECT id FROM redemptions WHERE customer_id = $1)', [customerId]).catch(() => {});
    await pool.query('DELETE FROM inventory_adjustments WHERE gift_inventory_id IN (SELECT id FROM gift_inventory WHERE gift_definition_id IN (SELECT id FROM gift_definitions WHERE source_merchant_id = $1))', [merchantId]).catch(() => {});
    await pool.query('DELETE FROM redemptions WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemption_tokens WHERE gift_claim_id IN (SELECT id FROM gift_claims WHERE customer_id = $1)', [customerId]).catch(() => {});
    await pool.query('DELETE FROM token_scans WHERE scanned_by_user_id = $1', [cashierUserId]).catch(() => {});
    await pool.query('DELETE FROM gift_claims WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM campaign_assignments WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM promo_campaigns WHERE source_id = $1', [merchantId]).catch(() => {});
    await pool.query('DELETE FROM gift_inventory WHERE gift_definition_id IN (SELECT id FROM gift_definitions WHERE source_merchant_id = $1)', [merchantId]).catch(() => {});
    await pool.query('DELETE FROM gift_definitions WHERE source_merchant_id = $1', [merchantId]).catch(() => {});
    await pool.query('DELETE FROM invoice_scans WHERE id = $1', [invoiceId]).catch(() => {});
    await pool.query('DELETE FROM point_accounts WHERE owner_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM cashier_profiles WHERE id = $1', [cashierProfileId]).catch(() => {});
    await pool.query('DELETE FROM merchant_profiles WHERE id = $1', [merchantId]).catch(() => {});
    await pool.query('DELETE FROM users WHERE id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.end();
  }
});