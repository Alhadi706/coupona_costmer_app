const assert = require('node:assert/strict');
const test = require('node:test');

const registerMerchantRoutes = require('./src/routes/merchant');

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function handlerFor(client) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) { routes.set(`GET ${path}`, handlers.at(-1)); },
    post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); },
    patch(path, ...handlers) { routes.set(`PATCH ${path}`, handlers.at(-1)); },
  };
  registerMerchantRoutes(app, {
    pool: {async connect() { return client; }},
    auth(_req, _res, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
    async assertMerchantSubscriptionWritable() {},
    isMerchantSubscriptionReadOnlyError() { return false; },
  });
  return routes.get('PATCH /api/merchant/branches/:id');
}

test('merchant can deactivate a branch without deleting it', async () => {
  let updateSql;
  let updateParams;
  const client = {
    async query(sql, params) {
      updateSql = sql;
      updateParams = params;
      return {rowCount: 1, rows: [{id: 'branch-1', merchant_id: 'merchant-1', status: 'inactive'}]};
    },
    release() {},
  };
  const res = response();
  await handlerFor(client)({
    user: {userId: 'owner-user'}, params: {id: 'branch-1'}, body: {status: 'inactive'},
  }, res);

  assert.equal(res.statusCode, 200);
  assert.match(updateSql, /status = COALESCE\(\$7, status\)/);
  assert.equal(updateParams[4], 'branch-1');
  assert.equal(updateParams[5], 'merchant-1');
  assert.equal(updateParams[6], 'inactive');
});

test('invalid branch status is rejected before update', async () => {
  let queried = false;
  const client = {
    async query() { queried = true; return {rows: []}; },
    release() {},
  };
  const res = response();
  await handlerFor(client)({
    user: {userId: 'owner-user'}, params: {id: 'branch-1'}, body: {status: 'deleted'},
  }, res);

  assert.equal(res.statusCode, 400);
  assert.deepEqual(res.body, {error: 'invalid_branch_status'});
  assert.equal(queried, false);
});