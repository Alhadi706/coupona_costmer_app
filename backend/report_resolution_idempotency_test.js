const assert = require('node:assert/strict');
const test = require('node:test');

const registerReportsRoutes = require('./src/routes/reports');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

function registerHandlers({client, merchantId = 'merchant-1', brandId = 'brand-1', onNotification}) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) {
      routes.set(`GET ${path}`, handlers.at(-1));
    },
    post(path, ...handlers) {
      routes.set(`POST ${path}`, handlers.at(-1));
    },
  };
  registerReportsRoutes(app, {
    pool: {
      async connect() {
        return client;
      },
    },
    auth(_req, _res, next) {
      next();
    },
    requireAdmin(_req, _res, next) {
      next();
    },
    async getMerchantProfileIdByUser() {
      return merchantId;
    },
    async getBrandProfileIdByUser() {
      return brandId;
    },
    async insertNotification(...args) {
      onNotification?.(...args);
    },
  });
  return routes;
}

function resolvedReportClient() {
  const statements = [];
  return {
    statements,
    async query(sql) {
      statements.push(sql);
      if (sql.includes('SELECT * FROM reports') || sql.includes('SELECT r.*')) {
        return {rows: [{id: 'report-1', owner_id: 'customer-1', status: 'accepted'}]};
      }
      return {rows: []};
    },
    release() {},
  };
}

test('brand cannot grant points twice for an already resolved report', async () => {
  const client = resolvedReportClient();
  let notifications = 0;
  const handler = registerHandlers({
    client,
    onNotification() {
      notifications += 1;
    },
  }).get('POST /api/brand/reports/:id/resolve');
  const response = createResponse();

  await handler(
    {user: {userId: 'brand-user'}, params: {id: 'report-1'}, body: {grantReward: true, rewardPoints: 10}},
    response,
  );

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, {error: 'report_already_resolved', status: 'accepted'});
  assert.equal(notifications, 0);
  assert.equal(client.statements.some((sql) => sql.includes('UPDATE point_accounts')), false);
  assert.equal(client.statements.at(-1), 'ROLLBACK');
});

test('merchant cannot grant points twice for an already resolved report', async () => {
  const client = resolvedReportClient();
  let notifications = 0;
  const handler = registerHandlers({
    client,
    onNotification() {
      notifications += 1;
    },
  }).get('POST /api/merchant/reports/:id/accept');
  const response = createResponse();

  await handler(
    {user: {userId: 'merchant-user'}, params: {id: 'report-1'}, body: {grantReward: true, rewardPoints: 10}},
    response,
  );

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, {error: 'report_already_resolved', status: 'accepted'});
  assert.equal(notifications, 0);
  assert.equal(client.statements.some((sql) => sql.includes('UPDATE point_accounts')), false);
  assert.equal(client.statements.at(-1), 'ROLLBACK');
});
