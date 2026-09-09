module.exports = function registerCoalitionTierWalletRoutes(app, deps) {
  const { pool, auth, id, getMerchantProfileIdByUser } = deps;

  async function debitTierRows(client, rows, points) {
    let remaining = points;
    for (const row of rows) {
      if (remaining <= 0) break;
      const debit = Math.min(remaining, Number(row.balance || 0));
      await client.query(
        `UPDATE customer_point_tiers
            SET balance = balance - $2, updated_at = NOW()
          WHERE id = $1`,
        [row.id, debit]
      );
      remaining -= debit;
    }
    return remaining === 0;
  }

  async function creditSettlementWallet(client, merchantId, customerId, reference, points, type) {
    const { rows: [wallet] } = await client.query(`
      INSERT INTO merchant_settlement_wallets (merchant_id, settled_balance, currency, updated_at)
      VALUES ($1, $2, 'LYD', NOW())
      ON CONFLICT (merchant_id) DO UPDATE
        SET settled_balance = merchant_settlement_wallets.settled_balance + EXCLUDED.settled_balance,
            updated_at = NOW()
      RETURNING settled_balance
    `, [merchantId, points]);
    await client.query(`
      INSERT INTO merchant_settlement_ledger
        (id, merchant_id, customer_id, reference, type, amount, balance_after, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
    `, [id(), merchantId, customerId, reference, type, points, Number(wallet.settled_balance)]);
    return Number(wallet.settled_balance);
  }

  app.post('/api/customer/coalition/gold-voucher', auth, async (req, res) => {
    const customerId = req.user.userId;
    const amount = Number(req.body?.amount || 0);
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({ error: 'invalid_voucher_amount' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query(`
        SELECT id, balance FROM customer_point_tiers
         WHERE customer_id = $1 AND tier = 'gold' AND balance > 0
         ORDER BY updated_at ASC FOR UPDATE
      `, [customerId]);
      const available = rows.reduce((sum, row) => sum + Number(row.balance || 0), 0);
      if (available < amount) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'insufficient_gold_points', availablePoints: available });
      }
      await debitTierRows(client, rows, amount);
      const accountDebit = await client.query(
        `UPDATE point_accounts SET available_points = available_points - $2, updated_at = NOW()
          WHERE owner_id = $1 AND available_points >= $2`,
        [customerId, amount]
      );
      if (accountDebit.rowCount !== 1) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'point_account_tier_mismatch' });
      }
      const voucherId = id();
      await client.query(`
        INSERT INTO customer_gold_vouchers (id, customer_id, value_lyd, status, created_at)
        VALUES ($1, $2, $3, 'ACTIVE', NOW())
      `, [voucherId, customerId, amount]);
      await client.query(`
        INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference, created_at)
        VALUES ($1, $2, 'GOLD_VOUCHER_CONVERSION', $3, $4, $5, NOW())
      `, [id(), customerId, amount, -amount, `gold_voucher:${voucherId}`]);
      await client.query('COMMIT');
      return res.status(201).json({ ok: true, voucherId, valueLyD: amount, status: 'ACTIVE' });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'gold_voucher_conversion_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/customer/coalition/redeem', auth, async (req, res) => {
    const customerId = req.user.userId;
    const merchantId = String(req.body?.merchantId || '').trim();
    const issuingMerchantId = String(req.body?.issuingMerchantId || '').trim();
    const tier = String(req.body?.tier || 'gold').trim().toLowerCase();
    const points = Number(req.body?.points || 0);
    if (!merchantId || !Number.isInteger(points) || points <= 0 || !['gold', 'silver', 'bronze'].includes(tier)) {
      return res.status(400).json({ error: 'invalid_redemption_request' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows: [receiver] } = await client.query(
        `SELECT id, status, is_public_coalition_active FROM merchant_profiles WHERE id = $1`,
        [merchantId]
      );
      if (!receiver || receiver.status !== 'active') {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'receiving_merchant_not_found' });
      }

      if (tier === 'bronze' && issuingMerchantId !== merchantId) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Points restricted to issuing store only' });
      }
      if (tier === 'gold' && receiver.is_public_coalition_active !== true) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'gold_receiving_merchant_required' });
      }
      if (tier === 'silver' && !issuingMerchantId) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'issuing_merchant_required' });
      }

      const scopeValues = [customerId, tier];
      let scopeSql = '';
      if (tier === 'bronze') {
        scopeValues.push(issuingMerchantId);
        scopeSql = 'AND merchant_id = $3 AND coalition_id IS NULL';
      } else if (tier === 'silver') {
        scopeValues.push(issuingMerchantId, merchantId);
        scopeSql = `AND merchant_id = $3
          AND EXISTS (
            SELECT 1 FROM coalition_members receiver_member
             WHERE receiver_member.coalition_id = customer_point_tiers.coalition_id
               AND receiver_member.merchant_id = $4
          )`;
      } else {
        scopeSql = 'AND merchant_id IS NULL';
      }
      const { rows: tierRows } = await client.query(`
        SELECT id, balance, coalition_id
          FROM customer_point_tiers
         WHERE customer_id = $1 AND tier = $2 ${scopeSql} AND balance > 0
         ORDER BY updated_at ASC
         FOR UPDATE
      `, scopeValues);
      const available = tierRows.reduce((sum, row) => sum + Number(row.balance || 0), 0);
      if (available < points) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'insufficient_tier_points', availablePoints: available });
      }

      await debitTierRows(client, tierRows, points);
      await client.query(
        `UPDATE point_accounts SET available_points = available_points - $2, updated_at = NOW()
          WHERE owner_id = $1 AND available_points >= $2`,
        [customerId, points]
      );
      const reference = `coalition_redemption:${id()}`;
      await client.query(
        `INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
        [id(), customerId, `${tier.toUpperCase()}_REDEMPTION`, points, -points, reference]
      );

      let settledBalance = null;
      if (tier === 'gold') {
        settledBalance = await creditSettlementWallet(
          client, merchantId, customerId, reference, points, 'GOLD_REDEMPTION_SETTLED'
        );
      } else if (tier === 'silver' && issuingMerchantId !== merchantId) {
        const coalitionId = tierRows[0].coalition_id;
        const period = new Date().toISOString().slice(0, 7);
        await client.query(`
          INSERT INTO coalition_ledger
            (id, coalition_id, from_merchant_id, to_merchant_id, customer_id, points_redeemed, conversion_rate, net_points)
          VALUES ($1, $2, $3, $4, $5, $6, 1.0, $6)
        `, [id(), coalitionId, issuingMerchantId, merchantId, customerId, points]);
        await client.query(`
          INSERT INTO coalition_clearinghouse
            (id, coalition_id, from_merchant_id, to_merchant_id, period, total_points)
          VALUES ($1, $2, $3, $4, $5, $6)
          ON CONFLICT (coalition_id, from_merchant_id, to_merchant_id, period)
          DO UPDATE SET total_points = coalition_clearinghouse.total_points + EXCLUDED.total_points
        `, [id(), coalitionId, issuingMerchantId, merchantId, period, points]);
      }

      await client.query('COMMIT');
      return res.json({ ok: true, tier, pointsRedeemed: points, merchantId, settledBalance, clearingDebt: tier === 'silver' ? points : 0 });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'coalition_redemption_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.get('/api/merchant/settlement-wallet', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const { rows: [wallet] } = await pool.query(
      `SELECT settled_balance, currency, updated_at FROM merchant_settlement_wallets WHERE merchant_id = $1`,
      [merchantId]
    );
    return res.json({ merchantId, settledBalance: Number(wallet?.settled_balance || 0), currency: wallet?.currency || 'LYD', updatedAt: wallet?.updated_at || null });
  });
};