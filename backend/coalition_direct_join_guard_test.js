const assert = require('node:assert/strict');
const test = require('node:test');

const registerCoalitionRoutes = require('./src/routes/coalition');

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function register(pool) {
  const routes = new Map();
  const app = {};
  for (const method of ['get', 'post', 'put', 'patch', 'delete']) {
    app[method] = (path, ...handlers) => routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
  }
  registerCoalitionRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
    async getBrandProfileIdByUser() { return 'brand-1'; },
  });
  return routes;
}

test('merchant cannot join a public coalition through the generic join endpoint', async () => {
  const pool = {async query() { return {rows: [{id: 'public-platform-coalition', type: 'public', is_active: true}]}; }};
  const handler = register(pool).get('POST /api/merchant/coalitions/:id/join');
  const res = response();
  await handler({user: {userId: 'merchant-user'}, params: {id: 'public-platform-coalition'}}, res);
  assert.equal(res.statusCode, 409);
  assert.equal(res.body.error, 'public_coalition_membership_workflow_required');
});

test('brand cannot join a public coalition through the legacy join endpoint', async () => {
  let queried = false;
  const pool = {async query() { queried = true; return {rows: []}; }};
  const handler = register(pool).get('POST /api/brand/coalitions/:id/join');
  const res = response();
  await handler({user: {userId: 'brand-user'}, params: {id: 'public-platform-coalition'}}, res);
  assert.equal(res.statusCode, 409);
  assert.equal(res.body.error, 'public_coalition_membership_workflow_required');
  assert.equal(queried, false);
});

test('merchant can still join a private coalition with a pending invitation', async () => {
  const statements = [];
  const pool = {
    async query(sql) {
      statements.push(sql);
      if (sql.includes('SELECT * FROM coalitions')) return {rows: [{id: 'private-1', type: 'private', is_active: true}]};
      if (sql.includes('SELECT id FROM coalition_invitations')) return {rows: [{id: 'invitation-1'}]};
      return {rows: []};
    },
  };
  const handler = register(pool).get('POST /api/merchant/coalitions/:id/join');
  const res = response();
  await handler({user: {userId: 'merchant-user'}, params: {id: 'private-1'}}, res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, {ok: true});
  assert.equal(statements.some((sql) => sql.includes("SET status = 'accepted'")), true);
  assert.equal(statements.some((sql) => sql.includes('INSERT INTO coalition_members')), true);
});