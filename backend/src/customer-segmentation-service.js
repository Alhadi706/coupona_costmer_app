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

async function getBrandCustomers(client, brandId, segmentFilter, params = {}) {
  const partnerMerchantId = String(params.partnerMerchantId || '').trim();
  const months = Math.max(1, Number(params.months || 6));
  const minVisits = Math.max(1, Number(params.minVisits || 1));
  const queryParams = [brandId, months];
  let partnerClause = '';
  if (partnerMerchantId) {
    queryParams.push(partnerMerchantId);
    partnerClause = ` AND i.merchant_profile_id = $${queryParams.length}`;
  }
  const { rows } = await client.query(`
    SELECT i.owner_id,
           COUNT(DISTINCT i.id)::int AS visit_count,
           COALESCE(SUM(li.line_total), 0) AS total_spent,
           MAX(i.created_at) AS last_visit
      FROM brand_matches bm
      JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
      JOIN invoice_scans i ON i.id = li.invoice_scan_id
     WHERE bm.brand_id = $1
       AND i.state = 'approved'
       AND i.created_at >= NOW() - ($2 || ' months')::INTERVAL${partnerClause}
     GROUP BY i.owner_id
     ORDER BY total_spent DESC
  `, queryParams);
  if (segmentFilter === 'frequent_visitors') {
    return rows.filter((row) => Number(row.visit_count || 0) >= minVisits).map((row) => ({customerId: row.owner_id, visitCount: Number(row.visit_count || 0)}));
  }
  if (segmentFilter === 'top_spenders') {
    const topPercent = Math.min(100, Math.max(1, Number(params.topPercent || 10)));
    const takeCount = rows.length ? Math.max(1, Math.ceil(rows.length * topPercent / 100)) : 0;
    return rows.slice(0, takeCount).map((row) => ({customerId: row.owner_id, totalSpent: Number(row.total_spent || 0)}));
  }
  return rows.map((row) => ({customerId: row.owner_id, totalSpent: Number(row.total_spent || 0)}));
}

async function resolveSegment(client, sourceType, sourceId, segmentFilter, segmentParams = {}) {
  if (segmentFilter === 'selected_customers') {
    const selectedIds = [...new Set(
      (Array.isArray(segmentParams.selectedCustomerIds) ? segmentParams.selectedCustomerIds : [])
        .map((customerId) => String(customerId || '').trim())
        .filter(Boolean)
    )].slice(0, 100);
    if (!selectedIds.length) return [];
    const sourceCustomers = sourceType === 'brand'
      ? await getBrandCustomers(client, sourceId, 'all', segmentParams)
      : await resolveSegment(client, sourceType, sourceId, 'all', segmentParams);
    const allowedIds = new Set(sourceCustomers.map((customer) => customer.customerId));
    return selectedIds.filter((customerId) => allowedIds.has(customerId)).map((customerId) => ({customerId}));
  }
  if (sourceType === 'brand') {
    return getBrandCustomers(client, sourceId, segmentFilter, segmentParams);
  }
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
  getBrandCustomers,
  resolveSegment,
};
