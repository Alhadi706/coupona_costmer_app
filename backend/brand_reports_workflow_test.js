const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'brand-reports-workflow-test-secret';
process.env.PGPASSWORD ||= 'brand-reports-workflow-test-password';

const registerReportsRoutes = require('./src/routes/reports');

function createResponse() {
  return {statusCode: 200, body: null, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }};
}

function reportRoutes(client, notifications = []) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) { routes.set(`GET ${path}`, handlers.at(-1)); },
    post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); },
  };
  registerReportsRoutes(app, {
    pool: {async connect() { return client; }, async query(sql, params) { return client.query(sql, params); }},
    auth(_req, _res, next) { next(); },
    async getBrandProfileIdByUser() { return 'brand-1'; },
    async getMerchantProfileIdByUser() { return null; },
    async insertNotification(_client, userId, type, title, body, payload) { notifications.push({userId, type, title, body, payload}); },
    toIso(value) { return value == null ? null : new Date(value).toISOString(); },
    id() { return 'id-1'; },
  });
  return routes;
}

test('brand cannot resolve a report owned by another brand', async () => {
  let ownershipQuery;
  const client = {
    async query(sql, params) {
      if (sql.includes('FROM reports WHERE id')) ownershipQuery = {sql, params};
      return {rows: []};
    },
    release() {},
  };
  const response = createResponse();

  await reportRoutes(client).get('POST /api/brand/reports/:id/resolve')(
    {user: {userId: 'brand-user'}, params: {id: 'report-other'}, body: {action: 'accept'}},
    response,
  );

  assert.equal(response.statusCode, 404);
  assert.deepEqual(response.body, {error: 'report_not_found'});
  assert.match(ownershipQuery.sql, /target_brand_id = \$2/);
  assert.deepEqual(ownershipQuery.params, ['report-other', 'brand-1']);
});

test('request information assigns the reviewer and notifies without granting points', async () => {
  const queries = [];
  const notifications = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reports WHERE id')) return {rows: [{id: 'report-1', owner_id: 'customer-1', status: 'new'}]};
      return {rows: []};
    },
    release() {},
  };
  const response = createResponse();

  await reportRoutes(client, notifications).get('POST /api/brand/reports/:id/resolve')(
    {user: {userId: 'reviewer-1'}, params: {id: 'report-1'}, body: {action: 'request_information', resolutionNote: 'أرفق صورة أوضح'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.status, 'information_requested');
  const update = queries.find(({sql}) => sql.includes('UPDATE reports SET status'));
  assert.equal(update.params[1], 'information_requested');
  assert.equal(update.params[4], 'reviewer-1');
  assert.equal(queries.some(({sql}) => sql.includes('UPDATE point_accounts')), false);
  assert.equal(notifications[0].type, 'report_information_requested');
  assert.equal(notifications[0].payload.reportId, 'report-1');
});

test('customer response preserves the original report and returns it to review', async () => {
  const queries = [];
  const notifications = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reports') && sql.includes('owner_id = $2')) {
        return {rows: [{id: 'report-1', owner_id: 'customer-1', status: 'information_requested', target_brand_id: 'brand-1', target_store_id: null}]};
      }
      if (sql.includes('SELECT user_id FROM brand_profiles')) return {rows: [{user_id: 'brand-owner'}]};
      return {rows: []};
    },
    release() {},
  };
  const response = createResponse();

  await reportRoutes(client, notifications).get('POST /api/reports/:id/respond')(
    {user: {userId: 'customer-1'}, params: {id: 'report-1'}, body: {message: 'هذه صورة أوضح ورقم الدفعة 42'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.status, 'new');
  const insert = queries.find(({sql}) => sql.includes('INSERT INTO report_updates'));
  assert.deepEqual(insert.params.slice(1), ['report-1', 'customer-1', 'هذه صورة أوضح ورقم الدفعة 42']);
  assert.equal(queries.some(({sql}) => sql.includes("SET status = 'new'")), true);
  assert.equal(queries.some(({sql}) => sql.includes('UPDATE reports') && sql.includes('description')), false);
  assert.equal(notifications[0].userId, 'brand-owner');
  assert.equal(notifications[0].type, 'report_customer_responded');
});

test('non-owner cannot append information to a report', async () => {
  let updateRan = false;
  const client = {
    async query(sql) {
      if (sql.includes('INSERT INTO report_updates') || sql.includes('UPDATE reports')) updateRan = true;
      return {rows: []};
    },
    release() {},
  };
  const response = createResponse();

  await reportRoutes(client).get('POST /api/reports/:id/respond')(
    {user: {userId: 'other-customer'}, params: {id: 'report-1'}, body: {message: 'محاولة غير مصرح بها'}},
    response,
  );

  assert.equal(response.statusCode, 404);
  assert.equal(updateRan, false);
});

for (const scenario of [
  {action: 'accept', expectedStatus: 'accepted', grantsPoints: false, notificationType: 'report_accepted'},
  {action: 'reward', expectedStatus: 'reward_granted', grantsPoints: true, notificationType: 'report_accepted_reward'},
  {action: 'reject', expectedStatus: 'rejected', grantsPoints: false, notificationType: 'report_rejected'},
]) {
  test(`brand report action ${scenario.action} has the expected wallet and notification effects`, async () => {
    const queries = [];
    const notifications = [];
    const client = {
      async query(sql, params) {
        queries.push({sql, params});
        if (sql.includes('FROM reports WHERE id')) return {rows: [{id: 'report-1', owner_id: 'customer-1', status: 'new'}]};
        return {rows: []};
      },
      release() {},
    };
    const response = createResponse();

    await reportRoutes(client, notifications).get('POST /api/brand/reports/:id/resolve')(
      {user: {userId: 'reviewer-1'}, params: {id: 'report-1'}, body: {action: scenario.action, rewardPoints: 10, resolutionNote: 'Decision note'}},
      response,
    );

    assert.equal(response.statusCode, 200);
    assert.equal(response.body.status, scenario.expectedStatus);
    assert.equal(queries.some(({sql}) => sql.includes('UPDATE point_accounts')), scenario.grantsPoints);
    assert.equal(notifications[0].type, scenario.notificationType);
  });
}
