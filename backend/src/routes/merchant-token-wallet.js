module.exports = function registerMerchantTokenWalletRoutes(app, deps) {
  const { pool, auth, getMerchantProfileIdByUser, id, toIso, clearPendingPointsQueue, insertNotification } = deps;

  async function getMerchantWallet(client, merchantId) {
    await client.query(
      `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
       VALUES ($1, 0, 'SAR', FALSE, NOW())
       ON CONFLICT (merchant_id) DO NOTHING`,
      [merchantId]
    );
    const row = (await client.query(
      `SELECT merchant_id, balance, currency, is_local_mode, last_updated_at
         FROM merchant_token_wallets
        WHERE merchant_id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0];
    return row;
  }

  app.get('/api/merchant/tokens/:merchantId/status', auth, async (req, res) => {
    const authMerchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    const requestedMerchantId = String(req.params.merchantId || '').trim();
    if (!requestedMerchantId) return res.status(400).json({ error: 'merchant_id_required' });
    if (!authMerchantId || authMerchantId !== requestedMerchantId) {
      return res.status(403).json({ error: 'merchant_forbidden' });
    }

    const wallet = await getMerchantWallet(pool, requestedMerchantId);
    return res.json({
      merchantId: wallet.merchant_id,
      balance: Number(wallet.balance || 0),
      currency: wallet.currency || 'SAR',
      isLocalMode: wallet.is_local_mode === true,
      lastUpdatedAt: toIso(wallet.last_updated_at),
    });
  });

  app.get('/api/merchant/token-wallet/balance', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const wallet = await getMerchantWallet(pool, merchantId);
    const { rows: [profile] } = await pool.query(
      `SELECT is_public_coalition_active FROM merchant_profiles WHERE id = $1`, [merchantId]
    );
    return res.json({
      merchantId,
      balance: Number(wallet.balance || 0),
      currency: wallet.currency || 'SAR',
      isPublicCoalitionActive: profile?.is_public_coalition_active === true,
      minimumActivationBalance: 1000,
    });
  });

  app.post('/api/merchant/coalitions/join-public', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    return res.status(409).json({
      error: 'public_coalition_membership_workflow_required',
      requestEndpoint: '/api/public-coalition/membership/request',
    });
  });

  app.post('/api/merchant/token-wallet/top-up', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    return res.status(410).json({
      error: 'public_coalition_external_payment_required',
      requestEndpoint: '/api/public-coalition/membership/request',
    });
  });

  app.post('/api/merchant/tokens/recharge', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const amount = Number((req.body || {}).amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'invalid_amount' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const wallet = await getMerchantWallet(client, merchantId);
      const newBalance = Number(wallet.balance || 0) + Math.round(amount);
      await client.query(
        `UPDATE merchant_token_wallets
            SET balance = $2,
                is_local_mode = FALSE,
                last_updated_at = NOW()
          WHERE merchant_id = $1`,
        [merchantId, newBalance]
      );
      await client.query(
        `INSERT INTO merchant_token_ledger (id, merchant_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
         VALUES ($1, $2, NULL, NULL, 'recharge', $3, $4, NOW())`,
        [id(), merchantId, Math.round(amount), newBalance]
      );
      await clearPendingPointsQueue(client, merchantId, insertNotification);
      await client.query('COMMIT');
      return res.json({ ok: true, merchantId, balance: newBalance, isLocalMode: false });
    } catch (e) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'recharge_failed', details: String(e.message || e) });
    } finally {
      client.release();
    }
  });

  app.post('/api/merchant/tokens/local-points', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const points = Number((req.body || {}).points || 0);
    const receiptId = String((req.body || {}).receiptId || '').trim();
    if (!Number.isInteger(points) || points <= 0 || !receiptId) {
      return res.status(400).json({ error: 'invalid_points_or_receipt' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const wallet = await getMerchantWallet(client, merchantId);
      const currentBalance = Number(wallet.balance || 0);
      if (currentBalance < points) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'insufficient_merchant_token_balance', balance: currentBalance });
      }
      const newBalance = currentBalance - points;
      await client.query(
        `UPDATE merchant_token_wallets
            SET balance = $2,
                is_local_mode = $3,
                last_updated_at = NOW()
          WHERE merchant_id = $1`,
        [merchantId, newBalance, newBalance === 0]
      );
      await client.query(
        `INSERT INTO merchant_token_ledger (id, merchant_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
         VALUES ($1, $2, $3, $4, 'local_points_deducted', $5, $6, NOW())`,
        [id(), merchantId, (req.body || {}).customerUserId ? String((req.body || {}).customerUserId).trim() : null, receiptId, points, newBalance]
      );
      await client.query('COMMIT');
      return res.json({ ok: true, merchantId, balance: newBalance, isLocalMode: newBalance === 0 });
    } catch (e) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'local_points_failed', details: String(e.message || e) });
    } finally {
      client.release();
    }
  });

  app.post('/api/merchant/tokens/local-redeem', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const points = Number((req.body || {}).points || 0);
    const cashierQrCode = String((req.body || {}).cashierQrCode || '').trim();
    if (!Number.isInteger(points) || points <= 0 || !cashierQrCode) {
      return res.status(400).json({ error: 'invalid_points_or_qr' });
    }

    const wallet = await getMerchantWallet(pool, merchantId);
    const currentBalance = Number(wallet.balance || 0);
    if (currentBalance < points) {
      return res.status(400).json({ error: 'insufficient_merchant_token_balance', balance: currentBalance });
    }

    const newBalance = currentBalance - points;
    await pool.query(
      `UPDATE merchant_token_wallets
          SET balance = $2,
              is_local_mode = $3,
              last_updated_at = NOW()
        WHERE merchant_id = $1`,
      [merchantId, newBalance, newBalance === 0]
    );
    await pool.query(
      `INSERT INTO merchant_token_ledger (id, merchant_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
       VALUES ($1, $2, NULL, $3, 'local_redeem', $4, $5, NOW())`,
      [id(), merchantId, cashierQrCode, points, newBalance]
    );
    return res.json({ ok: true, merchantId, balance: newBalance, isLocalMode: newBalance === 0 });
  });
};
