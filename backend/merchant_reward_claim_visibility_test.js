const assert = require('node:assert/strict');
const test = require('node:test');

const registerRewardsRoutes = require('./src/routes/rewards');

function response() {
  return {statusCode: 200, body: null, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }};
}

test('merchant reward claims are scoped to the authenticated merchant and expose one reference', async () => {
  let queryParams;
  let querySql;
  const routes = new Map();
  const app = {};
  for (const method of ['get', 'post', 'patch', 'delete', 'put']) {
    app[method] = (path, ...handlers) => routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
  }
  const pool = {
    async query(sql, params) {
      querySql = sql;
      queryParams = params;
      return {rows: [{
        id: 'claim-1', reward_id: 'reward-1', reward_name: 'Merchant Gift', points_cost: 75,
        reward_kind: 'physical', status: 'redeemed', settlement_id: 'settlement-1',
        created_at: '2026-09-02T00:00:00Z',
      }]};
    },
  };
  registerRewardsRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    requireAdmin(_req, _res, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
    toIso(value) { return value || null; },
  });
  const handler = routes.get('GET /api/merchant/reward-claims');
  const res = response();
  await handler({user: {userId: 'merchant-user'}}, res);

  assert.match(querySql, /rc\.source_type = 'merchant' AND rc\.source_id = \$1/);
  assert.deepEqual(queryParams, ['merchant-1']);
  assert.equal(res.body[0].reference, 'reward_claim:claim-1');
  assert.equal(res.body[0].settlementId, 'settlement-1');
});