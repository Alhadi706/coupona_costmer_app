const assert = require('node:assert/strict');
const test = require('node:test');

process.env.JWT_SECRET ||= 'brand-partner-campaign-test-secret';
process.env.PGPASSWORD ||= 'brand-partner-campaign-test-password';

const { getBrandCustomers, resolveSegment } = require('./src/customer-segmentation-service');
const { launchCampaign, redeemCoupon } = require('./src/promotion-campaign-service');

test('brand support audience is scoped to matched purchases at the partner store', async () => {
  let captured;
  const client = {
    async query(sql, params) {
      captured = {sql, params};
      return {rows: [{owner_id: 'customer-1', visit_count: 2, total_spent: 50, last_visit: new Date()}]};
    },
  };

  const customers = await getBrandCustomers(client, 'brand-1', 'frequent_visitors', {
    partnerMerchantId: 'merchant-1',
    months: 3,
    minVisits: 2,
  });

  assert.deepEqual(customers, [{customerId: 'customer-1', visitCount: 2}]);
  assert.match(captured.sql, /FROM brand_matches bm/);
  assert.match(captured.sql, /i\.merchant_profile_id = \$3/);
  assert.deepEqual(captured.params, ['brand-1', 3, 'merchant-1']);
});

test('brand support coupon can only be redeemed by its partner store', async () => {
  const client = {
    async query(sql) {
      if (sql.includes('FROM promo_campaign_coupons')) {
        return {rows: [{id: 'coupon-1', campaign_id: 'campaign-1', customer_id: 'customer-1', status: 'issued'}]};
      }
      if (sql.includes('FROM promo_campaigns')) {
        return {rows: [{
          id: 'campaign-1',
          source_type: 'brand',
          source_id: 'brand-1',
          status: 'active',
          segment_params: {partnerMerchantId: 'merchant-1'},
          starts_at: new Date(Date.now() - 1000),
          ends_at: new Date(Date.now() + 60000),
        }]};
      }
      return {rows: []};
    },
  };

  const denied = await redeemCoupon(client, 'QR', 'merchant-2', 'cashier-2');
  assert.deepEqual(denied, {ok: false, status: 403, error: 'coupon_not_valid_for_this_store'});
});

test('draft campaign launches once and enforces the recipient cap', async () => {
  const dispatchedCustomers = [];
  let activated = false;
  const campaign = {
    id: 'campaign-draft',
    source_type: 'brand',
    source_id: 'brand-1',
    campaign_type: 'early_access_discount',
    title: 'Support',
    status: 'draft',
    segment_filter: 'all',
    segment_params: {partnerMerchantId: 'merchant-1', maxRecipients: 1},
    starts_at: new Date(Date.now() - 1000),
    ends_at: new Date(Date.now() + 60000),
  };
  const client = {
    async query(sql, params) {
      if (sql.includes('FROM promo_campaigns') && sql.includes('FOR UPDATE')) return {rows: [campaign]};
      if (sql.includes('FROM brand_matches bm')) {
        return {rows: [
          {owner_id: 'customer-1', visit_count: 2, total_spent: 50},
          {owner_id: 'customer-2', visit_count: 1, total_spent: 20},
        ]};
      }
      if (sql.includes('INSERT INTO promo_campaign_coupons')) dispatchedCustomers.push(params[2]);
      if (sql.includes("SET status = 'active'")) activated = true;
      return {rows: []};
    },
  };

  const result = await launchCampaign(client, campaign.id, null, 'Brand');

  assert.equal(result.segmentSize, 1);
  assert.deepEqual(dispatchedCustomers, ['customer-1']);
  assert.equal(activated, true);
});

test('campaign budget cap limits dispatch below a larger recipient cap', async () => {
  const dispatchedCustomers = [];
  const campaign = {
    id: 'campaign-budget', source_type: 'brand', source_id: 'brand-1', campaign_type: 'free_gift',
    title: 'Budgeted gift', status: 'draft', segment_filter: 'all',
    segment_params: {maxRecipients: 10, maxCampaignSpend: 25, estimatedCostPerRecipient: 10},
    starts_at: new Date(Date.now() - 1000), ends_at: new Date(Date.now() + 60000),
  };
  const client = {
    async query(sql, params) {
      if (sql.includes('FROM promo_campaigns') && sql.includes('FOR UPDATE')) return {rows: [campaign]};
      if (sql.includes('FROM brand_matches bm')) return {rows: [
        {owner_id: 'customer-1', total_spent: 50}, {owner_id: 'customer-2', total_spent: 30}, {owner_id: 'customer-3', total_spent: 20},
      ]};
      if (sql.includes('INSERT INTO promo_campaign_coupons')) dispatchedCustomers.push(params[2]);
      return {rows: []};
    },
  };
  const result = await launchCampaign(client, campaign.id, null, 'Brand');
  assert.equal(result.segmentSize, 2);
  assert.deepEqual(dispatchedCustomers, ['customer-1', 'customer-2']);
});

test('direct gifts only retain customers with a previous relationship to the source', async () => {
  const client = {
    async query(sql) {
      if (sql.includes('SELECT DISTINCT owner_id FROM invoice_scans')) {
        return {rows: [{owner_id: 'customer-1'}, {owner_id: 'customer-2'}]};
      }
      return {rows: []};
    },
  };
  const recipients = await resolveSegment(client, 'merchant', 'merchant-1', 'selected_customers', {
    selectedCustomerIds: ['customer-2', 'outsider', 'customer-2'],
  });
  assert.deepEqual(recipients, [{customerId: 'customer-2'}]);
});

test('paused campaign coupons cannot be redeemed', async () => {
  const client = {
    async query(sql) {
      if (sql.includes('FROM promo_campaign_coupons')) return {rows: [{id: 'coupon-1', campaign_id: 'campaign-1', status: 'issued'}]};
      if (sql.includes('FROM promo_campaigns')) return {rows: [{id: 'campaign-1', status: 'paused'}]};
      return {rows: []};
    },
  };

  assert.deepEqual(
    await redeemCoupon(client, 'QR', 'merchant-1', 'cashier-1'),
    {ok: false, status: 409, error: 'campaign_not_active'},
  );
});
