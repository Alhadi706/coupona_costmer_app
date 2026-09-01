const { id } = require('./helpers');

async function addTierPoints(client, pending, tier, points) {
  const merchantId = tier === 'bronze' ? pending.merchant_id : null;
  const coalitionId = tier === 'bronze' ? null : pending.coalition_id;
  await client.query(`
    INSERT INTO customer_point_tiers
      (id, customer_id, tier, merchant_id, coalition_id, balance, lifetime_earned)
    VALUES ($1, $2, $3, $4, $5, $6, $6)
    ON CONFLICT (customer_id, tier, COALESCE(merchant_id, ''), COALESCE(coalition_id, ''))
    DO UPDATE SET balance = customer_point_tiers.balance + EXCLUDED.balance,
                  lifetime_earned = customer_point_tiers.lifetime_earned + EXCLUDED.lifetime_earned,
                  updated_at = NOW()
  `, [id(), pending.customer_id, tier, merchantId, coalitionId, points]);
}

async function clearPendingPointsQueue(client, merchantId, insertNotification) {
  const { rows: [wallet] } = await client.query(
    `SELECT balance FROM merchant_token_wallets WHERE merchant_id = $1 FOR UPDATE`, [merchantId]
  );
  let available = Number(wallet?.balance || 0);
  if (available <= 0) return { cleared: 0, remainingBalance: available };

  const { rows: pendingRows } = await client.query(`
    SELECT p.*, c.type AS coalition_type,
           CASE WHEN c.type = 'public' THEN 'gold'
                WHEN c.type = 'private' THEN 'silver'
                ELSE 'bronze' END AS resolved_tier,
           CASE WHEN c.type = 'public' THEN NULL
                WHEN c.type = 'private' THEN p.coalition_id
                ELSE NULL END AS resolved_coalition_id
      FROM customer_pending_points p
      LEFT JOIN coalitions c ON c.id = p.coalition_id
     WHERE p.merchant_id = $1 AND p.status IN ('PENDING', 'PARTIALLY_CLEARED')
     ORDER BY p.created_at ASC
     FOR UPDATE OF p
  `, [merchantId]);

  let cleared = 0;
  for (const pending of pendingRows) {
    if (available <= 0) break;
    const amount = Math.min(available, Number(pending.points_remaining));
    const tier = pending.resolved_tier || pending.tier;
    const hydrated = { ...pending, coalition_id: pending.resolved_coalition_id || pending.coalition_id };
    await addTierPoints(client, hydrated, tier, amount);
    await client.query(`
      UPDATE point_accounts
         SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW()
       WHERE owner_id = $1
    `, [pending.customer_id, amount]);
    await client.query(`
      UPDATE users SET points = points + $2, points_history = points_history || to_jsonb($2::int)
       WHERE id = $1
    `, [pending.customer_id, amount]);
    const remaining = Number(pending.points_remaining) - amount;
    await client.query(`
      UPDATE customer_pending_points
         SET points_remaining = $2,
             status = CASE WHEN $2 = 0 THEN 'CLEARED' ELSE 'PARTIALLY_CLEARED' END,
             cleared_at = CASE WHEN $2 = 0 THEN NOW() ELSE cleared_at END
       WHERE id = $1
    `, [pending.id, remaining]);
    await client.query(`
      INSERT INTO merchant_token_ledger
        (id, merchant_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
      VALUES ($1, $2, $3, $4, 'pending_points_cleared', $5, $6, NOW())
    `, [id(), merchantId, pending.customer_id, pending.invoice_id, amount, available - amount]);
    available -= amount;
    cleared += amount;
    if (insertNotification) {
      await insertNotification(client, pending.customer_id, 'pending_points_cleared', 'Pending points activated',
        'Your pending points have been activated.', { merchantId, invoiceId: pending.invoice_id, points: amount });
    }
  }
  await client.query(
    `UPDATE merchant_token_wallets SET balance = $2, is_local_mode = ($2 = 0), last_updated_at = NOW() WHERE merchant_id = $1`,
    [merchantId, available]
  );
  return { cleared, remainingBalance: available };
}

async function convertExpiredPendingPoints(client, insertNotification) {
  const { rows } = await client.query(`
    SELECT p.* FROM customer_pending_points p
     WHERE p.status IN ('PENDING', 'PARTIALLY_CLEARED')
       AND p.created_at <= NOW() - INTERVAL '14 days'
     ORDER BY p.created_at ASC
     FOR UPDATE
  `);
  for (const pending of rows) {
    const points = Number(pending.points_remaining);
    await addTierPoints(client, pending, 'bronze', points);
    await client.query(`
      UPDATE point_accounts
         SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW()
       WHERE owner_id = $1
    `, [pending.customer_id, points]);
    await client.query(
      `UPDATE customer_pending_points SET points_remaining = 0, status = 'CONVERTED_BRONZE', converted_at = NOW() WHERE id = $1`,
      [pending.id]
    );
    if (insertNotification) {
      await insertNotification(client, pending.customer_id, 'pending_points_converted', 'Pending points converted',
        'Your pending points are now store-exclusive Bronze points.', { merchantId: pending.merchant_id, points });
    }
  }
  return rows.length;
}

async function clearPendingBrandPointsQueue(client, brandId, insertNotification) {
  const { rows: [wallet] } = await client.query(
    `SELECT balance FROM brand_token_wallets WHERE brand_id = $1 FOR UPDATE`, [brandId]
  );
  let available = Number(wallet?.balance || 0);
  if (available <= 0) return { cleared: 0, remainingBalance: available };

  const { rows: pendingRows } = await client.query(`
    SELECT * FROM customer_pending_brand_points
     WHERE brand_id = $1 AND status IN ('PENDING', 'PARTIALLY_CLEARED')
     ORDER BY created_at ASC
     FOR UPDATE
  `, [brandId]);

  let cleared = 0;
  for (const pending of pendingRows) {
    if (available <= 0) break;
    const amount = Math.min(available, Number(pending.points_remaining));
    await client.query(`
      INSERT INTO points_ledger_brand (
        id, customer_id, brand_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at
      ) VALUES ($1,$2,$3,$4,$5,0,0,'active', NOW() + INTERVAL '12 months')
    `, [id(), pending.customer_id, brandId, pending.invoice_id, amount]);
    await client.query(`
      UPDATE point_accounts
         SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW()
       WHERE owner_id = $1
    `, [pending.customer_id, amount]);
    await client.query(`
      UPDATE users SET points = points + $2, points_history = points_history || to_jsonb($2::int)
       WHERE id = $1
    `, [pending.customer_id, amount]);
    const remaining = Number(pending.points_remaining) - amount;
    await client.query(`
      UPDATE customer_pending_brand_points
         SET points_remaining = $2,
             status = CASE WHEN $2 = 0 THEN 'CLEARED' ELSE 'PARTIALLY_CLEARED' END,
             cleared_at = CASE WHEN $2 = 0 THEN NOW() ELSE cleared_at END
       WHERE id = $1
    `, [pending.id, remaining]);
    await client.query(`
      INSERT INTO brand_token_ledger
        (id, brand_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
      VALUES ($1, $2, $3, $4, 'pending_points_cleared', $5, $6, NOW())
    `, [id(), brandId, pending.customer_id, pending.invoice_id, amount, available - amount]);
    available -= amount;
    cleared += amount;
    if (insertNotification) {
      await insertNotification(client, pending.customer_id, 'pending_brand_points_cleared', 'Pending brand points activated',
        'Your pending brand points have been activated.', { brandId, invoiceId: pending.invoice_id, points: amount });
    }
  }
  await client.query(
    `UPDATE brand_token_wallets SET balance = $2, is_local_mode = ($2 = 0), last_updated_at = NOW() WHERE brand_id = $1`,
    [brandId, available]
  );
  return { cleared, remainingBalance: available };
}

module.exports = { clearPendingPointsQueue, convertExpiredPendingPoints, clearPendingBrandPointsQueue };