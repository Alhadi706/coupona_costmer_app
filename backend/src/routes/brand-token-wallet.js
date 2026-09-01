module.exports = function registerBrandTokenWalletRoutes(app, deps) {
  const { pool, auth, getBrandProfileIdByUser, id, toIso, clearPendingBrandPointsQueue, insertNotification } = deps;

  async function getBrandWallet(client, brandId) {
    await client.query(
      `INSERT INTO brand_token_wallets (brand_id, balance, currency, is_local_mode, last_updated_at)
       VALUES ($1, 0, 'SAR', FALSE, NOW())
       ON CONFLICT (brand_id) DO NOTHING`,
      [brandId]
    );
    const row = (await client.query(
      `SELECT brand_id, balance, currency, is_local_mode, last_updated_at
         FROM brand_token_wallets
        WHERE brand_id = $1
        LIMIT 1`,
      [brandId]
    )).rows[0];
    return row;
  }

  app.get('/api/brand/token-wallet/balance', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_profile_required' });
    const wallet = await getBrandWallet(pool, brandId);
    return res.json({
      brandId,
      balance: Number(wallet.balance || 0),
      currency: wallet.currency || 'SAR',
      isLocalMode: wallet.is_local_mode === true,
      lastUpdatedAt: toIso(wallet.last_updated_at),
    });
  });

  app.post('/api/brand/tokens/recharge', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_profile_required' });
    const amount = Number((req.body || {}).amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'invalid_amount' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const wallet = await getBrandWallet(client, brandId);
      const newBalance = Number(wallet.balance || 0) + Math.round(amount);
      await client.query(
        `UPDATE brand_token_wallets
            SET balance = $2,
                is_local_mode = FALSE,
                last_updated_at = NOW()
          WHERE brand_id = $1`,
        [brandId, newBalance]
      );
      await client.query(
        `INSERT INTO brand_token_ledger (id, brand_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
         VALUES ($1, $2, NULL, NULL, 'recharge', $3, $4, NOW())`,
        [id(), brandId, Math.round(amount), newBalance]
      );
      await clearPendingBrandPointsQueue(client, brandId, insertNotification);
      await client.query('COMMIT');
      return res.json({ ok: true, brandId, balance: newBalance, isLocalMode: false });
    } catch (e) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'recharge_failed', details: String(e.message || e) });
    } finally {
      client.release();
    }
  });

  app.get('/api/brand/wallet/pending-points', auth, async (req, res) => {
    const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_profile_required' });
    const { rows: [summary] } = await pool.query(`
      SELECT COALESCE(SUM(points_remaining), 0)::int AS total_points,
             COUNT(DISTINCT customer_id)::int AS customer_count
        FROM customer_pending_brand_points
       WHERE brand_id = $1 AND status IN ('PENDING', 'PARTIALLY_CLEARED')
    `, [brandId]);
    res.json({ total_points: Number(summary?.total_points || 0), customer_count: Number(summary?.customer_count || 0) });
  });
};
