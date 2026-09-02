const assert = require('node:assert/strict');
const test = require('node:test');

const registerRoutes = require('./src/routes/merchant-team');

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function register({pool, merchantId = 'merchant-1', notifications = []}) {
  const routes = new Map();
  const app = {};
  for (const method of ['get', 'post', 'delete']) {
    app[method] = (path, ...handlers) => routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
  }
  registerRoutes(app, {
    pool,
    auth(_req, _res, next) { next(); },
    id() { return 'generated-id'; },
    toIso(value) { return value || null; },
    async getMerchantProfileIdByUser() { return merchantId; },
    async assertMerchantSubscriptionWritable() {},
    isMerchantSubscriptionReadOnlyError() { return false; },
    async insertNotification(...args) { notifications.push(args); },
  });
  return routes;
}

test('creating an invitation does not grant branch access before acceptance', async () => {
  const statements = [];
  const notifications = [];
  const client = {
    async query(sql, params) {
      statements.push({sql, params});
      if (sql.includes('FROM branches')) return {rows: [{id: 'branch-1', name: 'Main'}]};
      if (sql.includes('FROM users')) return {rows: [{id: 'user-2', email: 'staff@example.com'}]};
      if (sql.includes("status = 'pending'")) return {rows: []};
      if (sql.includes('INSERT INTO merchant_team_invitations')) return {rows: [{
        id: 'invite-1', merchant_id: 'merchant-1', branch_id: 'branch-1',
        invited_user_id: 'user-2', role_type: 'manager', status: 'pending',
        permissions: {canReviewInvoices: true},
      }]};
      return {rows: []};
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool, notifications}).get('POST /api/merchant/team/invitations');
  const res = response();
  await handler({
    user: {userId: 'merchant-owner'},
    body: {branchId: 'branch-1', roleType: 'manager', emailOrPhone: 'staff@example.com', permissions: {canReviewInvoices: true}},
  }, res);

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.status, 'pending');
  assert.equal(statements.some(({sql}) => sql.includes('INSERT INTO branch_manager_permissions')), false);
  assert.equal(statements.some(({sql}) => sql.includes('INSERT INTO cashier_profiles')), false);
  assert.equal(notifications.length, 1);
});

test('accepting a manager invitation applies only the invited permissions', async () => {
  const statements = [];
  const notifications = [];
  const client = {
    async query(sql, params) {
      statements.push({sql, params});
      if (sql.includes('SELECT * FROM merchant_team_invitations')) return {rows: [{
        id: 'invite-1', merchant_id: 'merchant-1', branch_id: 'branch-1',
        invited_user_id: 'manager-user', invited_by_user_id: 'owner-user',
        role_type: 'manager', status: 'pending',
        permissions: {canReviewInvoices: true, canCreateOffers: false, canViewReports: true},
      }]};
      return {rows: []};
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool, notifications}).get('POST /api/team/invitations/:id/respond');
  const res = response();
  await handler({user: {userId: 'manager-user'}, params: {id: 'invite-1'}, body: {action: 'accept'}}, res);

  assert.equal(res.body.status, 'accepted');
  const grant = statements.find(({sql}) => sql.includes('INSERT INTO branch_manager_permissions'));
  assert.ok(grant);
  assert.equal(grant.params[0], 'branch-1');
  assert.equal(grant.params[1], 'manager-user');
  assert.equal(grant.params[2], true);
  assert.equal(grant.params[3], false);
  assert.equal(grant.params[5], true);
  assert.equal(statements.at(-1).sql, 'COMMIT');
});

test('rejecting an invitation creates no manager or cashier access', async () => {
  const statements = [];
  const client = {
    async query(sql) {
      statements.push(sql);
      if (sql.includes('SELECT * FROM merchant_team_invitations')) return {rows: [{
        id: 'invite-1', merchant_id: 'merchant-1', branch_id: 'branch-1',
        invited_user_id: 'staff-user', invited_by_user_id: 'owner-user',
        role_type: 'cashier', status: 'pending', permissions: {},
      }]};
      return {rows: []};
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool}).get('POST /api/team/invitations/:id/respond');
  const res = response();
  await handler({user: {userId: 'staff-user'}, params: {id: 'invite-1'}, body: {action: 'reject'}}, res);

  assert.equal(res.body.status, 'rejected');
  assert.equal(statements.some((sql) => sql.includes('INSERT INTO branch_manager_permissions')), false);
  assert.equal(statements.some((sql) => sql.includes('INSERT INTO cashier_profiles')), false);
});

test('merchant owner revokes cashier access only through an owned branch', async () => {
  const statements = [];
  const client = {
    async query(sql, params) {
      statements.push({sql, params});
      if (sql.includes('SELECT id FROM branches')) return {rows: [{id: 'branch-1'}]};
      return {rows: []};
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool}).get('DELETE /api/merchant/team/:roleType/:branchId/:userId');
  const res = response();
  await handler({
    user: {userId: 'owner-user'},
    params: {roleType: 'cashier', branchId: 'branch-1', userId: 'cashier-user'},
  }, res);

  assert.equal(res.body.revoked, true);
  const revoke = statements.find(({sql}) => sql.includes('UPDATE cashier_profiles SET is_active = FALSE'));
  assert.deepEqual(revoke.params, ['branch-1', 'cashier-user', 'merchant-1']);
});

test('merchant owner can cancel only a pending invitation in their merchant', async () => {
  const notifications = [];
  let updateParams;
  const client = {
    async query(sql, params) {
      if (sql.includes('UPDATE merchant_team_invitations')) {
        updateParams = params;
        return {rows: [{invited_user_id: 'staff-user', branch_id: 'branch-1', role_type: 'manager'}]};
      }
      return {rows: []};
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool, notifications}).get('DELETE /api/merchant/team/invitations/:id');
  const res = response();
  await handler({user: {userId: 'owner-user'}, params: {id: 'invite-1'}}, res);

  assert.deepEqual(updateParams, ['invite-1', 'merchant-1']);
  assert.deepEqual(res.body, {ok: true, status: 'cancelled'});
  assert.equal(notifications.length, 1);
  assert.equal(notifications[0][1], 'staff-user');
});

test('inactive branch cannot receive a new team invitation', async () => {
  const client = {
    async query(sql) {
      if (sql.includes('FROM branches')) return {rows: []};
      throw new Error('invitation lookup must stop when branch is inactive');
    },
    release() {},
  };
  const pool = {async connect() { return client; }};
  const handler = register({pool}).get('POST /api/merchant/team/invitations');
  const res = response();
  await handler({
    user: {userId: 'owner-user'},
    body: {branchId: 'inactive-branch', roleType: 'manager', emailOrPhone: 'staff@example.com'},
  }, res);

  assert.equal(res.statusCode, 404);
  assert.deepEqual(res.body, {error: 'branch_not_found'});
});