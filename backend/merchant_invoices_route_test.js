const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'merchant-invoice-route-test-secret';
process.env.PGPASSWORD ||= 'merchant-invoice-route-test-password';

const registerInvoicesRoutes = require('./src/routes/invoices');
const {canManageInvoice} = require('./src/access-control');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

function registerHandler({client, merchantId}) {
  const routes = new Map();
  const app = {
    get(path, _auth, handler) {
      routes.set(`GET ${path}`, handler);
    },
    post() {},
  };
  registerInvoicesRoutes(app, {
    pool: {
      async connect() {
        return client;
      },
    },
    auth(_req, _res, next) {
      next();
    },
    async getMerchantProfileIdByUser() {
      return merchantId;
    },
    toIso(value) {
      return value == null ? null : new Date(value).toISOString();
    },
  });
  return routes.get('GET /api/merchant/invoices');
}

test('merchant owner invoice queue is scoped by merchant profile', async () => {
  let invoiceQuery;
  const client = {
    async query(sql, params) {
      invoiceQuery = {sql, params};
      return {
        rows: [{
          id: 'invoice-1',
          merchant_profile_id: 'merchant-1',
          state: 'processing',
          created_at: '2026-09-01T00:00:00Z',
        }],
      };
    },
    release() {},
  };
  const handler = registerHandler({client, merchantId: 'merchant-1'});
  const response = createResponse();

  await handler(
    {user: {userId: 'merchant-user'}, query: {state: 'processing'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.reviewerRole, 'merchant_owner');
  assert.equal(response.body.invoices.length, 1);
  assert.match(invoiceQuery.sql, /s\.merchant_profile_id = \$1/);
  assert.deepEqual(invoiceQuery.params, ['merchant-1', 'processing', 100]);
});

test('delegated manager invoice queue is scoped by assigned branch ids', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM branch_manager_permissions')) {
        return {rows: [{branch_id: 'branch-1'}]};
      }
      return {
        rows: [{
          id: 'invoice-1',
          branch_id: 'branch-1',
          state: 'processing',
          created_at: '2026-09-01T00:00:00Z',
        }],
      };
    },
    release() {},
  };
  const handler = registerHandler({client, merchantId: null});
  const response = createResponse();

  await handler(
    {user: {userId: 'manager-user'}, query: {state: 'all', limit: '20'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.reviewerRole, 'manager');
  assert.match(queries[1].sql, /s\.branch_id = ANY\(\$1::text\[\]\)/);
  assert.deepEqual(queries[1].params, [['branch-1'], 20]);
});

test('user without merchant ownership or review permission is denied', async () => {
  let invoiceQueryRan = false;
  const client = {
    async query(sql) {
      if (sql.includes('FROM branch_manager_permissions')) return {rows: []};
      invoiceQueryRan = true;
      return {rows: []};
    },
    release() {},
  };
  const handler = registerHandler({client, merchantId: null});
  const response = createResponse();

  await handler(
    {user: {userId: 'customer-user'}, query: {}},
    response,
  );

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, {error: 'merchant_invoice_review_permission_required'});
  assert.equal(invoiceQueryRan, false);
});

test('invalid limit falls back to the bounded default', async () => {
  let invoiceParams;
  const client = {
    async query(_sql, params) {
      invoiceParams = params;
      return {rows: []};
    },
    release() {},
  };
  const handler = registerHandler({client, merchantId: 'merchant-1'});
  const response = createResponse();

  await handler(
    {user: {userId: 'merchant-user'}, query: {limit: 'not-a-number'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(invoiceParams, ['merchant-1', 100]);
});

test('delegated manager can transition invoices only in an assigned branch', async () => {
  function clientForBranch(assignedBranchId) {
    return {
      async query(sql, params) {
        if (sql.includes('FROM invoice_scans')) {
          return {
            rows: [{
              owner_id: 'customer-1',
              merchant_profile_id: 'merchant-1',
              branch_id: 'branch-1',
              state: 'processing',
            }],
          };
        }
        if (sql.includes('FROM branch_manager_permissions')) {
          return {rows: params[1] === assignedBranchId ? [{'?column?': 1}] : []};
        }
        return {rows: []};
      },
    };
  }
  const user = {userId: 'manager-user'};
  const noMerchantProfile = async () => null;

  const allowed = await canManageInvoice(
    clientForBranch('branch-1'),
    user,
    'invoice-1',
    'approved',
    noMerchantProfile,
  );
  const denied = await canManageInvoice(
    clientForBranch('branch-2'),
    user,
    'invoice-1',
    'approved',
    noMerchantProfile,
  );

  assert.equal(allowed.allowed, true);
  assert.deepEqual(denied, {allowed: false, status: 403, error: 'forbidden'});
});