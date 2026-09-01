const { execSync } = require('child_process');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const API = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3017/api';
const PASSWORD = 'WalletTest123!';
const stamp = Date.now();

async function api(path, method = 'GET', body = null, token = null, headers = {}) {
  const requestHeaders = { 'Content-Type': 'application/json', ...headers };
  if (token) requestHeaders.Authorization = token.startsWith('RAW ') ? token.slice(4) : `Bearer ${token}`;
  const response = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    method,
    headers: requestHeaders,
    body: body ? JSON.stringify(body) : undefined,
  });
  const raw = await response.text();
  let data = {};
  try { data = raw ? JSON.parse(raw) : {}; } catch { data = { raw }; }
  return { status: response.status, ok: response.ok, data };
}

async function signup(email, role = 'customer') {
  return api('/auth/signup', 'POST', {
    email,
    password: PASSWORD,
    role,
    fullName: `${role} Test`,
    gender: 'male',
    birthDate: '1990-01-01',
  });
}

async function login(email, password = PASSWORD) {
  return api('/auth/login', 'POST', { email, password });
}

async function main() {
  const email = `wallet.merchant.${stamp}@kupuna.test`;
  const signupResult = await signup(email, 'customer');
  const loginResult = await login(email);
  if (!loginResult.ok) {
    console.log(JSON.stringify({ status: 'FAIL', reason: 'signup/login failed', signupResult, loginResult }));
    process.exit(1);
  }
  const token = loginResult.data.token;
  const userId = loginResult.data.userId;

  const dbPassword = execSync("grep '^POSTGRES_PASSWORD=' /opt/projects/kupuna/docker/.env | cut -d= -f2-", { encoding: 'utf8' }).trim();
  const pool = new Pool({ host: '127.0.0.1', port: 5434, user: 'kupuna_user', password: dbPassword, database: 'kupuna_db' });
  const merchantId = `merchant_wallet_${stamp}`;
  const merchantName = `Wallet Merchant ${stamp}`;

  await pool.query(`
    INSERT INTO merchant_profiles (id, user_id, business_name, status, point_value)
    VALUES ($1, $2, $3, 'active', 10)
    ON CONFLICT (id) DO NOTHING
  `, [merchantId, userId, merchantName]);

  const statusBefore = await api(`/merchant/tokens/${merchantId}/status`, 'GET', null, token);
  const recharge = await api('/merchant/tokens/recharge', 'POST', { merchantId, amount: 150 }, token);
  const statusAfter = await api(`/merchant/tokens/${merchantId}/status`, 'GET', null, token);
  const localSpend = await api('/merchant/tokens/local-points', 'POST', { merchantId, points: 35, receiptId: `receipt_${stamp}`, customerUserId: userId, is_local_only: true }, token);
  const drainSpend = await api('/merchant/tokens/local-points', 'POST', { merchantId, points: 115, receiptId: `receipt_drain_${stamp}`, customerUserId: userId, is_local_only: true }, token);
  const statusFinal = await api(`/merchant/tokens/${merchantId}/status`, 'GET', null, token);
  const invoiceScan = await api('/invoices/scan', 'POST', {
    rawText: 'Wallet Merchant receipt',
    merchantName,
    totalAmount: 10,
    invoiceNumber: `wallet_invoice_${stamp}`,
    invoiceDate: new Date().toISOString().slice(0, 10),
  }, token);

  console.log(JSON.stringify({
    statusBefore,
    recharge,
    statusAfter,
    localSpend,
    drainSpend,
    statusFinal,
    invoiceScan,
  }, null, 2));

  const ok = statusBefore.status === 200 &&
    recharge.status === 200 &&
    Number(statusAfter.data.balance || 0) === 150 &&
    localSpend.status === 200 &&
    Number(statusFinal.data.balance || 0) === 0 &&
    statusFinal.data.isLocalMode === true &&
    drainSpend.data.isLocalMode === true &&
    invoiceScan.status === 200 &&
    invoiceScan.data.degradedLocalMode === true;

  if (!ok) {
    process.exit(1);
  }

  await pool.end();
}

main().catch((error) => {
  console.error('MERCHANT_PREPAID_WALLET_REGRESSION_FAILED', error.message || error);
  process.exit(1);
});
