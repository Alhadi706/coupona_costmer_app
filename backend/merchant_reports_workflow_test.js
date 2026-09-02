const assert = require('node:assert/strict');
const test = require('node:test');

const registerReportsRoutes = require('./src/routes/reports');

function response() {
  return {statusCode: 200, body: null, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }};
}

test('merchant requests information without granting points and records the conversation', async () => {
  const queries = [];
  const notifications = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT r.*')) return {rows: [{id: 'report-1', owner_id: 'customer-1', status: 'new'}]};
      if (sql.includes('SELECT business_name')) return {rows: [{business_name: 'Store One'}]};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const routes = new Map();
  const app = {get(path, ...handlers) { routes.set(`GET ${path}`, handlers.at(-1)); }, post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); }};
  registerReportsRoutes(app, {
    pool: {async connect() { return client; }, async query(sql, params) { return client.query(sql, params); }},
    auth(_req, _res, next) { next(); },
    requireAdmin(_req, _res, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
    async getBrandProfileIdByUser() { return null; },
    async insertNotification(_client, userId, type, title, body, payload) { notifications.push({userId, type, title, body, payload}); },
    id() { return 'update-1'; },
    toIso(value) { return value || null; },
  });
  const res = response();
  await routes.get('POST /api/merchant/reports/:id/accept')({
    user: {userId: 'merchant-user'}, params: {id: 'report-1'},
    body: {action: 'request_information', resolutionNote: 'Attach a clearer invoice.'},
  }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.status, 'information_requested');
  assert.equal(queries.some(({sql}) => sql.includes('UPDATE point_accounts')), false);
  const update = queries.find(({sql}) => sql.includes('INSERT INTO report_updates'));
  assert.deepEqual(update.params, ['update-1', 'report-1', 'merchant-user', 'Attach a clearer invoice.']);
  assert.equal(notifications[0].type, 'report_information_requested');
  assert.equal(notifications[0].payload.targetScreen, 'reports');
  assert.equal(queries.at(-1).sql, 'COMMIT');
});

test('merchant rejection requires a resolution note before database access', async () => {
  let connected = false;
  const routes = new Map();
  const app = {get() {}, post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); }};
  registerReportsRoutes(app, {
    pool: {async connect() { connected = true; return {}; }},
    auth(_req, _res, next) { next(); }, requireAdmin(_req, _res, next) { next(); },
  });
  const res = response();
  await routes.get('POST /api/merchant/reports/:id/accept')({
    user: {userId: 'merchant-user'}, params: {id: 'report-1'}, body: {action: 'reject'},
  }, res);
  assert.equal(res.statusCode, 400);
  assert.deepEqual(res.body, {error: 'resolution_note_required'});
  assert.equal(connected, false);
});