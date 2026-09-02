const assert = require('node:assert/strict');
const test = require('node:test');

const registerRoutes = require('./src/routes/reward-funding');

function response() {
  return {statusCode: 200, body: null, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }};
}

function register(client, {brandId = 'brand-1', merchantId = null} = {}) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) { routes.set(`GET ${path}`, handlers.at(-1)); },
    post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); },
  };
  registerRoutes(app, {
    pool: {async connect() { return client; }},
    auth(_req, _res, next) { next(); },
    id() { return 'funding-id'; },
    async getBrandProfileIdByUser() { return brandId; },
    async getMerchantProfileIdByUser() { return merchantId; },
  });
  return routes;
}

test('brand moves wallet points into reward escrow atomically with one reference', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT balance FROM brand_token_wallets') && sql.includes('FOR UPDATE')) return {rows: [{balance: 200}]};
      if (sql.includes('SELECT id, balance FROM escrow_accounts')) return {rows: [{id: 'escrow-1', balance: 30}]};
      if (sql.includes('UPDATE escrow_accounts')) return {rows: [{id: 'escrow-1', balance: 130}], rowCount: 1};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const handler = register(client).get('POST /api/reward-funding/:sourceType/fund');
  const res = response();
  await handler({user: {userId: 'brand-user'}, params: {sourceType: 'brand'}, body: {amount: 100}}, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.reference, 'reward_funding:funding-id');
  assert.equal(res.body.walletBalance, 100);
  assert.equal(res.body.escrowBalance, 130);
  const ledger = queries.find(({sql}) => sql.includes('INSERT INTO brand_token_ledger'));
  assert.deepEqual(ledger.params, ['funding-id', 'brand-1', 'reward_funding:funding-id', -100, 100]);
  assert.equal(queries.at(-1).sql, 'COMMIT');
});

test('insufficient wallet balance cannot increase reward escrow', async () => {
  const queries = [];
  const client = {
    async query(sql) {
      queries.push(sql);
      if (sql.includes('SELECT balance FROM brand_token_wallets') && sql.includes('FOR UPDATE')) return {rows: [{balance: 20}]};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const handler = register(client).get('POST /api/reward-funding/:sourceType/fund');
  const res = response();
  await handler({user: {userId: 'brand-user'}, params: {sourceType: 'brand'}, body: {amount: 100}}, res);

  assert.equal(res.statusCode, 409);
  assert.deepEqual(res.body, {error: 'insufficient_reward_funding_balance'});
  assert.equal(queries.some((sql) => sql.includes('UPDATE escrow_accounts')), false);
  assert.equal(queries.at(-1), 'ROLLBACK');
});

test('customer cannot fund merchant or brand reward escrow', async () => {
  const queries = [];
  const client = {async query(sql) { queries.push(sql); return {rows: []}; }, release() {}};
  const handler = register(client, {brandId: null, merchantId: null}).get('POST /api/reward-funding/:sourceType/fund');
  const res = response();
  await handler({user: {userId: 'customer'}, params: {sourceType: 'brand'}, body: {amount: 10}}, res);

  assert.equal(res.statusCode, 403);
  assert.equal(queries.some((sql) => sql.includes('UPDATE brand_token_wallets')), false);
  assert.equal(queries.at(-1), 'ROLLBACK');
});