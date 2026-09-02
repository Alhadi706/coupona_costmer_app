const assert = require('node:assert/strict');
const test = require('node:test');

const registerInvoicesRoutes = require('./src/routes/invoices');
const registerRewardsRoutes = require('./src/routes/rewards');

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

function routeCollector() {
  const routes = new Map();
  const app = {};
  for (const method of ['get', 'post', 'patch', 'delete', 'put']) {
    app[method] = (path, ...handlers) => {
      routes.set(`${method.toUpperCase()} ${path}`, handlers.at(-1));
    };
  }
  return {app, routes};
}

function registerProductRoutes({client, brandId = 'brand-1', poolQuery} = {}) {
  const {app, routes} = routeCollector();
  const pool = {
    async connect() {
      return client;
    },
    async query(sql, params) {
      if (poolQuery) return poolQuery(sql, params);
      return client.query(sql, params);
    },
  };
  const deps = {
    pool,
    auth(_req, _res, next) {
      next();
    },
    async getBrandProfileIdByUser() {
      return brandId;
    },
    async getManageableBrandProductId() {
      return brandId;
    },
    id() {
      return 'product-new';
    },
    toIso(value) {
      return value == null ? null : new Date(value).toISOString();
    },
  };
  registerInvoicesRoutes(app, deps);
  registerRewardsRoutes(app, deps);
  return routes;
}

test('brand product creation rejects a duplicate barcode within the same brand', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT id FROM product_registry')) {
        return {rows: [{id: 'product-existing'}]};
      }
      return {rows: []};
    },
    release() {},
  };
  const handler = registerProductRoutes({client}).get('POST /api/brand/products');
  const response = createResponse();

  await handler(
    {user: {userId: 'brand-user'}, body: {name: 'Product', barcode: 'ABC-123'}},
    response,
  );

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, {error: 'product_barcode_exists', productId: 'product-existing'});
  assert.equal(queries.some(({sql}) => sql.startsWith('INSERT INTO product_registry')), false);
  assert.equal(queries.some(({sql}) => sql === 'ROLLBACK'), true);
});

test('brand cannot update a product owned by another brand', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      return {rows: []};
    },
    release() {},
  };
  const handler = registerProductRoutes({client}).get('PATCH /api/brand/products/:id');
  const response = createResponse();

  await handler(
    {user: {userId: 'brand-user'}, params: {id: 'other-product'}, body: {name: 'Changed'}},
    response,
  );

  assert.equal(response.statusCode, 404);
  assert.deepEqual(response.body, {error: 'product_not_found'});
  const ownershipCheck = queries.find(({sql}) => sql.includes('FROM product_registry') && sql.includes('FOR UPDATE'));
  assert.deepEqual(ownershipCheck.params, ['other-product', 'brand-1']);
  assert.equal(queries.some(({sql}) => sql.includes('UPDATE product_registry')), false);
  assert.equal(queries.some(({sql}) => sql === 'ROLLBACK'), true);
});

test('deactivation is scoped to the brand and preserves the product row', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM product_registry') && sql.includes('FOR UPDATE')) {
        return {rows: [{id: 'product-1', name: 'Product', image_url: null, barcode: 'ABC', is_active: true}]};
      }
      return {rows: []};
    },
    release() {},
  };
  const routes = registerProductRoutes({client});
  const response = createResponse();

  await routes.get('DELETE /api/brand/products/:id')(
    {user: {userId: 'brand-user'}, params: {id: 'product-1'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {ok: true, id: 'product-1', isActive: false});
  const updateQuery = queries.find(({sql}) => sql.includes('UPDATE product_registry'));
  assert.match(updateQuery.sql, /SET is_active = FALSE/);
  assert.match(updateQuery.sql, /brand_id = \$2/);
  assert.doesNotMatch(updateQuery.sql, /DELETE FROM product_registry/);
  assert.deepEqual(updateQuery.params, ['product-1', 'brand-1']);
  const auditQuery = queries.find(({sql}) => sql.includes('INSERT INTO brand_product_audit_logs'));
  assert.match(auditQuery.sql, /'deactivated'/);
  assert.equal(JSON.parse(auditQuery.params[4]).isActive, true);
  assert.equal(JSON.parse(auditQuery.params[5]).isActive, false);
  assert.equal(queries.some(({sql}) => sql === 'COMMIT'), true);
});

test('user without product permission cannot mutate brand products', async () => {
  let queryRan = false;
  const client = {
    async query() {
      queryRan = true;
      return {rows: []};
    },
    release() {},
  };
  const handler = registerProductRoutes({client, brandId: null}).get('PATCH /api/brand/products/:id');
  const response = createResponse();

  await handler(
    {user: {userId: 'customer-user'}, params: {id: 'product-1'}, body: {name: 'Changed'}},
    response,
  );

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, {error: 'brand_product_permission_required'});
  assert.equal(queryRan, false);
});

test('delegated brand team member with product permission can create products', async () => {
  let inserted = false;
  const client = {
    async query(sql) {
      if (sql.includes('SELECT id FROM product_registry')) return {rows: []};
      if (sql.startsWith('INSERT INTO product_registry')) inserted = true;
      return {rows: []};
    },
    release() {},
  };
  const handler = registerProductRoutes({client, brandId: 'delegated-brand'}).get('POST /api/brand/products');
  const response = createResponse();

  await handler(
    {user: {userId: 'team-member'}, body: {name: 'Delegated Product', barcode: 'TEAM-1'}},
    response,
  );

  assert.equal(response.statusCode, 201);
  assert.equal(inserted, true);
});

test('brand reward inventory update is scoped and cannot drop below redeemed quantity', async () => {
  let captured;
  const client = {
    async query(sql, params) {
      if (sql.includes('UPDATE rewards')) {
        captured = {sql, params};
        return {rows: [], rowCount: 0};
      }
      return {rows: []};
    },
    release() {},
  };
  const handler = registerProductRoutes({client}).get('PATCH /api/brand/rewards/:id');
  const response = createResponse();

  await handler(
    {user: {userId: 'brand-user'}, params: {id: 'reward-1'}, body: {quantityLimit: 2}},
    response,
  );

  assert.equal(response.statusCode, 404);
  assert.deepEqual(response.body, {error: 'reward_not_found_or_quantity_below_redeemed'});
  assert.match(captured.sql, /source_type = 'brand'/);
  assert.match(captured.sql, /source_id = \$6/);
  assert.match(captured.sql, /\$2::int >= quantity_redeemed/);
  assert.deepEqual(captured.params.slice(-2), ['reward-1', 'brand-1']);
});
