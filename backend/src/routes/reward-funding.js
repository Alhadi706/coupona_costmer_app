module.exports = function registerRewardFundingRoutes(app, deps) {
  const {pool, auth, id, getMerchantProfileIdByUser, getBrandProfileIdByUser} = deps;

  async function resolveSource(client, userId, rawType) {
    const sourceType = String(rawType || '').trim().toLowerCase();
    if (sourceType === 'merchant') {
      const sourceId = await getMerchantProfileIdByUser(client, userId);
      return sourceId ? {sourceType, sourceId, walletTable: 'merchant_token_wallets', ledgerTable: 'merchant_token_ledger', idColumn: 'merchant_id'} : null;
    }
    if (sourceType === 'brand') {
      const sourceId = await getBrandProfileIdByUser(client, userId);
      return sourceId ? {sourceType, sourceId, walletTable: 'brand_token_wallets', ledgerTable: 'brand_token_ledger', idColumn: 'brand_id'} : null;
    }
    return null;
  }

  async function ensureWallet(client, source) {
    await client.query(
      `INSERT INTO ${source.walletTable} (${source.idColumn}, balance, currency, is_local_mode, last_updated_at)
       VALUES ($1, 0, 'SAR', FALSE, NOW()) ON CONFLICT (${source.idColumn}) DO NOTHING`,
      [source.sourceId]
    );
  }

  async function summary(client, source) {
    await ensureWallet(client, source);
    const wallet = (await client.query(
      `SELECT balance FROM ${source.walletTable} WHERE ${source.idColumn} = $1 LIMIT 1`,
      [source.sourceId]
    )).rows[0];
    const escrow = (await client.query(
      `SELECT id, balance FROM escrow_accounts
        WHERE source_type = $1 AND source_id = $2
        ORDER BY created_at ASC LIMIT 1`,
      [source.sourceType, source.sourceId]
    )).rows[0];
    return {
      sourceType: source.sourceType,
      sourceId: source.sourceId,
      walletBalance: Number(wallet?.balance || 0),
      escrowBalance: Number(escrow?.balance || 0),
    };
  }

  app.get('/api/reward-funding/:sourceType/summary', auth, async (req, res) => {
    const client = await pool.connect();
    try {
      const source = await resolveSource(client, req.user.userId, req.params.sourceType);
      if (!source) return res.status(403).json({error: 'reward_funding_role_required'});
      return res.json(await summary(client, source));
    } catch (error) {
      return res.status(500).json({error: 'reward_funding_summary_failed', details: String(error.message || error)});
    } finally {
      client.release();
    }
  });

  app.post('/api/reward-funding/:sourceType/fund', auth, async (req, res) => {
    const amount = Number(req.body?.amount);
    if (!Number.isInteger(amount) || amount <= 0) return res.status(400).json({error: 'invalid_funding_amount'});
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const source = await resolveSource(client, req.user.userId, req.params.sourceType);
      if (!source) {
        await client.query('ROLLBACK');
        return res.status(403).json({error: 'reward_funding_role_required'});
      }
      await ensureWallet(client, source);
      const wallet = (await client.query(
        `SELECT balance FROM ${source.walletTable} WHERE ${source.idColumn} = $1 FOR UPDATE`,
        [source.sourceId]
      )).rows[0];
      if (Number(wallet?.balance || 0) < amount) {
        await client.query('ROLLBACK');
        return res.status(409).json({error: 'insufficient_reward_funding_balance'});
      }
      const fundingId = id();
      const walletAfter = Number(wallet.balance) - amount;
      await client.query(
        `UPDATE ${source.walletTable} SET balance = $2, last_updated_at = NOW() WHERE ${source.idColumn} = $1`,
        [source.sourceId, walletAfter]
      );
      let escrow = (await client.query(
        `SELECT id, balance FROM escrow_accounts
          WHERE source_type = $1 AND source_id = $2
          ORDER BY created_at ASC LIMIT 1 FOR UPDATE`,
        [source.sourceType, source.sourceId]
      )).rows[0];
      if (escrow) {
        escrow = (await client.query(
          'UPDATE escrow_accounts SET balance = balance + $2, updated_at = NOW() WHERE id = $1 RETURNING id, balance',
          [escrow.id, amount]
        )).rows[0];
      } else {
        const escrowId = id();
        escrow = (await client.query(
          `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
           VALUES ($1,$2,$3,$4) RETURNING id, balance`,
          [escrowId, source.sourceType, source.sourceId, amount]
        )).rows[0];
      }
      await client.query(
        `INSERT INTO ${source.ledgerTable}
          (id, ${source.idColumn}, customer_user_id, receipt_id, type, amount, balance_after, created_at)
         VALUES ($1,$2,NULL,$3,'reward_escrow_funded',$4,$5,NOW())`,
        [fundingId, source.sourceId, `reward_funding:${fundingId}`, -amount, walletAfter]
      );
      await client.query('COMMIT');
      return res.json({
        ok: true,
        reference: `reward_funding:${fundingId}`,
        sourceType: source.sourceType,
        sourceId: source.sourceId,
        walletBalance: walletAfter,
        escrowBalance: Number(escrow.balance || 0),
      });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({error: 'reward_funding_failed', details: String(error.message || error)});
    } finally {
      client.release();
    }
  });
};