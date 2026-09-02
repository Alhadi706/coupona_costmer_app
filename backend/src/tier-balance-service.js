const TIER_KEYS = ['bronze', 'silver', 'gold'];

function summarizeTierBalances(availablePoints, rows = [], lifetimePoints = availablePoints) {
  const available = Math.max(0, Number(availablePoints || 0));
  const lifetime = Math.max(available, Number(lifetimePoints || 0));
  const tiers = {
    bronze: { balance: 0, lifetimeEarned: 0 },
    silver: { balance: 0, lifetimeEarned: 0 },
    gold: { balance: 0, lifetimeEarned: 0 },
  };

  for (const row of rows) {
    if (!TIER_KEYS.includes(row.tier)) continue;
    tiers[row.tier].balance += Math.max(0, Number(row.balance || 0));
    tiers[row.tier].lifetimeEarned += Math.max(0, Number(row.lifetime_earned || row.lifetimeEarned || 0));
  }

  let classified = TIER_KEYS.reduce((sum, tier) => sum + tiers[tier].balance, 0);
  const classifiedLifetime = TIER_KEYS.reduce((sum, tier) => sum + tiers[tier].lifetimeEarned, 0);
  const legacyUnclassified = Math.max(0, available - classified);
  const legacyLifetimeUnclassified = Math.max(0, lifetime - classifiedLifetime);
  tiers.bronze.balance += legacyUnclassified;
  tiers.bronze.lifetimeEarned += legacyLifetimeUnclassified;
  classified += legacyUnclassified;

  let excess = Math.max(0, classified - available);
  for (const tier of ['gold', 'silver', 'bronze']) {
    if (excess === 0) break;
    const deduction = Math.min(excess, tiers[tier].balance);
    tiers[tier].balance -= deduction;
    excess -= deduction;
  }

  return { tiers, legacyUnclassified, legacyLifetimeUnclassified };
}

module.exports = { summarizeTierBalances };