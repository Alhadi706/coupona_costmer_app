const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

process.env.PGHOST = process.env.PHASE2_SCHEMA_TEST_PGHOST || '127.0.0.1';
process.env.PGPORT = process.env.PHASE2_SCHEMA_TEST_PGPORT || '5434';
process.env.PGUSER = process.env.PHASE2_SCHEMA_TEST_PGUSER || 'kupuna_user';
process.env.PGDATABASE = process.env.PHASE2_SCHEMA_TEST_PGDATABASE || 'kupuna_db';
process.env.JWT_SECRET ||= 'dynamic-voucher-merchant-binding-test-secret';

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

test('dynamic voucher binds to selected merchant and validates per-store balance', async (testContext) => {
  const suffix = crypto.randomUUID();
  const merchantAUserId = `dv-merchant-a-user-${suffix}`;
  const merchantAId = `dv-merchant-a-${suffix}`;
  const merchantBUserId = `dv-merchant-b-user-${suffix}`;
  const merchantBId = `dv-merchant-b-${suffix}`;
  const cashierAUserId = `dv-cashier-a-user-${suffix}`;
  const cashierBUserId = `dv-cashier-b-user-${suffix}`;
  const customerId = `dv-customer-${suffix}`;
  const handlers = createHandlers();
  const userIds = [merchantAUserId, merchantBUserId, cashierAUserId, cashierBUserId, customerId];

  try {
    for (const [uid, role] of [[merchantAUserId, 'merchant'], [merchantBUserId, 'merchant'], [cashierAUserId, 'merchant'], [cashierBUserId, 'merchant'], [customerId, 'customer']]) {
      await pool.query(`INSERT INTO users (id, email, password_hash, role) VALUES ($1,$2,'hash',$3)`, [uid, `${uid}@example.com`, role]);
    }
    await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'متجر أ','active')`, [merchantAId, merchantAUserId]);
    await pool.query(`INSERT INTO merchant_profiles (id, user_id, business_name, status) VALUES ($1,$2,'متجر ب','active')`, [merchantBId, merchantBUserId]);
    await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [`dv-cashier-a-${suffix}`, cashierAUserId, merchantAId]);
    await pool.query(`INSERT INTO cashier_profiles (id, user_id, merchant_id, is_active) VALUES ($1,$2,$3,TRUE)`, [`dv-cashier-b-${suffix}`, cashierBUserId, merchantBId]);
    await pool.query(`INSERT INTO point_accounts (owner_id, available_points, lifetime_points) VALUES ($1,200,200)`, [customerId]);
    await pool.query(
      `INSERT INTO points_ledger_merchant (id, customer_id, merchant_id, points_delta, status) VALUES ($1,$2,$3,30,'active')`,
      [`dv-ledger-${suffix}`, customerId, merchantAId]
    );

    // 1) Exceeding the selected store balance is rejected with store-scoped error.
    const tooMuch = await call(handlers.get('POST /api/customer/redemptions/dynamic-voucher'), {
      user: { userId: customerId, role: 'customer' },
      body: { cashValueLyD: 5, merchantId: merchantAId },
    });
    assert.equal(tooMuch.statusCode, 400);
    assert.equal(tooMuch.body.error, 'insufficient_points_at_merchant');
    assert.equal(tooMuch.body.availablePoints, 30);
    assert.equal(tooMuch.body.requiredPoints, 50);

    // 2) Unknown merchant is rejected.
    const unknownMerchant = await call(handlers.get('POST /api/customer/redemptions/dynamic-voucher'), {
      user: { userId: customerId, role: 'customer' },
      body: { cashValueLyD: 1, merchantId: `no-such-merchant-${suffix}` },
    });
    assert.equal(unknownMerchant.statusCode, 404);
    assert.equal(unknownMerchant.body.error, 'merchant_not_found');

    // 3) Within the store balance succeeds and binds the voucher to the merchant.
    const create = await call(handlers.get('POST /api/customer/redemptions/dynamic-voucher'), {
      user: { userId: customerId, role: 'customer' },
      body: { cashValueLyD: 2, merchantId: merchantAId },
    });
    assert.equal(create.statusCode, 201);
    assert.equal(create.body.voucher.merchantId, merchantAId);
    assert.equal(create.body.voucher.merchantName, 'متجر أ');
    assert.equal(create.body.voucher.pointsUsed, 20);

    const claim = (await pool.query('SELECT merchant_id FROM cash_voucher_claims WHERE id = $1', [create.body.redemptionId])).rows[0];
    assert.equal(claim.merchant_id, merchantAId);

    // 4) Cashier verify surfaces the merchant binding.
    const verify = await call(handlers.get('POST /api/cashier/dynamic-voucher/verify'), {
      user: { userId: cashierAUserId, role: 'merchant' },
      body: { qrCode: create.body.voucher.qrCode },
    });
    assert.equal(verify.statusCode, 200);
    assert.equal(verify.body.merchantId, merchantAId);
    assert.equal(verify.body.merchantName, 'متجر أ');

    // 5) A cashier of a different merchant cannot redeem the bound voucher.
    const mismatch = await call(handlers.get('POST /api/cashier/dynamic-voucher/redeem'), {
      user: { userId: cashierBUserId, role: 'merchant' },
      body: { qrCode: create.body.voucher.qrCode },
    });
    assert.equal(mismatch.statusCode, 409);
    assert.equal(mismatch.body.error, 'voucher_merchant_mismatch');

    // 6) The bound merchant's cashier redeems; global and per-store ledgers debit.
    const redeem = await call(handlers.get('POST /api/cashier/dynamic-voucher/redeem'), {
      user: { userId: cashierAUserId, role: 'merchant' },
      body: { qrCode: create.body.voucher.qrCode, idempotencyKey: `dv-${suffix}` },
    });
    assert.equal(redeem.statusCode, 200);
    assert.equal(redeem.body.pointsDebited, 20);
    assert.equal(redeem.body.merchantId, merchantAId);

    const account = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId])).rows[0];
    assert.equal(Number(account.available_points), 180);

    const merchantBalance = (await pool.query(
      `SELECT COALESCE(SUM(CASE WHEN status = 'active' THEN points_delta ELSE 0 END), 0)::int AS active_points
         FROM points_ledger_merchant WHERE customer_id = $1 AND merchant_id = $2`,
      [customerId, merchantAId]
    )).rows[0];
    assert.equal(Number(merchantBalance.active_points), 10);
  } catch (error) {
    if (error.code === 'ECONNREFUSED' || /password authentication failed/i.test(String(error.message || ''))) {
      testContext.skip(`PostgreSQL unavailable: ${error.message}`);
      return;
    }
    throw error;
  } finally {
    await pool.query('DELETE FROM notifications WHERE user_id = ANY($1::text[])', [userIds]).catch(() => {});
    await pool.query('DELETE FROM business_events WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemption_requests WHERE actor_user_id = ANY($1::text[])', [userIds]).catch(() => {});
    await pool.query('DELETE FROM points_ledger_merchant WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM ledger_entries WHERE owner_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemptions WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM redemption_tokens WHERE cash_voucher_claim_id IN (SELECT id FROM cash_voucher_claims WHERE customer_id = $1)', [customerId]).catch(() => {});
    await pool.query('DELETE FROM token_scans WHERE scanned_by_user_id = ANY($1::text[])', [[cashierAUserId, cashierBUserId]]).catch(() => {});
    await pool.query('DELETE FROM cash_voucher_claims WHERE customer_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM point_accounts WHERE owner_id = $1', [customerId]).catch(() => {});
    await pool.query('DELETE FROM cashier_profiles WHERE user_id = ANY($1::text[])', [[cashierAUserId, cashierBUserId]]).catch(() => {});
    await pool.query('DELETE FROM merchant_profiles WHERE id = ANY($1::text[])', [[merchantAId, merchantBId]]).catch(() => {});
    await pool.query('DELETE FROM users WHERE id = ANY($1::text[])', [userIds]).catch(() => {});
  }
});
