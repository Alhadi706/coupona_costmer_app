const assert = require('node:assert/strict');
const test = require('node:test');

const registerBrandTeamRoutes = require('./src/routes/brand-team');

function response() {
  return {statusCode: 200, body: null, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; return this; }};
}

function routesFor(client, notifications = []) {
  const routes = new Map();
  const app = {};
  for (const method of ['get', 'post', 'delete']) app[method] = (path, ...handlers) => routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
  registerBrandTeamRoutes(app, {
    pool: {async connect() { return client; }, async query(sql, params) { return client.query(sql, params); }},
    auth(_req, _res, next) { next(); },
    id() { return 'invitation-1'; },
    toIso(value) { return value == null ? null : new Date(value).toISOString(); },
    async getBrandProfileIdByUser() { return 'brand-1'; },
    async insertNotification(_client, userId, type, title, body, payload) { notifications.push({userId, type, title, body, payload}); },
  });
  return routes;
}

test('brand invitation stores least-privilege permissions and notifies the user', async () => {
  const notifications = [];
  let invitationInsert;
  const client = {
    async query(sql, params) {
      if (sql.includes('FROM users WHERE')) return {rows: [{id: 'user-2', email: 'user@example.com'}]};
      if (sql.includes('FROM brand_team_invitations')) return {rows: []};
      if (sql.includes('INSERT INTO brand_team_invitations')) {
        invitationInsert = params;
        return {rows: [{id: 'invitation-1', permissions: JSON.parse(params[4]), created_at: new Date()}]};
      }
      return {rows: []};
    },
    release() {},
  };
  const res = response();

  await routesFor(client, notifications).get('POST /api/brand/team/invitations')(
    {user: {userId: 'brand-owner'}, body: {emailOrPhone: 'user@example.com', permissions: {canManageProducts: true}}},
    res,
  );

  assert.equal(res.statusCode, 201);
  assert.deepEqual(JSON.parse(invitationInsert[4]), {canManageProducts: true, canViewGeoDistribution: false});
  assert.equal(notifications[0].userId, 'user-2');
});

test('accepting a brand invitation atomically grants only invited permissions', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT * FROM brand_team_invitations')) {
        return {rows: [{id: 'invitation-1', brand_id: 'brand-1', invited_user_id: 'user-2', invited_by_user_id: 'brand-owner', permissions: {canManageProducts: false, canViewGeoDistribution: true}}]};
      }
      return {rows: []};
    },
    release() {},
  };
  const res = response();

  await routesFor(client).get('POST /api/brand/team/invitations/:id/respond')(
    {user: {userId: 'user-2'}, params: {id: 'invitation-1'}, body: {action: 'accept'}},
    res,
  );

  assert.equal(res.statusCode, 200);
  const grant = queries.find(({sql}) => sql.includes('INSERT INTO brand_team_members'));
  assert.deepEqual(grant.params, ['brand-1', 'user-2', false, true]);
  assert.equal(queries.some(({sql}) => sql === 'COMMIT'), true);
});

test('rejecting a brand invitation does not grant team access', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT * FROM brand_team_invitations')) return {rows: [{id: 'invitation-1', brand_id: 'brand-1', invited_user_id: 'user-2', invited_by_user_id: 'brand-owner', permissions: {canManageProducts: true}}]};
      return {rows: []};
    },
    release() {},
  };
  const res = response();

  await routesFor(client).get('POST /api/brand/team/invitations/:id/respond')(
    {user: {userId: 'user-2'}, params: {id: 'invitation-1'}, body: {action: 'reject'}},
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(queries.some(({sql}) => sql.includes('INSERT INTO brand_team_members')), false);
});
