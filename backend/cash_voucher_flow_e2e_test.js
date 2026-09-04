const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

process.env.PGHOST = process.env.PHASE2_SCHEMA_TEST_PGHOST || '127.0.0.1';
process.env.PGPORT = process.env.PHASE2_SCHEMA_TEST_PGPORT || '5434';
process.env.PGUSER = process.env.PHASE2_SCHEMA_TEST_PGUSER || 'kupuna_user';
process.env.PGDATABASE = process.env.PHASE2_SCHEMA_TEST_PGDATABASE || 'kupuna_db';
process.env.JWT_SECRET ||= 'cash-voucher-flow-e2e-test-secret';

const { pool } = require('./src/db');
const registerCoalitionRoutes = require('./src/routes/coalition');
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

function createHandlers() {
  const handlers = new Map();
  const app = {
    get(path, ...routeHandlers) { handlers.set(`GET ${path}`, routeHandlers.at(-1)); },
    post(path, ...routeHandlers) { handlers.set(`POST ${path}`, routeHandlers.at(-1)); },
    put(path, ...routeHandlers) { handlers.set(`PUT ${path}`, routeHandlers.at(-1)); },
    patch(path, ...routeHandlers) { handlers.set(`PATCH ${path}`, routeHandlers.at(-1)); },
    delete(path, ...routeHandlers) { handlers.set(`DELETE ${path}`, routeHandlers.at(-1)); },
  };
  registerCoalitionRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    id: () => crypto.randomUUID(),
    toIso: (value) => value == null ? null : new Date(value).toISOString(),
    getMerchantProfileIdByUser: servicesMatching.getMerchantProfileIdByUser,
    getBrandProfileIdByUser: servicesMatching.getBrandProfileIdByUser,
    insertNotification: servicesSocial.insertNotification,
  });
  return handlers;
}

async function call(handler, req) {
  const response = createResponse();
  await handler(req, response);
  return response;
}

test('cash voucher flow debits points only at cashier redemption', async (testContext) => {
  const suffix = crypto.randomUUID();
  const merchantUserId = `cash-merchant-user-${suffix}`;
  const merchantId = `cash-merchant-${suffix}`;
  const cashierUserId = `cash-cashier-user-${suffix}`;
  const cashierProfileId = `cash-cashier-${suffix}`;
  const customerId = `cash-customer-${suffix}`;
  const handlers = createHandlers();

  try {
    await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [merchantUserId, `${merchantUserId}@example.com`]);
    await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','merchant')`, [cashierUserId, `${cashierUserId}@example.com`]);
    await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash','customer')`, [customerId, `${customerId}@example.com`]);
    await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'Cash Merchant','active')`, [merchantId, merchantUserId]);
    await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [cashierProfileId, cashierUserId, merchantId]);
    await pool.query(`INSERT INTO point_accounts (owner_id, available_points, lifetime_points) VALUES ($1,200,200)`, [customerId]);

    const create = await call(handlers.get('POST /api/customer/redemptions/dynamic-voucher'), {
      user: { userId: customerId, role: 'customer' },
      body: { cashValueLyD: 5 },
    });
    assert.equal(create.statusCode, 201);
    assert.ok(create.body.voucher.qrCode);
    assert.equal(create.body.voucher.pointsUsed, 50);

    let points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
    assert.equal(Number(points.available_points), 200);

    const verify = await call(handlers.get('POST /api/cashier/dynamic-voucher/verify'), {
      user: { userId: cashierUserId, role: 'merchant' },
      body: { qrCode: create.body.voucher.qrCode },
    });
    assert.equal(verify.statusCode, 200);
    assert.equal(verify.body.status, 'VERIFIED');

    points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
    assert.equal(Number(points.available_points), 200);

    const redeem = await call(handlers.get('POST /api/cashier/dynamic-voucher/redeem'), {
      user: { userId: cashierUserId, role: 'merchant' },
      body: { qrCode: create.body.voucher.qrCode, idempotencyKey: `cash-${suffix}` },
    });
    assert.equal(redeem.statusCode, 200);
    assert.equal(redeem.body.pointsDebited, 50);
    assert.equal(redeem.body.cashValueLyD, 5);

    points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
    assert.equal(Number(points.available_points), 150);
    const ledger = (await pool.query(`SELECT type, points, amount FROM ledger_entries WHERE owner_id = $1 AND type = 'cashVoucherRedeemed'`, [customerId])).rows[0];
    assert.equal(ledger.type, 'cashVoucherRedeemed');
    assert.equal(Number(ledger.points), -50);
    assert.equal(Number(ledger.amount), 5);

    const replay = await call(handlers.get('POST /api/cashier/dynamic-voucher/redeem'), {
      user: { userId: cashierUserId, role: 'merchant' },
      body: { qrCode: create.body.voucher.qrCode, idempotencyKey: `cash-${suffix}` },
    });
    assert.equal(replay.statusCode, 200);
    assert.equal(replay.body.redemptionId, redeem.body.redemptionId);
    assert.equal(replay.body.idempotentReplay, true);
  } catch (error) {
    if (error.code === 'ECONNREFUSED' || /password authentication failed/i.test(String(error.message || ''))) {
      testContext.skip(`PostgreSQL unavailable: ${error.message}`);
      return;
    }
    throw error;
  } finally {
    await pool.query('DELETE FROM notifications WHERE user_id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.query('DELETE FROM business_events WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemption_requests WHERE actor_user_id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.query('DELETE FROM ledger_entries WHERE owner_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemptions WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemption_tokens WHERE cash_voucher_claim_id IN (SELECT id FROM cash_voucher_claims WHERE customer_id = $1)', [customerId]).catch(() => {});
    await pool.query('DELETE FROM token_scans WHERE scanned_by_user_id = $1', [cashierUserId]).catch(() => {});
    await pool.query('DELETE FROM cash_voucher_claims WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM point_accounts WHERE owner_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM cashier_profiles WHERE id = $1', [cashierProfileId]).catch(() => {});
    await pool.query('DELETE FROM merchant_profiles WHERE id = $1', [merchantId]).catch(() => {});
    await pool.query('DELETE FROM users WHERE id = ANY($1::text[])', [[customerId, merchantUserId, cashierUserId]]).catch(() => {});
    await pool.end();
  }
});