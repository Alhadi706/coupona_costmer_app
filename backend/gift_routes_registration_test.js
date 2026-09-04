const assert = require('node:assert/strict');
const test = require('node:test');

const registerGiftRoutes = require('./src/routes/gifts');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function createGiftHandlers(deps) {
  const handlers = new Map();
  const app = {
    get(path, ...routeHandlers) { handlers.set(`GET ${path}`, routeHandlers.at(-1)); },
    post(path, ...routeHandlers) { handlers.set(`POST ${path}`, routeHandlers.at(-1)); },
  };
  const noop = async () => null;

  registerGiftRoutes(app, {
    pool: {},
    auth(_req, _res, next) { next(); },
    id() { return 'id'; },
    toIso(value) { return value == null ? null : new Date(value).toISOString(); },
    getMerchantProfileIdByUser: noop,
    getBrandProfileIdByUser: noop,
    getBrandIdWithPermission: noop,
    insertNotification: noop,
    ...deps,
  });

  return handlers;
}

test('gift routes register the backend foundation endpoints', () => {
  const routes = new Set();
  const app = {
    get(path) { routes.add(`GET ${path}`); },
    post(path) { routes.add(`POST ${path}`); },
  };
  const noop = async () => null;

  registerGiftRoutes(app, {
    pool: {},
    auth(_req, _res, next) { next(); },
    id() { return 'id'; },
    toIso(value) { return value == null ? null : new Date(value).toISOString(); },
    getMerchantProfileIdByUser: noop,
    getBrandProfileIdByUser: noop,
    getBrandIdWithPermission: noop,
    insertNotification: noop,
  });

  assert.deepEqual([...routes].sort(), [
    'GET /api/customer/gifts/assignments',
    'GET /api/gifts/analytics/mine',
    'GET /api/gifts/definitions/mine',
    'POST /api/cashier/gifts/redeem',
    'POST /api/cashier/gifts/redemptions/:id/reverse',
    'POST /api/cashier/gifts/verify',
    'POST /api/customer/gifts/assignments/:id/claim',
    'POST /api/customer/gifts/assignments/:id/view',
    'POST /api/gifts/definitions',
    'POST /api/gifts/definitions/:id/campaigns/launch',
  ]);
});

test('merchant gift definition list is scoped by merchant source only', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({ sql, params });
      if (sql.includes('SELECT * FROM gift_definitions')) {
        return { rows: [{ id: 'gift-1', gift_type: 'VOUCHER', title: 'Gift', status: 'ACTIVE', created_at: new Date() }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const handlers = createGiftHandlers({
    pool: { async connect() { return client; } },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
  });
  const response = createResponse();

  await handlers.get('GET /api/gifts/definitions/mine')({ user: { userId: 'merchant-user' } }, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.gifts.length, 1);
  const listQuery = queries.find(({ sql }) => sql.includes('SELECT * FROM gift_definitions'));
  assert.match(listQuery.sql, /WHERE source_merchant_id = \$1/);
  assert.doesNotMatch(listQuery.sql, /source_brand_id IS NOT DISTINCT FROM/);
  assert.deepEqual(listQuery.params, ['merchant-1']);
});