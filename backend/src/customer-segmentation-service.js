// Customer segmentation filters used by promotional campaign targeting.
async function getTopSpenders(client, sourceType, sourceId, { months = 6, topPercent = 10, minimumTotalSpend = 0 } = {}) {
  if (sourceType !== 'merchant') return [];
  const minimumSpend = Number(minimumTotalSpend || 0);
  const { rows } = await client.query(`
    SELECT owner_id, COALESCE(SUM(total_amount), 0) AS total_spent
      FROM invoice_scans
     WHERE merchant_profile_id = $1
       AND state = 'approved'
       AND created_at >= NOW() - ($2 || ' months')::INTERVAL
     GROUP BY owner_id
    HAVING COALESCE(SUM(total_amount), 0) >= $3
     ORDER BY total_spent DESC
  `, [sourceId, months, minimumSpend]);
  const takeCount = Math.max(1, Math.ceil(rows.length * (topPercent / 100)));
  return rows.slice(0, takeCount).map((r) => ({ customerId: r.owner_id, totalSpent: Number(r.total_spent || 0) }));
}

async function getFrequentVisitors(client, sourceType, sourceId, { months = 6, minVisits = 3 } = {}) {
  if (sourceType !== 'merchant') return [];
  const { rows } = await client.query(`
    SELECT owner_id, COUNT(*)::int AS visit_count
      FROM invoice_scans
     WHERE merchant_profile_id = $1
       AND state = 'approved'
       AND created_at >= NOW() - ($2 || ' months')::INTERVAL
     GROUP BY owner_id
    HAVING COUNT(*) >= $3
     ORDER BY visit_count DESC
  `, [sourceId, months, minVisits]);
  return rows.map((r) => ({ customerId: r.owner_id, visitCount: Number(r.visit_count || 0) }));
}

async function getInactiveCustomers(client, sourceType, sourceId, { inactiveDays = 60 } = {}) {
  if (sourceType !== 'merchant') return [];
  const { rows } = await client.query(`
    SELECT owner_id, MAX(created_at) AS last_visit
      FROM invoice_scans
     WHERE merchant_profile_id = $1
       AND state = 'approved'
     GROUP BY owner_id
    HAVING MAX(created_at) <= NOW() - ($2 || ' days')::INTERVAL
     ORDER BY last_visit ASC
  `, [sourceId, inactiveDays]);
  return rows.map((r) => ({ customerId: r.owner_id, lastVisit: r.last_visit }));
}

async function getCoalitionNetworkCustomers(client, sourceType, sourceId) {
  if (sourceType !== 'merchant') return [];
  const { rows } = await client.query(`
    SELECT DISTINCT b.customer_id
      FROM customer_merchant_point_balances b
     WHERE b.coalition_id IN (
       SELECT coalition_id FROM coalition_members WHERE merchant_id = $1
     )
       AND b.merchant_id != $1
       AND b.points_balance > 0
  `, [sourceId]);
  return rows.map((r) => ({ customerId: r.customer_id }));
}

async function resolveSegment(client, sourceType, sourceId, segmentFilter, segmentParams = {}) {
  switch (segmentFilter) {
    case 'top_spenders':
      return getTopSpenders(client, sourceType, sourceId, segmentParams);
    case 'frequent_visitors':
      return getFrequentVisitors(client, sourceType, sourceId, segmentParams);
    case 'inactive':
      return getInactiveCustomers(client, sourceType, sourceId, segmentParams);
    case 'coalition_network':
      return getCoalitionNetworkCustomers(client, sourceType, sourceId);
    case 'all': {
      if (sourceType !== 'merchant') return [];
      const { rows } = await client.query(
        `SELECT DISTINCT owner_id FROM invoice_scans WHERE merchant_profile_id = $1 AND state = 'approved'`,
        [sourceId]
      );
      return rows.map((r) => ({ customerId: r.owner_id }));
    }
    default:
      return [];
  }
}

module.exports = {
  getTopSpenders,
  getFrequentVisitors,
  getInactiveCustomers,
  getCoalitionNetworkCustomers,
  resolveSegment,
};
