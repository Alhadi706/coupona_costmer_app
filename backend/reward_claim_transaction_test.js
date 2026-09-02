const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'reward-claim-transaction-test-secret';
process.env.PGPASSWORD ||= 'reward-claim-transaction-test-password';

const registerExchangeRewardsRoutes = require('./src/routes/exchange-rewards');
const { canRedeemClaim } = require('./src/access-control');

function createResponse() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function exchangeHandlers(client, overrides = {}) {
  const routes = new Map();
  const app = {
    post(path, ...handlers) { routes.set(`POST ${path}`, handlers.at(-1)); },
    get(path, ...handlers) { routes.set(`GET ${path}`, handlers.at(-1)); },
  };
  registerExchangeRewardsRoutes(app, {
    pool: {async connect() { return client; }, async query(sql, params) { return client.query(sql, params); }},
    auth(_req, _res, next) { next(); },
    requireAdmin(_req, _res, next) { next(); },
    id() { return 'new-id'; },
    toIso(value) { return value == null ? null : new Date(value).toISOString(); },
    ...overrides,
  });
  return routes;
}

function claimCreateHandler(client) {
  return exchangeHandlers(client).get('POST /api/reward-claims/create');
}

test('claim creation replay returns the original claim without another debit or inventory change', async () => {
  const queries = [];
  const expiry = new Date(Date.now() + 60000);
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reward_claims') && sql.includes('idempotency_key')) {
        return {rows: [{id: 'claim-existing', pickup_qr_code: 'QR-1', digital_code: null, status: 'pending_pickup', expires_at: expiry}]};
      }
      return {rows: []};
    },
    release() {},
  };
  const response = createResponse();

  await claimCreateHandler(client)(
    {user: {userId: 'customer-1'}, body: {pointsCost: 100, rewardId: 'reward-1', idempotencyKey: 'request-1'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.id, 'claim-existing');
  assert.equal(response.body.idempotentReplay, true);
  assert.equal(queries.some(({sql}) => sql.includes('UPDATE rewards')), false);
  assert.equal(queries.some(({sql}) => sql.includes('UPDATE point_accounts')), false);
  assert.equal(queries.filter(({sql}) => sql === 'COMMIT').length, 1);
});

test('cashier in a coalition shared with the brand can fulfill its physical reward', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('UNION ALL')) return {rows: [{merchant_id: 'merchant-1'}]};
      if (sql.includes('FROM brand_coalition_members')) return {rows: [{'?column?': 1}]};
      return {rows: []};
    },
  };

  const allowed = await canRedeemClaim(client, {userId: 'cashier-1'}, {source_type: 'brand', source_id: 'brand-1'});

  assert.equal(allowed, true);
  assert.deepEqual(queries.at(-1).params, ['brand-1', 'merchant-1']);
});

test('cashier without a shared coalition cannot fulfill a brand reward', async () => {
  const client = {
    async query(sql) {
      if (sql.includes('UNION ALL')) return {rows: [{merchant_id: 'merchant-2'}]};
      return {rows: []};
    },
  };

  const allowed = await canRedeemClaim(client, {userId: 'cashier-2'}, {source_type: 'brand', source_id: 'brand-1'});

  assert.equal(allowed, false);
});

test('claim uses locked reward metadata and writes one unified customer ledger reference', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reward_claims') && sql.includes('idempotency_key')) return {rows: []};
      if (sql.includes('FROM rewards WHERE id')) return {rows: [{
        id: 'reward-1', value: 100, kind: 'physical', source_type: 'brand', source_id: 'brand-1',
        is_active: true, quantity_limit: 10, quantity_redeemed: 0, expires_at: null, draw_enabled: false,
      }]};
      if (sql.includes('SELECT available_points')) return {rows: [{available_points: 500}]};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const response = createResponse();

  await claimCreateHandler(client)(
    {user: {userId: 'customer-1'}, body: {
      pointsCost: 100, rewardId: 'reward-1', idempotencyKey: 'request-1',
      sourceType: 'merchant', sourceId: 'forged-merchant', rewardKind: 'digital',
    }},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.status, 'pending_pickup');
  assert.equal(response.body.reference, 'reward_claim:new-id');
  const claimInsert = queries.find(({sql}) => sql.includes('INSERT INTO reward_claims'));
  assert.equal(claimInsert.params[3], 'brand');
  assert.equal(claimInsert.params[4], 'brand-1');
  assert.equal(claimInsert.params[6], 'physical');
  const ledgerInsert = queries.find(({sql}) => sql.includes('INSERT INTO ledger_entries'));
  assert.deepEqual(ledgerInsert.params, ['new-id', 'customer-1', -100, 'reward_claim:new-id']);
});

test('concurrent idempotency conflict returns the committed original claim', async () => {
  const queries = [];
  let postRollbackLookup = false;
  const expiry = new Date(Date.now() + 60000);
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql === 'ROLLBACK') { postRollbackLookup = true; return {rows: []}; }
      if (sql.includes('FROM reward_claims') && sql.includes('idempotency_key')) {
        return postRollbackLookup
            ? {rows: [{id: 'claim-winner', pickup_qr_code: 'QR-WIN', digital_code: null, status: 'pending_pickup', expires_at: expiry}]}
            : {rows: []};
      }
      if (sql.includes('FROM rewards WHERE id')) return {rows: [{
        id: 'reward-1', value: 100, kind: 'physical', source_type: 'merchant', source_id: 'merchant-1',
        is_active: true, quantity_limit: null, quantity_redeemed: 0, expires_at: null, draw_enabled: false,
      }]};
      if (sql.includes('SELECT available_points')) return {rows: [{available_points: 500}]};
      if (sql.includes('INSERT INTO reward_claims')) {
        const error = new Error('duplicate idempotency key');
        error.code = '23505';
        throw error;
      }
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const response = createResponse();

  await claimCreateHandler(client)(
    {user: {userId: 'customer-1'}, body: {pointsCost: 100, rewardId: 'reward-1', idempotencyKey: 'same-request'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.id, 'claim-winner');
  assert.equal(response.body.reference, 'reward_claim:claim-winner');
  assert.equal(response.body.idempotentReplay, true);
  assert.equal(queries.filter(({sql}) => sql.includes('UPDATE point_accounts')).length, 0);
});

test('digital reward usage immediately debits source escrow and records settlement', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reward_claims') && sql.includes('idempotency_key')) return {rows: []};
      if (sql.includes('FROM rewards WHERE id')) return {rows: [{
        id: 'reward-digital', value: 40, kind: 'digital', source_type: 'brand', source_id: 'brand-1',
        is_active: true, quantity_limit: 5, quantity_redeemed: 0, expires_at: null, draw_enabled: false,
      }]};
      if (sql.includes('SELECT available_points')) return {rows: [{available_points: 100}]};
      if (sql.includes('SELECT id, balance FROM escrow_accounts')) return {rows: [{id: 'escrow-1', balance: 80}]};
      if (sql.includes('UPDATE escrow_accounts')) return {rows: [], rowCount: 1};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const response = createResponse();
  await claimCreateHandler(client)(
    {user: {userId: 'customer-1'}, body: {pointsCost: 40, rewardId: 'reward-digital', idempotencyKey: 'digital-request'}},
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.status, 'used');
  assert.equal(response.body.settlementId, 'new-id');
  assert.equal(queries.some(({sql}) => sql.includes("'digital_reward_claim_used'")), true);
  const claimInsert = queries.find(({sql}) => sql.includes('INSERT INTO reward_claims'));
  assert.equal(claimInsert.params[14], 'new-id');
});

test('unfunded digital reward cannot debit customer points or create a claim', async () => {
  const queries = [];
  const client = {
    async query(sql) {
      queries.push(sql);
      if (sql.includes('FROM reward_claims') && sql.includes('idempotency_key')) return {rows: []};
      if (sql.includes('FROM rewards WHERE id')) return {rows: [{
        id: 'reward-digital', value: 40, kind: 'digital', source_type: 'brand', source_id: 'brand-1',
        is_active: true, quantity_limit: null, quantity_redeemed: 0, expires_at: null, draw_enabled: false,
      }]};
      if (sql.includes('SELECT available_points')) return {rows: [{available_points: 100}]};
      if (sql.includes('SELECT id, balance FROM escrow_accounts')) return {rows: []};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const response = createResponse();
  await claimCreateHandler(client)(
    {user: {userId: 'customer-1'}, body: {pointsCost: 40, rewardId: 'reward-digital', idempotencyKey: 'digital-request'}},
    response,
  );

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, {error: 'insufficient_escrow_balance'});
  assert.equal(queries.some((sql) => sql.includes('INSERT INTO reward_claims')), false);
  assert.equal(queries.some((sql) => sql.includes('UPDATE point_accounts')), false);
  assert.equal(queries.at(-1), 'ROLLBACK');
});

test('brand physical reward fulfillment debits brand escrow and creates settlement', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT * FROM reward_claims')) return {rows: [{
        id: 'claim-1', owner_id: 'customer-1', reward_kind: 'physical',
        source_type: 'brand', source_id: 'brand-1', points_cost: 80,
        status: 'pending_pickup', expires_at: new Date(Date.now() + 60000),
      }]};
      if (sql.includes('FROM escrow_accounts')) return {rows: [{id: 'escrow-1', balance: 100}]};
      if (sql.includes('UPDATE escrow_accounts')) return {rowCount: 1, rows: []};
      if (sql.includes('SELECT merchant_id FROM cashier_profiles')) return {rows: [{merchant_id: 'merchant-fulfiller'}]};
      if (sql.includes('INSERT INTO merchant_token_wallets')) return {rows: [{balance: 80}], rowCount: 1};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const handler = exchangeHandlers(client, {
    async canRedeemClaim() { return true; },
    async getMerchantProfileIdByUser() { return null; },
  }).get('POST /api/cashier/redeem-claim');
  const response = createResponse();

  await handler({user: {userId: 'cashier-1'}, body: {pickupQrCode: 'QR-1'}}, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.status, 'redeemed');
  const escrowLookup = queries.find(({sql}) => sql.includes('FROM escrow_accounts'));
  assert.deepEqual(escrowLookup.params, ['brand', 'brand-1']);
  assert.equal(queries.some(({sql}) => sql.includes('INSERT INTO settlements')), true);
  assert.equal(queries.some(({sql}) => sql.includes("settlement_id = $3")), true);
  assert.equal(queries.at(-1).sql, 'COMMIT');
});

test('insufficient brand escrow leaves claim and fulfiller wallet unchanged', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('SELECT * FROM reward_claims')) return {rows: [{
        id: 'claim-1', owner_id: 'customer-1', reward_kind: 'physical',
        source_type: 'brand', source_id: 'brand-1', points_cost: 80,
        status: 'pending_pickup', expires_at: new Date(Date.now() + 60000),
      }]};
      if (sql.includes('FROM escrow_accounts')) return {rows: [{id: 'escrow-1', balance: 20}]};
      if (sql.includes('UPDATE escrow_accounts')) return {rowCount: 0, rows: []};
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const handler = exchangeHandlers(client, {
    async canRedeemClaim() { return true; },
  }).get('POST /api/cashier/redeem-claim');
  const response = createResponse();

  await handler({user: {userId: 'cashier-1'}, body: {pickupQrCode: 'QR-1'}}, response);

  assert.equal(response.statusCode, 409);
  assert.deepEqual(response.body, {error: 'insufficient_escrow_balance'});
  assert.equal(queries.some(({sql}) => sql.includes("SET status = 'redeemed'")), false);
  assert.equal(queries.some(({sql}) => sql.includes('INSERT INTO merchant_token_wallets')), false);
  assert.equal(queries.at(-1).sql, 'ROLLBACK');
});

test('expired physical claim restores points inventory and reference ledger atomically', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reward_claims') && sql.includes("status = 'pending_pickup'")) {
        return {rows: [{id: 'claim-1', owner_id: 'customer-1', reward_id: 'reward-1', points_cost: 80}]};
      }
      return {rows: [], rowCount: 1};
    },
    release() {},
  };
  const handler = exchangeHandlers(client).get('POST /api/reward-claims/refund-expired/run');
  const response = createResponse();

  await handler({user: {userId: 'admin-1'}, body: {}}, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.refunded, 1);
  assert.equal(queries.some(({sql}) => sql.includes('quantity_redeemed = GREATEST')), true);
  const ledger = queries.find(({sql}) => sql.includes("'rewardClaimRefunded'"));
  assert.deepEqual(ledger.params, ['new-id', 'customer-1', 80, 'reward_claim:claim-1']);
  assert.equal(queries.at(-1).sql, 'COMMIT');
});
