const assert = require('node:assert/strict');
const test = require('node:test');

const {processExpiredRewardClaims} = require('./src/reward-claim-service');

test('scheduled processor restores one expired claim completely', async () => {
  const queries = [];
  const client = {
    async query(sql, params) {
      queries.push({sql, params});
      if (sql.includes('FROM reward_claims')) return {rows: [{id: 'claim-1', owner_id: 'customer-1', reward_id: 'reward-1', points_cost: 30}]};
      return {rows: [], rowCount: 1};
    },
  };

  const count = await processExpiredRewardClaims(client, () => 'ledger-1');

  assert.equal(count, 1);
  assert.equal(queries.some(({sql}) => sql.includes("status = 'refunded_as_points'")), true);
  assert.equal(queries.some(({sql}) => sql.includes('quantity_redeemed = GREATEST')), true);
  const ledger = queries.find(({sql}) => sql.includes("'rewardClaimRefunded'"));
  assert.deepEqual(ledger.params, ['ledger-1', 'customer-1', 30, 'reward_claim:claim-1']);
});

test('scheduled processor is a no-op when no claims expired', async () => {
  const queries = [];
  const client = {async query(sql) { queries.push(sql); return {rows: []}; }};

  const count = await processExpiredRewardClaims(client, () => 'unused');

  assert.equal(count, 0);
  assert.equal(queries.length, 1);
});