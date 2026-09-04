const assert = require('node:assert/strict');
const test = require('node:test');

const registerCampaignRoutes = require('./src/routes/campaigns');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function createHandlers(client) {
  const handlers = new Map();
  const app = {
    get(path, ...routeHandlers) { handlers.set(`GET ${path}`, routeHandlers.at(-1)); },
    post(path, ...routeHandlers) { handlers.set(`POST ${path}`, routeHandlers.at(-1)); },
    patch(path, ...routeHandlers) { handlers.set(`PATCH ${path}`, routeHandlers.at(-1)); },
  };
  registerCampaignRoutes(app, {
    pool: {
      async connect() { return client; },
      async query(sql, params) { return client.query(sql, params); },
    },
    auth(_req, _res, next) { next(); },
    async getMerchantProfileIdByUser() { return 'merchant-1'; },
    async getBrandProfileIdByUser() { return null; },
    async getBrandIdWithPermission() { return null; },
    async insertNotification() {},
    toIso(value) { return value == null ? null : new Date(value).toISOString(); },
  });
  return handlers;
}

test('legacy campaign endpoint no longer creates free gift campaigns', async () => {
  const client = {
    async query() { return { rows: [{ business_name: 'Merchant' }] }; },
    release() {},
  };
  const response = createResponse();

  await createHandlers(client).get('POST /api/campaigns')({
    user: { userId: 'merchant-user' },
    body: { campaignType: 'free_gift' },
  }, response);

  assert.equal(response.statusCode, 400);
  assert.deepEqual(response.body, { error: 'invalid_campaign_type' });
});

test('legacy campaign launch refuses gift engine campaigns', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({ sql, params });
      if (sql.includes('SELECT business_name FROM merchant_profiles')) return { rows: [{ business_name: 'Merchant' }] };
      if (sql === 'BEGIN' || sql === 'ROLLBACK') return { rows: [] };
      if (sql.includes('SELECT id, campaign_type, gift_definition_id FROM promo_campaigns')) {
        return { rows: [{ id: 'campaign-1', campaign_type: 'free_gift', gift_definition_id: 'gift-1' }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const response = createResponse();

  await createHandlers(client).get('POST /api/campaigns/:id/launch')({
    params: { id: 'campaign-1' },
    user: { userId: 'merchant-user' },
    body: {},
  }, response);

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, { error: 'use_gift_engine' });
  assert.equal(queries.at(-1).sql, 'ROLLBACK');
});