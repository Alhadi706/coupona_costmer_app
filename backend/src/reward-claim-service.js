async function processExpiredRewardClaims(client, id) {
  const rows = (await client.query(
    `SELECT id, owner_id, reward_id, points_cost
       FROM reward_claims
      WHERE status = 'pending_pickup'
        AND expires_at IS NOT NULL
        AND expires_at <= NOW()
      FOR UPDATE`
  )).rows;
  for (const row of rows) {
    await client.query("UPDATE reward_claims SET status = 'refunded_as_points', updated_at = NOW() WHERE id = $1", [row.id]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $2, updated_at = NOW() WHERE owner_id = $1', [row.owner_id, row.points_cost]);
    if (row.reward_id) {
      await client.query(
        `UPDATE rewards
            SET quantity_redeemed = GREATEST(quantity_redeemed - 1, 0)
          WHERE id = $1 AND quantity_limit IS NOT NULL`,
        [row.reward_id]
      );
    }
    await client.query(
      `INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference)
       VALUES ($1, $2, 'rewardClaimRefunded', 0, $3, $4)`,
      [id(), row.owner_id, Number(row.points_cost || 0), `reward_claim:${row.id}`]
    );
  }
  return rows.length;
}

module.exports = {processExpiredRewardClaims};