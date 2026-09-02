const assert = require('node:assert/strict');
const test = require('node:test');

const registerRoutes = require('./src/routes/merchant-token-wallet');

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function handlers() {
  const routes = new Map();
  const app = {
    get() {},
    post(path, ...routeHandlers) { routes.set(path, routeHandlers.at(-1)); },
  };
  registerRoutes(app, {
    pool: {},
    auth(_req, _res, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
  });
  return routes;
}

test('legacy join endpoint cannot activate public coalition membership', async () => {
  const res = response();
  await handlers().get('/api/merchant/coalitions/join-public')({user: {userId: 'merchant-user'}, body: {}}, res);
  assert.equal(res.statusCode, 409);
  assert.equal(res.body.error, 'public_coalition_membership_workflow_required');
});

test('legacy internal top-up cannot activate membership', async () => {
  const res = response();
  await handlers().get('/api/merchant/token-wallet/top-up')({user: {userId: 'merchant-user'}, body: {amount: 100}}, res);
  assert.equal(res.statusCode, 410);
  assert.equal(res.body.error, 'public_coalition_external_payment_required');
});