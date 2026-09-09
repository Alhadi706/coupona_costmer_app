const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const API = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3018/api';
const stamp = Date.now();
const password = 'CoalitionTierTest123!';
const pool = new Pool({
  host: process.env.TEST_PGHOST || '127.0.0.1',
  port: Number(process.env.TEST_PGPORT || 5434),
  user: process.env.TEST_PGUSER || 'kupuna_user',
  password: process.env.TEST_PGPASSWORD || process.env.PGPASSWORD,
  database: process.env.TEST_PGDATABASE || 'kupuna_db',
});

async function api(path, method = 'GET', body = null, token = null) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }
  return { status: response.status, data };
}

function unique(prefix) {
  return `${prefix}_${stamp}_${Math.random().toString(36).slice(2, 8)}`;
}

async function createUser(role, name) {
  const userId = unique('user');
  const email = `${name.toLowerCase().replaceAll(' ', '.')}.${stamp}@kupuna.test`;
  await pool.query(`
    INSERT INTO users (id, email, password_hash, role, full_name, profile_completed, points, points_history)
    VALUES ($1, $2, $3, $4, $5, TRUE, 0, '[]'::jsonb)
  `, [userId, email, await bcrypt.hash(password, 4), role, name]);
  if (role === 'customer') {
    await pool.query(
      `INSERT INTO customer_profiles (user_id, created_at) VALUES ($1, NOW()) ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );
  }
  const login = await api('/auth/login', 'POST', { email, password });
  assert.equal(login.status, 200, `login failed for ${name}: ${JSON.stringify(login.data)}`);
  return { userId, email, token: login.data.token };
}

async function createMerchant(name, isGold = false) {
  const user = await createUser('merchant', name);
  const merchantId = unique('merchant');
  await pool.query(`
    INSERT INTO merchant_profiles
      (id, user_id, business_name, point_value, status, is_public_coalition_active, created_at)
    VALUES ($1, $2, $3, 1, 'active', $4, NOW())
  `, [merchantId, user.userId, name, isGold]);
  await pool.query(`
    INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
    VALUES ($1, 0, 'LYD', FALSE, NOW())
  `, [merchantId]);
  return { ...user, merchantId, name };
}

async function scanInvoice(customer, merchant, amount, suffix) {
  const result = await api('/invoices/scan', 'POST', {
    rawText: `${merchant.name} invoice ${suffix}`,
    merchantName: merchant.name,
    totalAmount: amount,
    invoiceNumber: `${suffix}-${stamp}`,
    invoiceDate: new Date().toISOString().slice(0, 10),
    currency: 'LYD',
  }, customer.token);
  assert.equal(result.status, 200, `invoice scan failed: ${JSON.stringify(result.data)}`);
  assert.equal(result.data.awards?.merchantPoints, amount);
  return result.data;
}

async function tierBalance(customerId, tier, merchantId = null) {
  const values = [customerId, tier];
  const merchantFilter = merchantId == null ? '' : 'AND merchant_id = $3';
  if (merchantId != null) values.push(merchantId);
  const { rows: [row] } = await pool.query(
    `SELECT COALESCE(SUM(balance), 0)::int AS balance FROM customer_point_tiers
      WHERE customer_id = $1 AND tier = $2 ${merchantFilter}`,
    values
  );
  return Number(row.balance);
}

async function main() {
  const createdUserIds = [];
  let silverCoalitionId = null;
  try {
    const merchantA = await createMerchant(`Tier Gold A ${stamp}`, true);
    const merchantB = await createMerchant(`Tier Gold B ${stamp}`, true);
    const merchantC = await createMerchant(`Tier Silver C ${stamp}`);
    const merchantD = await createMerchant(`Tier Silver D ${stamp}`);
    const customerX = await createUser('customer', `Tier Customer X ${stamp}`);
    const customerY = await createUser('customer', `Tier Customer Y ${stamp}`);
    createdUserIds.push(merchantA.userId, merchantB.userId, merchantC.userId, merchantD.userId, customerX.userId, customerY.userId);

    await pool.query(`UPDATE merchant_token_wallets SET balance = 100 WHERE merchant_id = $1`, [merchantA.merchantId]);

    const goldIssue = await scanInvoice(customerX, merchantA, 10, 'gold-issuance');
    assert.equal(goldIssue.awards.merchantTier, 'gold');
    const { rows: [walletAfterIssue] } = await pool.query(
      `SELECT balance FROM merchant_token_wallets WHERE merchant_id = $1`, [merchantA.merchantId]
    );
    assert.equal(Number(walletAfterIssue.balance), 90);
    assert.equal(await tierBalance(customerX.userId, 'gold'), 10);
    const { rows: [goldLedger] } = await pool.query(
      `SELECT type, customer_user_id FROM merchant_token_ledger WHERE receipt_id = $1`, [goldIssue.id]
    );
    assert.equal(goldLedger.type, 'ISSUANCE_GOLD');
    assert.equal(goldLedger.customer_user_id, customerX.userId);

    const voucher = await api('/customer/coalition/gold-voucher', 'POST', { amount: 3 }, customerX.token);
    assert.equal(voucher.status, 201, JSON.stringify(voucher.data));
    await pool.query(`UPDATE merchant_profiles SET status = 'inactive' WHERE id = $1`, [merchantA.merchantId]);
    assert.equal(await tierBalance(customerX.userId, 'gold'), 7);
    const { rows: [voucherRow] } = await pool.query(
      `SELECT value_lyd, status FROM customer_gold_vouchers WHERE id = $1`, [voucher.data.voucherId]
    );
    assert.deepEqual([Number(voucherRow.value_lyd), voucherRow.status], [3, 'ACTIVE']);

    const goldRedeem = await api('/customer/coalition/redeem', 'POST', {
      merchantId: merchantB.merchantId,
      tier: 'gold',
      points: 5,
    }, customerX.token);
    assert.equal(goldRedeem.status, 200, JSON.stringify(goldRedeem.data));
    assert.equal(goldRedeem.data.settledBalance, 5);
    assert.equal(goldRedeem.data.clearingDebt, 0);
    assert.equal(await tierBalance(customerX.userId, 'gold'), 2);
    const { rows: [goldDebt] } = await pool.query(`
      SELECT COUNT(*)::int AS count FROM coalition_ledger
       WHERE customer_id = $1 AND from_merchant_id = $2 AND to_merchant_id = $3
    `, [customerX.userId, merchantA.merchantId, merchantB.merchantId]);
    assert.equal(goldDebt.count, 0);

    await pool.query(`UPDATE merchant_profiles SET status = 'active' WHERE id = $1`, [merchantA.merchantId]);
    await pool.query(`UPDATE merchant_token_wallets SET balance = 0, is_local_mode = FALSE WHERE merchant_id = $1`, [merchantA.merchantId]);
    const bronzeIssue = await scanInvoice(customerY, merchantA, 4, 'bronze-fallback');
    assert.equal(bronzeIssue.awards.merchantTier, 'bronze');
    assert.equal(bronzeIssue.degradedLocalMode, true);
    assert.equal(await tierBalance(customerY.userId, 'bronze', merchantA.merchantId), 4);
    const restricted = await api('/customer/coalition/redeem', 'POST', {
      merchantId: merchantB.merchantId,
      issuingMerchantId: merchantA.merchantId,
      tier: 'bronze',
      points: 1,
    }, customerY.token);
    assert.equal(restricted.status, 409);
    assert.equal(restricted.data.error, 'Points restricted to issuing store only');
    const recharge = await api('/merchant/tokens/recharge', 'POST', { amount: 50 }, merchantA.token);
    assert.equal(recharge.status, 200, JSON.stringify(recharge.data));
    assert.equal(recharge.data.isLocalMode, false);
    const recoveredIssue = await scanInvoice(customerY, merchantA, 5, 'gold-recovered');
    assert.equal(recoveredIssue.awards.merchantTier, 'gold');
    assert.equal(recoveredIssue.awards.merchantTokenBalance, 45);

    silverCoalitionId = unique('silver_coalition');
    await pool.query(`
      INSERT INTO coalitions (id, name, type, created_by, is_active)
      VALUES ($1, $2, 'private', $3, TRUE)
    `, [silverCoalitionId, `Silver Test ${stamp}`, merchantC.merchantId]);
    await pool.query(`
      INSERT INTO coalition_members (coalition_id, merchant_id)
      VALUES ($1, $2), ($1, $3)
    `, [silverCoalitionId, merchantC.merchantId, merchantD.merchantId]);
    const silverC = await scanInvoice(customerX, merchantC, 20, 'silver-c');
    const silverD = await scanInvoice(customerX, merchantD, 5, 'silver-d');
    assert.equal(silverC.awards.merchantTier, 'silver');
    assert.equal(silverD.awards.merchantTier, 'silver');

    const redeemAtD = await api('/customer/coalition/redeem', 'POST', {
      merchantId: merchantD.merchantId,
      issuingMerchantId: merchantC.merchantId,
      tier: 'silver',
      points: 20,
    }, customerX.token);
    const redeemAtC = await api('/customer/coalition/redeem', 'POST', {
      merchantId: merchantC.merchantId,
      issuingMerchantId: merchantD.merchantId,
      tier: 'silver',
      points: 5,
    }, customerX.token);
    assert.equal(redeemAtD.status, 200, JSON.stringify(redeemAtD.data));
    assert.equal(redeemAtC.status, 200, JSON.stringify(redeemAtC.data));

    const clearingC = await api('/merchant/coalition/clearing', 'GET', null, merchantC.token);
    const clearingD = await api('/merchant/coalition/clearing', 'GET', null, merchantD.token);
    assert.equal(clearingC.status, 200, JSON.stringify(clearingC.data));
    assert.equal(clearingD.status, 200, JSON.stringify(clearingD.data));
    assert.ok(Array.isArray(clearingC.data.matrix) && clearingC.data.matrix.length > 0);
    assert.equal(clearingC.data.summary.netBalance, -15);
    assert.equal(clearingD.data.summary.netBalance, 15);
    assert.equal(clearingC.data.matrix[0].netBalance, -15);
    assert.equal(clearingD.data.matrix[0].netBalance, 15);

    console.log(JSON.stringify({
      status: 'PASS',
      gold: { prepaidWallet: '100 -> 90', customerPoints: '10 -> 7 -> 2', voucherLyD: 3, merchantBSettledLyD: 5, clearingDebt: 0 },
      bronze: { fallback: true, restrictedAtMerchantB: true, recharge: '0 -> 50', recoveredGoldWallet: 45 },
      silver: { merchantCNetLyD: -15, merchantDNetLyD: 15, matrixRows: clearingC.data.matrix.length },
    }, null, 2));
  } finally {
    if (silverCoalitionId) await pool.query('DELETE FROM coalitions WHERE id = $1', [silverCoalitionId]).catch(() => {});
    if (createdUserIds.length > 0) await pool.query('DELETE FROM users WHERE id = ANY($1::text[])', [createdUserIds]).catch(() => {});
    await pool.end();
  }
}

main().catch((error) => {
  console.error('COALITION_TIER_WALLET_E2E_FAILED', error.stack || error);
  process.exitCode = 1;
});