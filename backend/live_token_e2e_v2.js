const BASE = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3006/api';
const MERCHANT_EMAIL = process.env.MERCHANT_EMAIL || 'ahmed.stage9.20260822221230681@kupuna.test';
const MERCHANT_PASSWORD = process.env.MERCHANT_PASSWORD || 'Test1234!';

async function api(path, method = 'GET', body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text };
  }

  return {
    status: res.status,
    ok: res.ok,
    data,
  };
}

async function login(email, password) {
  const r = await api('/auth/login', 'POST', { email, password });
  if (!r.ok) {
    throw new Error(`login_failed:${email}:${JSON.stringify(r.data)}`);
  }
  return r.data;
}

async function signup(email, password, fullName) {
  const r = await api('/auth/signup', 'POST', {
    email,
    password,
    fullName,
    gender: 'male',
    birthDate: '1990-01-01',
    locationLat: 32.8872,
    locationLng: 13.1913,
  });
  if (!r.ok) {
    throw new Error(`signup_failed:${email}:${JSON.stringify(r.data)}`);
  }
  return r.data;
}

async function ensureCustomer() {
  const email = `live.customer.${Date.now()}.${Math.floor(Math.random() * 100000)}@kupuna.test`;
  const password = 'Test1234!';
  const safeName = 'Live Customer';

  const loginRes = await api('/auth/login', 'POST', { email, password });
  if (loginRes.ok) {
    return { email, password, token: loginRes.data.token, userId: loginRes.data.userId };
  }

  const signupRes = await signup(email, password, safeName);
  const loginAfterSignup = await login(email, password);
  return { email, password, token: loginAfterSignup.token, userId: loginAfterSignup.userId };
}

async function run() {
  const merchantLogin = await login(MERCHANT_EMAIL, MERCHANT_PASSWORD);
  const merchantToken = merchantLogin.token;

  const merchantProfile = await api('/merchant/profile', 'GET', null, merchantToken);
  if (!merchantProfile.ok) {
    throw new Error(`merchant_profile_failed:${JSON.stringify(merchantProfile.data)}`);
  }

  const beforeWallet = await api('/merchant/token-wallet/balance', 'GET', null, merchantToken);
  const customer = await ensureCustomer();

  const customerTierBefore = await api('/customer/wallet/tiers', 'GET', null, customer.token);
  const customerPendingBefore = await api('/customer/wallet/pending-points', 'GET', null, customer.token);

  const invoiceNumber = `LIVE-E2E-${Date.now()}`;
  const totalAmount = 95;
  const invoiceScan = await api('/invoices/scan', 'POST', {
    rawText: `Invoice ${invoiceNumber}\nMerchant: ${merchantProfile.data.businessName}\nTotal: ${totalAmount} SAR`,
    merchantName: merchantProfile.data.businessName,
    totalAmount,
    invoiceNumber,
    invoiceDate: new Date().toISOString().slice(0, 10),
    category: 'general',
    currency: 'SAR',
    items: [{ name: 'Live E2E Item', quantity: 1, unitPrice: totalAmount, lineTotal: totalAmount }],
  }, customer.token);

  const afterWallet = await api('/merchant/token-wallet/balance', 'GET', null, merchantToken);
  const customerTierAfter = await api('/customer/wallet/tiers', 'GET', null, customer.token);
  const customerPendingAfter = await api('/customer/wallet/pending-points', 'GET', null, customer.token);

  const recharge = await api('/merchant/tokens/recharge', 'POST', { amount: 100 }, merchantToken);
  const afterRechargeWallet = await api('/merchant/token-wallet/balance', 'GET', null, merchantToken);
  const merchantPendingSummary = await api('/merchant/wallet/pending-points', 'GET', null, merchantToken);
  const customerTierFinal = await api('/customer/wallet/tiers', 'GET', null, customer.token);

  const summary = {
    scenario: 'live_token_e2e_v2',
    merchant: {
      email: MERCHANT_EMAIL,
      businessName: merchantProfile.data.businessName,
      profileStatus: merchantProfile.data.status,
      balanceBefore: beforeWallet.data,
      balanceAfterInvoice: afterWallet.data,
      recharge: recharge.data,
      balanceAfterRecharge: afterRechargeWallet.data,
      pendingSummary: merchantPendingSummary.data,
    },
    customer: {
      email: customer.email,
      tiersBefore: customerTierBefore.data,
      pendingBefore: customerPendingBefore.data,
      invoiceScan: invoiceScan.data,
      tiersAfter: customerTierAfter.data,
      pendingAfter: customerPendingAfter.data,
      tiersFinal: customerTierFinal.data,
    },
  };

  console.log(JSON.stringify(summary, null, 2));
  return summary;
}

run().catch((err) => {
  console.error('LIVE_TOKEN_E2E_V2_FAILED');
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
