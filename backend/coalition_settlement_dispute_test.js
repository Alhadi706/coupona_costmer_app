const assert = require('node:assert/strict');
const test = require('node:test');
const register = require('./src/routes/coalition');

function setup(query) {
  const routes = new Map();
  const app = {};
  for (const method of ['get', 'post', 'put', 'patch', 'delete']) app[method] = (path, ...handlers) => routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
  register(app, {
    pool: {query}, auth(_q, _s, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
    async getBrandProfileIdByUser() { return 'brand-1'; },
    async insertNotification() {}, toIso(value) { return value || null; },
  });
  return routes;
}

function response() {
  return {statusCode: 200, body: null, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }};
}

test('merchant clearinghouse includes disputes assigned to that merchant', async () => {
  let calls = 0;
  const routes = setup(async () => {
    calls += 1;
    return calls === 1 ? {rows: []} : {rows: [{id: 'd-1', claim_id: 'c-1', brand_id: 'b-1', brand_name: 'Brand', reason: 'Mismatch', status: 'open'}]};
  });
  const res = response();
  await routes.get('GET /api/merchant/coalitions/clearinghouse')({user: {userId: 'owner'}}, res);
  assert.equal(res.body.disputes[0].id, 'd-1');
  assert.equal(res.body.disputes[0].brandName, 'Brand');
});

test('settlement replay returns conflict instead of silent success', async () => {
  const routes = setup(async () => ({rowCount: 0, rows: []}));
  const res = response();
  await routes.get('POST /api/merchant/coalitions/clearinghouse/settle')({user: {userId: 'owner'}, body: {coalition_id: 'co-1', to_merchant_id: 'm-2', period: '2026-09'}}, res);
  assert.equal(res.statusCode, 409);
  assert.equal(res.body.error, 'clearinghouse_already_settled_or_not_found');
});

test('merchant cannot respond to another merchant settlement dispute', async () => {
  let params;
  const routes = setup(async (_sql, values) => { params = values; return {rows: []}; });
  const res = response();
  await routes.get('POST /api/merchant/coalitions/clearinghouse/disputes/:id/respond')({user: {userId: 'owner'}, params: {id: 'd-other'}, body: {status: 'resolved', note: 'Checked'}}, res);
  assert.deepEqual(params.slice(0, 2), ['d-other', 'merchant-1']);
  assert.equal(res.statusCode, 404);
});