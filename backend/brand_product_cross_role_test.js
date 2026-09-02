const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'brand-cross-role-test-secret';
process.env.PGPASSWORD ||= 'brand-cross-role-test-password';

const registerAnalyticsRoutes = require('./src/routes/analytics');
const matching = require('./src/services-matching');

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

function analyticsHandlers(client) {
  const routes = new Map();
  const app = {
    get(path, _auth, handler) {
      routes.set(path, handler);
    },
  };
  registerAnalyticsRoutes(app, {
    pool: {
      async connect() {
        return client;
      },
    },
    auth(_req, _res, next) {
      next();
    },
    async getMerchantProfileIdByUser(_client, userId) {
      return userId === 'merchant-user' ? 'merchant-1' : null;
    },
    async getBrandProfileIdByUser(_client, userId) {
      return userId === 'brand-user' ? 'brand-1' : null;
    },
    analyticsRangeDays: matching.analyticsRangeDays,
    analyticsDaysAgo: matching.analyticsDaysAgo,
    analyticsSafeNumber: matching.analyticsSafeNumber,
    analyticsPercentChange: matching.analyticsPercentChange,
    analyticsAgeBucket: matching.analyticsAgeBucket,
    analyticsCountEntries: matching.analyticsCountEntries,
    analyticsTopEntries: matching.analyticsTopEntries,
  });
  return routes;
}

test('active product matches customer invoice while inactive products are excluded', async () => {
  let querySql = '';
  const client = {
    async query(sql) {
      querySql = sql;
      return {
        rows: [
          {product_id: 'active-product', brand_id: 'brand-1', name: 'منتج مترابط'},
        ],
      };
    },
  };

  const matched = await matching.autoMatchLineItemToBrand(client, 'عبوة منتج مترابط 500 مل');

  assert.deepEqual(matched, {brandId: 'brand-1', productId: 'active-product', matchLength: 'منتج مترابط'.length});
  assert.match(querySql, /WHERE pr\.is_active = TRUE/);
});

test('one approved customer invoice feeds merchant and brand product analytics without exposing customer identity', async () => {
  const now = new Date().toISOString();
  const matchedInvoiceRow = {
    owner_id: 'customer-1',
    created_at: now,
    merchant_profile_id: 'merchant-1',
    merchant_name: 'متجر مترابط',
    merchant_user_id: 'merchant-user',
    merchant_phone: '000',
    merchant_address: 'Tripoli',
    location_lat: 32.8872,
    location_lng: 13.1913,
    product_id: 'active-product',
    product_name: 'منتج مترابط',
    quantity: 2,
    line_total: 125,
    gender: 'unknown',
    birth_date: null,
  };
  const client = {
    async query(sql) {
      if (sql.includes('FROM merchant_profiles') && sql.includes('point_value')) {
        return {rows: [{id: 'merchant-1', business_name: 'متجر مترابط', point_value: 5}]};
      }
      if (sql.includes('COALESCE(pr.name, li.item_name') && sql.includes('GROUP BY')) {
        return {rows: [{product_name: 'منتج مترابط', brand_name: 'علامة مترابطة', sales_total: 125, quantity_total: 2}]};
      }
      if (sql.includes('FROM points_ledger_brand')) return {rows: [{total: 1000}]};
      if (sql.includes('FROM reward_claims')) return {rows: [{claims_count: 3, redeemed_points: 250}]};
      if (sql.includes('FROM brand_matches bm')) return {rows: [matchedInvoiceRow]};
      return {rows: []};
    },
    release() {},
  };
  const routes = analyticsHandlers(client);
  const merchantResponse = createResponse();
  const brandResponse = createResponse();

  await routes.get('/api/merchant/analytics')(
    {user: {userId: 'merchant-user'}, query: {range: '30d'}},
    merchantResponse,
  );
  await routes.get('/api/brand/analytics')(
    {user: {userId: 'brand-user'}, query: {range: '30d', storeId: 'merchant-1', product: 'active-product', region: 'Tripoli'}},
    brandResponse,
  );

  assert.equal(merchantResponse.statusCode, 200);
  assert.deepEqual(merchantResponse.body.topBrandProducts[0], {
    name: 'منتج مترابط',
    brandName: 'علامة مترابطة',
    salesTotal: 125,
    quantity: 2,
  });
  assert.equal(brandResponse.statusCode, 200);
  assert.equal(brandResponse.body.matchedSales, 125);
  assert.equal(brandResponse.body.matchedCustomers, 1);
  assert.equal(brandResponse.body.topProducts[0].name, 'منتج مترابط');
  assert.equal(brandResponse.body.pointsIssued, 1000);
  assert.equal(brandResponse.body.rewardClaims, 3);
  assert.equal(brandResponse.body.pointsRedeemed, 250);
  assert.equal(brandResponse.body.redemptionRate, 25);
  assert.deepEqual(brandResponse.body.appliedFilters, {storeId: 'merchant-1', product: 'active-product', region: 'tripoli'});
  assert.deepEqual(brandResponse.body.filterOptions.stores, [{value: 'merchant-1', label: 'متجر مترابط'}]);
  assert.equal(brandResponse.body.demographicsSuppressed, true);
  assert.deepEqual(brandResponse.body.consumerDemographics, {gender: [], ageBuckets: []});
  assert.equal(JSON.stringify(brandResponse.body).includes('customer-1'), false);

  const excludedResponse = createResponse();
  await routes.get('/api/brand/analytics')(
    {user: {userId: 'brand-user'}, query: {range: '30d', storeId: 'different-store'}},
    excludedResponse,
  );
  assert.equal(excludedResponse.body.matchedSales, 0);
  assert.equal(excludedResponse.body.matchedCustomers, 0);
  assert.deepEqual(excludedResponse.body.filterOptions.stores, [{value: 'merchant-1', label: 'متجر مترابط'}]);
});
