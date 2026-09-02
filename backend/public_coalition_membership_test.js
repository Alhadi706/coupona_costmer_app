const assert = require('node:assert/strict');
const test = require('node:test');

const registerRoutes = require('./src/routes/public-coalition-membership');

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function register({pool, merchantId = null, brandId = null, notifications = []}) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) { routes.set(`GET ${path}`, handlers.at(-1)); },
    post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); },
  };
  registerRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    requireAdmin(_req, _res, next) { next(); },
    id() { return 'request-1'; },
    toIso(value) { return value || null; },
    async getMerchantProfileIdByUser() { return merchantId; },
    async getBrandProfileIdByUser() { return brandId; },
    async insertNotification(...args) { notifications.push(args); },
  });
  return routes;
}

test('merchant and brand can submit idempotent public coalition applications', async () => {
  for (const applicant of [
    {type: 'merchant', merchantId: 'merchant-1', brandId: null},
    {type: 'brand', merchantId: null, brandId: 'brand-1'},
  ]) {
    const statements = [];
    const pool = {
      async query(sql, params) {
        statements.push({sql, params});
        if (sql.includes('SELECT *')) return {rows: []};
        return {rows: [{
          id: 'request-1',
          applicant_type: applicant.type,
          applicant_profile_id: params[2],
          applicant_user_id: params[3],
          status: 'pending_admin_review',
        }]};
      },
    };
    const handler = register({...applicant, pool}).get('POST /api/public-coalition/membership/request');
    const res = response();
    await handler({user: {userId: `${applicant.type}-user`}, body: {applicantType: applicant.type}}, res);

    assert.equal(res.statusCode, 201);
    assert.equal(res.body.applicantType, applicant.type);
    assert.equal(res.body.status, 'pending_admin_review');
    assert.deepEqual(statements[1].params, ['request-1', applicant.type, `${applicant.type}-1`, `${applicant.type}-user`]);
  }
});

test('customer cannot submit a public coalition application', async () => {
  let queried = false;
  const pool = {async query() { queried = true; return {rows: []}; }};
  const handler = register({pool}).get('POST /api/public-coalition/membership/request');
  const res = response();
  await handler({user: {userId: 'customer-1'}, body: {applicantType: 'merchant'}}, res);
  assert.equal(res.statusCode, 403);
  assert.equal(queried, false);
});

test('admin approval moves request to payment and sends a private message', async () => {
  const notifications = [];
  const pool = {
    async query(sql) {
      assert.match(sql, /approved_pending_payment/);
      return {rows: [{
        id: 'request-1', applicant_type: 'merchant', applicant_user_id: 'merchant-user',
        status: 'approved_pending_payment', admin_message: 'Pay using this private link',
        payment_url: 'https://payments.example/join/request-1',
      }]};
    },
  };
  const handler = register({pool, notifications}).get('POST /api/admin/public-coalition/membership-requests/:id/approve');
  const res = response();
  await handler({
    user: {userId: 'admin-1'}, params: {id: 'request-1'},
    body: {adminMessage: 'Pay using this private link', paymentUrl: 'https://payments.example/join/request-1'},
  }, res);

  assert.equal(res.body.status, 'approved_pending_payment');
  assert.equal(notifications.length, 1);
  assert.equal(notifications[0][1], 'merchant-user');
  assert.equal(notifications[0][5].targetScreen, 'public_coalition_membership');
});

test('activation is rejected before admin approval and payment stage', async () => {
  const statements = [];
  const client = {
    async query(sql) {
      statements.push(sql);
      if (sql.includes('SELECT *')) return {rows: [{id: 'request-1', status: 'pending_admin_review'}]};
      return {rows: []};
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool}).get('POST /api/admin/public-coalition/membership-requests/:id/activate');
  const res = response();
  await handler({user: {userId: 'admin-1'}, params: {id: 'request-1'}, body: {paymentReference: 'PAY-1'}}, res);

  assert.equal(res.statusCode, 409);
  assert.equal(statements.some((sql) => sql.includes('coalition_members (')), false);
  assert.equal(statements.at(-1), 'ROLLBACK');
});

test('manual activation adds the correct applicant membership atomically', async () => {
  for (const applicantType of ['merchant', 'brand']) {
    const statements = [];
    const notifications = [];
    const client = {
      async query(sql) {
        statements.push(sql);
        if (sql.includes('SELECT *')) return {rows: [{
          id: 'request-1', applicant_type: applicantType,
          applicant_profile_id: `${applicantType}-1`, applicant_user_id: `${applicantType}-user`,
          status: 'approved_pending_payment',
        }]};
        if (sql.includes("SET status = 'active'")) return {rows: [{
          id: 'request-1', applicant_type: applicantType,
          applicant_profile_id: `${applicantType}-1`, applicant_user_id: `${applicantType}-user`,
          status: 'active', activation_source: 'manual_admin',
        }]};
        return {rows: []};
      },
      release() {},
    };
    const pool = {async connect() { return client; }};
    const handler = register({pool, notifications}).get('POST /api/admin/public-coalition/membership-requests/:id/activate');
    const res = response();
    await handler({user: {userId: 'admin-1'}, params: {id: 'request-1'}, body: {paymentReference: 'PAY-1'}}, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.status, 'active');
    assert.equal(statements.some((sql) => sql.includes(applicantType === 'merchant' ? 'coalition_members (' : 'brand_coalition_members (')), true);
    assert.equal(statements.at(-1), 'COMMIT');
    assert.equal(notifications.length, 1);
  }
});