const assert = require('node:assert/strict');
const test = require('node:test');

const { summarizeTierBalances } = require('./src/tier-balance-service');

test('classifies legacy unscoped balance as bronze', () => {
  const result = summarizeTierBalances(151, [], 381);

  assert.deepEqual(result.tiers, {
    bronze: { balance: 151, lifetimeEarned: 381 },
    silver: { balance: 0, lifetimeEarned: 0 },
    gold: { balance: 0, lifetimeEarned: 0 },
  });
  assert.equal(result.legacyUnclassified, 151);
  assert.equal(result.legacyLifetimeUnclassified, 381);
});

test('preserves classified balances that match the point account', () => {
  const result = summarizeTierBalances(100, [
    { tier: 'bronze', balance: 25, lifetime_earned: 40 },
    { tier: 'silver', balance: 30, lifetime_earned: 30 },
    { tier: 'gold', balance: 45, lifetime_earned: 50 },
  ]);

  assert.equal(result.tiers.bronze.balance, 25);
  assert.equal(result.tiers.silver.balance, 30);
  assert.equal(result.tiers.gold.balance, 45);
  assert.equal(result.legacyUnclassified, 0);
});

test('reconciles historical redemptions from the highest tier first', () => {
  const result = summarizeTierBalances(60, [
    { tier: 'bronze', balance: 30 },
    { tier: 'silver', balance: 30 },
    { tier: 'gold', balance: 30 },
  ]);

  assert.equal(result.tiers.bronze.balance, 30);
  assert.equal(result.tiers.silver.balance, 30);
  assert.equal(result.tiers.gold.balance, 0);
});