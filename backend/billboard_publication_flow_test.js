const assert = require('node:assert/strict');
const test = require('node:test');

const registerRoutes = require('./src/routes/offers-billboard');

function response() {
  return {
    statusCode: 200,
    body: null,
    sentFile: null,
    contentType: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
    type(value) { this.contentType = value; return this; },
    sendFile(value) { this.sentFile = value; return this; },
  };
}

function register(pool) {
  const routes = new Map();
  const app = {};
  let nextId = 0;
  for (const method of ['get', 'post']) {
    app[method] = (path, ...handlers) => routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
  }
  registerRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    requireAdmin(_req, _res, next) { next(); },
    toIso(value) { return value || null; },
    id() { nextId += 1; return `generated-${nextId}`; },
    getMerchantProfileIdByUser: async () => 'merchant-1',
    getIntSetting: async (_client, _key, fallback) => fallback,
    UPLOAD_DIR: '/uploads',
  });
  return routes;
}

test('admin approval shifts an expired review window and preserves a minimum duration', async () => {
  let approvalSql = '';
  const pool = {
    async query(sql) {
      approvalSql = sql;
      return {rowCount: 1, rows: [{id: 'ad-1', start_date: 'now', end_date: 'later'}]};
    },
  };
  const handler = register(pool).get('POST /api/admin/billboard-ads/:id/approve');
  const res = response();
  await handler({params: {id: 'ad-1'}, user: {userId: 'admin-1'}}, res);

  assert.equal(res.body.status, 'active');
  assert.match(approvalSql, /end_date <= NOW\(\)/);
  assert.match(approvalSql, /INTERVAL '1 day'/);
  assert.match(approvalSql, /published_at = NOW\(\)/);
  assert.match(approvalSql, /lifecycle_status IN \('pending', 'pending_review'\)/);
  assert.match(approvalSql, /lifecycle_status = 'active'/);
});

test('admin rejection only transitions an ad pending review', async () => {
  let rejectionSql = '';
  const pool = {
    async query(sql) {
      rejectionSql = sql;
      return {rowCount: 1, rows: [{id: 'ad-1'}]};
    },
  };
  const handler = register(pool).get('POST /api/admin/billboard-ads/:id/reject');
  const res = response();
  await handler({params: {id: 'ad-1'}, body: {reason: 'Not suitable'}}, res);

  assert.equal(res.body.status, 'rejected');
  assert.match(rejectionSql, /lifecycle_status IN \('pending', 'pending_review'\)/);
});

test('admin pending queue includes both status variants and card fields', async () => {
  let querySql = '';
  let queryParams;
  const pool = {
    async query(sql, params) {
      querySql = sql;
      queryParams = params;
      return {rows: [{
        id: 'ad-1', owner_id: 'merchant-1', business_name: 'Demo Store',
        image_url: '/api/uploads/banner.jpg', lifecycle_status: 'pending',
        start_date: 'start', end_date: 'end', created_at: 'created',
      }]};
    },
  };
  const handler = register(pool).get('GET /api/admin/billboard-ads');
  const res = response();
  await handler({query: {status: 'pending_review'}, protocol: 'http', headers: {host: 'api.test'}}, res);

  assert.match(querySql, /o\.lifecycle_status IN \('pending', 'pending_review'\)/);
  assert.deepEqual(queryParams, []);
  assert.equal(res.body[0].businessName, 'Demo Store');
  assert.equal(res.body[0].imageUrl, 'http://api.test/api/uploads/banner.jpg');
  assert.equal(res.body[0].startDate, 'start');
  assert.equal(res.body[0].endDate, 'end');
});

test('customer billboard feed returns a dedicated public image URL', async () => {
  const pool = {
    async query() {
      return {rows: [{
        id: 'ad-1', image_url: '/api/uploads/private.jpg', lifecycle_status: 'active',
        description: 'Visible ad', created_at: 'created', published_at: 'published',
      }]};
    },
  };
  const handler = register(pool).get('GET /api/billboard-ads');
  const res = response();
  await handler({user: {userId: 'customer-1'}, protocol: 'https', headers: {host: 'api.test'}}, res);
  assert.equal(res.body[0].imageUrl, 'https://api.test/api/billboard-ads/ad-1/image');
  assert.equal(res.body[0].description, 'Visible ad');
});

test('merchant billboard creation deducts gold and queues pending review atomically', async () => {
  const statements = [];
  const client = {
    async query(sql, params) {
      statements.push({sql, params});
      if (sql.includes('SELECT balance FROM merchant_token_wallets')) {
        return {rows: [{balance: 150}], rowCount: 1};
      }
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const pool = {connect: async () => client};
  const handler = register(pool).get('POST /api/merchant/billboard-ads');
  const res = response();
  await handler({
    user: {userId: 'merchant-user'},
    body: {imageUrl: '/api/uploads/banner.jpg', description: 'Campaign'},
  }, res);

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.status, 'pending_review');
  assert.equal(res.body.pointsDeducted, 100);
  assert.equal(res.body.balance, 50);
  assert.match(statements.find(({sql}) => sql.includes('SELECT balance')).sql, /FOR UPDATE/);
  assert.match(statements.find(({sql}) => sql.includes('INSERT INTO offers')).sql, /'pending_review'/);
  assert.deepEqual(statements.find(({sql}) => sql.includes('UPDATE merchant_token_wallets')).params, ['merchant-1', 50]);
  assert.equal(statements.at(-1).sql, 'COMMIT');
});

test('merchant billboard creation does not insert or deduct when gold is insufficient', async () => {
  const statements = [];
  const client = {
    async query(sql) {
      statements.push(sql);
      if (sql.includes('SELECT balance FROM merchant_token_wallets')) {
        return {rows: [{balance: 25}], rowCount: 1};
      }
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const handler = register({connect: async () => client}).get('POST /api/merchant/billboard-ads');
  const res = response();
  await handler({user: {userId: 'merchant-user'}, body: {imageUrl: '/api/uploads/banner.jpg'}}, res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'insufficient_gold_points');
  assert.equal(statements.some((sql) => sql.includes('INSERT INTO offers')), false);
  assert.equal(statements.some((sql) => sql.includes('UPDATE merchant_token_wallets')), false);
  assert.equal(statements.at(-1), 'ROLLBACK');
});

test('public image endpoint denies ads without an active in-window upload', async () => {
  const pool = {async query() { return {rows: []}; }};
  const handler = register(pool).get('GET /api/billboard-ads/:id/image');
  const res = response();
  await handler({params: {id: 'inactive-ad'}}, res);
  assert.equal(res.statusCode, 404);
  assert.equal(res.sentFile, null);
});

test('offer history is scoped to the authenticated owner', async () => {
  let params;
  let sql;
  const pool = {
    async query(statement, values) {
      sql = statement;
      params = values;
      return {rows: []};
    },
  };
  const handler = register(pool).get('GET /api/offers/mine');
  const res = response();
  await handler({user: {userId: 'brand-user'}}, res);
  assert.match(sql, /o\.owner_id = \$1/);
  assert.deepEqual(params, ['brand-user']);
  assert.deepEqual(res.body, []);
});