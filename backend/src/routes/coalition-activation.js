// App Store compliant activation flow: no in-app payments.
// Merchants redeem platform-issued activation codes to top up their Gold
// prepaid balance; admins can also top up any merchant wallet manually.
module.exports = function registerCoalitionActivationRoutes(app, deps) {
  const {
    pool,
    auth,
    requireAdmin,
    id,
    toIso,
    getMerchantProfileIdByUser,
    clearPendingPointsQueue,
    insertNotification,
  } = deps;

  const PUBLIC_COALITION_ID = 'public-platform-coalition';
  const MINIMUM_ACTIVATION_BALANCE = 1000;

  async function ensureWallet(client, merchantId) {
    await client.query(
      `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
       VALUES ($1, 0, 'LYD', FALSE, NOW())
       ON CONFLICT (merchant_id) DO NOTHING`,
      [merchantId]
    );
  }

  async function creditGoldWallet(client, { merchantId, amount, ledgerType }) {
    await ensureWallet(client, merchantId);
    const wallet = (await client.query(
      `SELECT balance FROM merchant_token_wallets WHERE merchant_id = $1 FOR UPDATE`,
      [merchantId]
    )).rows[0];
    const newBalance = Number(wallet?.balance || 0) + Math.round(amount);
    await client.query(
      `UPDATE merchant_token_wallets
          SET balance = $2, is_local_mode = FALSE, last_updated_at = NOW()
        WHERE merchant_id = $1`,
      [merchantId, newBalance]
    );
    await client.query(
      `INSERT INTO merchant_token_ledger (id, merchant_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
       VALUES ($1, $2, NULL, NULL, $3, $4, $5, NOW())`,
      [id(), merchantId, ledgerType, Math.round(amount), newBalance]
    );
    return newBalance;
  }

  async function enableGoldStatus(client, merchantId) {
    await client.query(
      `INSERT INTO coalition_members (coalition_id, merchant_id)
       VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [PUBLIC_COALITION_ID, merchantId]
    );
    await client.query(
      `UPDATE merchant_profiles SET is_public_coalition_active = TRUE WHERE id = $1`,
      [merchantId]
    );
  }

  app.post('/api/merchant/coalition/activate-code', auth, async (req, res) => {
    const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_profile_required' });
    const code = String(req.body?.code || '').trim();
    if (!code) return res.status(400).json({ error: 'activation_code_required' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const codeRow = (await client.query(
        `SELECT * FROM coalition_activation_codes WHERE code = $1 FOR UPDATE`,
        [code]
      )).rows[0];
      if (!codeRow || codeRow.status !== 'active') {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'activation_code_invalid_or_used' });
      }

      const newBalance = await creditGoldWallet(client, {
        merchantId,
        amount: Number(codeRow.points_amount),
        ledgerType: 'activation_code',
      });
      await client.query(
        `UPDATE coalition_activation_codes
            SET status = 'redeemed', redeemed_by_merchant_id = $2, redeemed_at = NOW()
          WHERE id = $1`,
        [codeRow.id, merchantId]
      );

      const goldActive = newBalance >= MINIMUM_ACTIVATION_BALANCE;
      if (goldActive) await enableGoldStatus(client, merchantId);
      await clearPendingPointsQueue(client, merchantId, insertNotification);

      const { rows: [profile] } = await client.query(
        `SELECT user_id FROM merchant_profiles WHERE id = $1`, [merchantId]
      );
      if (profile?.user_id) {
        await insertNotification(
          client,
          profile.user_id,
          'coalition_activation_code_redeemed',
          'Gold balance activated',
          `Your activation code credited ${Number(codeRow.points_amount)} points to your Gold prepaid balance.`,
          { merchantId, balance: newBalance, targetScreen: 'public_coalition_membership' }
        );
      }

      await client.query('COMMIT');
      return res.json({
        ok: true,
        merchantId,
        creditedPoints: Number(codeRow.points_amount),
        balance: newBalance,
        minimumActivationBalance: MINIMUM_ACTIVATION_BALANCE,
        isPublicCoalitionActive: goldActive,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'activation_code_redemption_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  app.post('/api/admin/merchant/:id/topup-gold-wallet', auth, requireAdmin, async (req, res) => {
    const merchantId = String(req.params.id || '').trim();
    const amount = Number(req.body?.amount ?? req.body?.points_amount);
    const note = String(req.body?.note || '').trim();
    if (!merchantId) return res.status(400).json({ error: 'merchant_id_required' });
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'invalid_amount' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows: [profile] } = await client.query(
        `SELECT id, user_id FROM merchant_profiles WHERE id = $1 FOR UPDATE`,
        [merchantId]
      );
      if (!profile) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'merchant_not_found' });
      }

      const newBalance = await creditGoldWallet(client, {
        merchantId,
        amount,
        ledgerType: 'admin_topup',
      });
      const goldActive = newBalance >= MINIMUM_ACTIVATION_BALANCE;
      if (goldActive) await enableGoldStatus(client, merchantId);
      await clearPendingPointsQueue(client, merchantId, insertNotification);

      await insertNotification(
        client,
        profile.user_id,
        'coalition_gold_wallet_topup',
        'Gold balance topped up',
        note || `The platform administration credited ${Math.round(amount)} points to your Gold prepaid balance.`,
        { merchantId, balance: newBalance, targetScreen: 'public_coalition_membership' }
      );

      await client.query('COMMIT');
      return res.json({
        ok: true,
        merchantId,
        balance: newBalance,
        minimumActivationBalance: MINIMUM_ACTIVATION_BALANCE,
        isPublicCoalitionActive: goldActive,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      return res.status(500).json({ error: 'admin_topup_failed', details: String(error.message || error) });
    } finally {
      client.release();
    }
  });

  // Platform issues activation codes off-store; merchants redeem them in-app.
  app.post('/api/admin/coalition/activation-codes', auth, requireAdmin, async (req, res) => {
    const pointsAmount = Number(req.body?.pointsAmount);
    const note = String(req.body?.note || '').trim();
    const requestedCode = String(req.body?.code || '').trim();
    if (!Number.isFinite(pointsAmount) || pointsAmount <= 0) {
      return res.status(400).json({ error: 'invalid_points_amount' });
    }
    const code = requestedCode || `GOLD-${id().slice(0, 8).toUpperCase()}`;
    try {
      const row = (await pool.query(
        `INSERT INTO coalition_activation_codes (id, code, points_amount, note, created_by_user_id)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [id(), code, Math.round(pointsAmount), note || null, req.user.userId]
      )).rows[0];
      return res.status(201).json({
        id: row.id,
        code: row.code,
        pointsAmount: Number(row.points_amount),
        status: row.status,
        note: row.note || null,
        createdAt: toIso(row.created_at),
      });
    } catch (error) {
      if (String(error?.code) === '23505') {
        return res.status(409).json({ error: 'activation_code_already_exists' });
      }
      return res.status(500).json({ error: 'activation_code_creation_failed', details: String(error.message || error) });
    }
  });

  app.get('/api/admin/coalition/activation-codes', auth, requireAdmin, async (req, res) => {
    const rows = (await pool.query(
      `SELECT c.*, mp.business_name AS redeemed_by_business_name
         FROM coalition_activation_codes c
         LEFT JOIN merchant_profiles mp ON mp.id = c.redeemed_by_merchant_id
        ORDER BY c.created_at DESC
        LIMIT 200`
    )).rows;
    return res.json(rows.map((row) => ({
      id: row.id,
      code: row.code,
      pointsAmount: Number(row.points_amount),
      status: row.status,
      note: row.note || null,
      redeemedByMerchantId: row.redeemed_by_merchant_id || null,
      redeemedByBusinessName: row.redeemed_by_business_name || null,
      redeemedAt: toIso(row.redeemed_at),
      createdAt: toIso(row.created_at),
    })));
  });
};
