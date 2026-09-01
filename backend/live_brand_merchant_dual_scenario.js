// E2E test: Brand + Merchant Dual Point Engine (Co-Op Brand Loyalty)
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const BASE = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3006/api';
const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5434),
  user: process.env.PGUSER || 'kupuna_user',
  password: process.env.PGPASSWORD || 'b3c21618bf4c4aaf9caaf5892f51d93d',
  database: process.env.PGDATABASE || 'kupuna_db',
});

function uid(prefix) {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

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
  return { status: res.status, ok: res.ok, data };
}

async function login(email, password) {
  const r = await api('/auth/login', 'POST', { email, password });
  if (!r.ok) throw new Error(`login_failed:${email}:${JSON.stringify(r.data)}`);
  return r.data;
}

async function ensureUser({ email, password, fullName, role = 'customer' }) {
  const normalized = String(email).trim().toLowerCase();
  const existing = await pool.query('SELECT id, email, password_hash, role FROM users WHERE email = $1 LIMIT 1', [normalized]);
  if (existing.rows[0]) {
    const user = existing.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [await bcrypt.hash(password, 10), user.id]);
    }
    return user.id;
  }
  const userId = uid('user');
  const hash = await bcrypt.hash(password, 10);
  await pool.query(
    `INSERT INTO users (id, email, password_hash, role, full_name, profile_completed, points, points_history)
     VALUES ($1, $2, $3, $4, $5, TRUE, 0, '[]'::jsonb)`,
    [userId, normalized, hash, role, fullName || null]
  );
  return userId;
}

async function upsertMerchant({ email, password, businessName, pointValue }) {
  const userId = await ensureUser({ email, password, fullName: businessName, role: 'merchant' });
  const existing = await pool.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId]);
  let merchantId;
  if (existing.rows[0]) {
    merchantId = existing.rows[0].id;
    await pool.query(`UPDATE merchant_profiles SET business_name = $2, point_value = $3, status = 'active' WHERE user_id = $1`, [userId, businessName, pointValue]);
  } else {
    merchantId = uid('merchant');
    await pool.query(
      `INSERT INTO merchant_profiles (id, user_id, business_name, point_value, status, created_at)
       VALUES ($1, $2, $3, $4, 'active', NOW())`,
      [merchantId, userId, businessName, pointValue]
    );
  }
  await pool.query(
    `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
     VALUES ($1, 0, 'SAR', FALSE, NOW())
     ON CONFLICT (merchant_id) DO NOTHING`,
    [merchantId]
  );
  return { userId, merchantId };
}

async function upsertBrand({ email, password, businessName, pointValue }) {
  const userId = await ensureUser({ email, password, fullName: businessName, role: 'brand' });
  const existing = await pool.query('SELECT id FROM brand_profiles WHERE user_id = $1 LIMIT 1', [userId]);
  let brandId;
  if (existing.rows[0]) {
    brandId = existing.rows[0].id;
    await pool.query(`UPDATE brand_profiles SET business_name = $2, point_value = $3, status = 'active' WHERE user_id = $1`, [userId, businessName, pointValue]);
  } else {
    brandId = uid('brand');
    await pool.query(
      `INSERT INTO brand_profiles (id, user_id, business_name, point_value, status, created_at)
       VALUES ($1, $2, $3, $4, 'active', NOW())`,
      [brandId, userId, businessName, pointValue]
    );
  }
  await pool.query(
    `INSERT INTO brand_token_wallets (brand_id, balance, currency, is_local_mode, last_updated_at)
     VALUES ($1, 0, 'SAR', FALSE, NOW())
     ON CONFLICT (brand_id) DO NOTHING`,
    [brandId]
  );
  return { userId, brandId };
}

async function upsertCustomer({ email, password, fullName }) {
  const userId = await ensureUser({ email, password, fullName, role: 'customer' });
  await pool.query(
    `INSERT INTO customer_profiles (user_id, location_lat, location_lng, created_at)
     VALUES ($1, 24.7136, 46.6753, NOW())
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
  return userId;
}

async function createProduct(brandId, name) {
  const productId = uid('product');
  await pool.query(
    'INSERT INTO product_registry (id, brand_id, name) VALUES ($1,$2,$3)',
    [productId, brandId, name]
  );
  return productId;
}

async function setBrandWalletBalance(brandId, balance) {
  await pool.query(
    `UPDATE brand_token_wallets SET balance = $2, last_updated_at = NOW() WHERE brand_id = $1`,
    [brandId, balance]
  );
}

async function setMerchantWalletBalance(merchantId, balance) {
  await pool.query(
    `UPDATE merchant_token_wallets SET balance = $2, last_updated_at = NOW() WHERE merchant_id = $1`,
    [merchantId, balance]
  );
}

async function scanAndApproveInvoice({ customerToken, merchantToken, merchantId, totalAmount, invoiceNumber, lineItems }) {
  const scan = await api('/invoices/scan-v2', 'POST', {
    merchantProfileId: merchantId,
    totalAmount,
    invoiceNumber,
    invoiceDate: new Date().toISOString(),
    merchantName: 'Dual Points Test Store',
  }, customerToken);
  if (!scan.ok) throw new Error(`scan_failed:${JSON.stringify(scan.data)}`);
  const invoiceId = scan.data.id;

  const lineItemIds = [];
  if (lineItems.length > 0) {
    const li = await api(`/invoices/${invoiceId}/line-items`, 'POST', {
      items: lineItems.map((x) => ({ name: x.name, quantity: x.quantity, unitPrice: x.unitPrice, lineTotal: x.lineTotal })),
    }, merchantToken);
    if (!li.ok) throw new Error(`line_items_failed:${JSON.stringify(li.data)}`);
    lineItemIds.push(...li.data.lineItemIds);

    const matches = lineItems.map((x, i) => ({ invoiceLineItemId: lineItemIds[i], brandId: x.brandId, productId: x.productId || null, confidence: 1 }));
    const bm = await api(`/invoices/${invoiceId}/brand-matches`, 'POST', { matches }, merchantToken);
    if (!bm.ok) throw new Error(`brand_matches_failed:${JSON.stringify(bm.data)}`);
  }

  const approve = await api(`/invoices/${invoiceId}/state-transition`, 'POST', { to: 'approved' }, merchantToken);
  if (!approve.ok) throw new Error(`approve_failed:${JSON.stringify(approve.data)}`);

  return invoiceId;
}

async function getLatestNotification(userId) {
  const { rows: [n] } = await pool.query(
    `SELECT type, title, body, payload FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [userId]
  );
  return n;
}

async function main() {
  console.log('🚀 STARTING LIVE BRAND + MERCHANT DUAL POINT ENGINE E2E TEST\n');
  const results = { scenarios: [], status: 'RUNNING' };
  const ts = Date.now();

  console.log('📝 Step 1: Creating Merchant A, Brand Tory, Brand Pepsi, 3 Customers...');
  const merchantA = await upsertMerchant({ email: `dual.merchant.a.${ts}@kupuna.test`, password: 'Passw0rd!', businessName: 'Merchant A (Dual)', pointValue: 5 });
  const tory = await upsertBrand({ email: `dual.brand.tory.${ts}@kupuna.test`, password: 'Passw0rd!', businessName: 'توري (Tory)', pointValue: 1 });
  const pepsi = await upsertBrand({ email: `dual.brand.pepsi.${ts}@kupuna.test`, password: 'Passw0rd!', businessName: 'ببسي (Pepsi)', pointValue: 1 });
  const alpha = await upsertCustomer({ email: `dual.customer.alpha.${ts}@kupuna.test`, password: 'Passw0rd!', fullName: 'Customer_Alpha' });
  const beta = await upsertCustomer({ email: `dual.customer.beta.${ts}@kupuna.test`, password: 'Passw0rd!', fullName: 'Customer_Beta' });
  const gamma = await upsertCustomer({ email: `dual.customer.gamma.${ts}@kupuna.test`, password: 'Passw0rd!', fullName: 'Customer_Gamma' });
  console.log(`✅ Merchant A: ${merchantA.merchantId}`);
  console.log(`✅ Brand Tory: ${tory.brandId}`);
  console.log(`✅ Brand Pepsi: ${pepsi.brandId}`);
  console.log(`✅ Customers: Alpha=${alpha}, Beta=${beta}, Gamma=${gamma}\n`);

  const toryProductId = await createProduct(tory.brandId, 'Tory Item A');
  const pepsiProductId = await createProduct(pepsi.brandId, 'Pepsi Can');

  console.log('📝 Step 2: Funding Wallets (Merchant + Tory funded, Pepsi left EMPTY to test Pending Queue)...');
  await setMerchantWalletBalance(merchantA.merchantId, 10000);
  await setBrandWalletBalance(tory.brandId, 1000);
  await setBrandWalletBalance(pepsi.brandId, 0);
  console.log('✅ Merchant A wallet: 10000, Tory wallet: 1000, Pepsi wallet: 0 (forces pending)\n');

  const merchantToken = (await login(`dual.merchant.a.${ts}@kupuna.test`, 'Passw0rd!')).token;
  const alphaToken = (await login(`dual.customer.alpha.${ts}@kupuna.test`, 'Passw0rd!')).token;
  const betaToken = (await login(`dual.customer.beta.${ts}@kupuna.test`, 'Passw0rd!')).token;
  const gammaToken = (await login(`dual.customer.gamma.${ts}@kupuna.test`, 'Passw0rd!')).token;
  const pepsiToken = (await login(`dual.brand.pepsi.${ts}@kupuna.test`, 'Passw0rd!')).token;

  console.log('📝 Step 3: Invoice 1 (Customer_Alpha) — 100 LYD store + 1x Tory + 2x Pepsi...');
  const inv1 = await scanAndApproveInvoice({
    customerToken: alphaToken,
    merchantToken,
    merchantId: merchantA.merchantId,
    totalAmount: 100,
    invoiceNumber: `DUAL-A-${ts}`,
    lineItems: [
      { name: 'Tory Item A', quantity: 1, unitPrice: 5, lineTotal: 5, brandId: tory.brandId, productId: toryProductId },
      { name: 'Pepsi Can', quantity: 2, unitPrice: 2, lineTotal: 4, brandId: pepsi.brandId, productId: pepsiProductId },
    ],
  });
  console.log(`✅ Invoice 1 approved: ${inv1}\n`);

  console.log('📝 Step 4: Invoice 2 (Customer_Beta) — 50 LYD store + 3x Pepsi (no Tory)...');
  const inv2 = await scanAndApproveInvoice({
    customerToken: betaToken,
    merchantToken,
    merchantId: merchantA.merchantId,
    totalAmount: 50,
    invoiceNumber: `DUAL-B-${ts}`,
    lineItems: [
      { name: 'Pepsi Can', quantity: 3, unitPrice: 2, lineTotal: 6, brandId: pepsi.brandId, productId: pepsiProductId },
    ],
  });
  console.log(`✅ Invoice 2 approved: ${inv2}\n`);

  console.log('📝 Step 5: Invoice 3 (Customer_Gamma) — 2x Tory Items only...');
  const inv3 = await scanAndApproveInvoice({
    customerToken: gammaToken,
    merchantToken,
    merchantId: merchantA.merchantId,
    totalAmount: 25,
    invoiceNumber: `DUAL-C-${ts}`,
    lineItems: [
      { name: 'Tory Item A', quantity: 2, unitPrice: 5, lineTotal: 10, brandId: tory.brandId, productId: toryProductId },
    ],
  });
  console.log(`✅ Invoice 3 approved: ${inv3}\n`);

  console.log('📝 Step 6: Validating Per-Customer Point Calculations...');
  async function getSources(userId) {
    const { rows: [account] } = await pool.query('SELECT available_points, lifetime_points FROM point_accounts WHERE owner_id = $1', [userId]);
    const { rows: merchantSrc } = await pool.query(
      `SELECT m.business_name, SUM(plm.points_delta) AS points FROM points_ledger_merchant plm
       JOIN merchant_profiles m ON m.id = plm.merchant_id WHERE plm.customer_id = $1 GROUP BY m.business_name`,
      [userId]
    );
    const { rows: brandSrc } = await pool.query(
      `SELECT b.business_name, SUM(plb.points_delta) AS points FROM points_ledger_brand plb
       JOIN brand_profiles b ON b.id = plb.brand_id WHERE plb.customer_id = $1 AND plb.status = 'active' GROUP BY b.business_name`,
      [userId]
    );
    const { rows: pendingBrand } = await pool.query(
      `SELECT b.business_name, SUM(p.points_remaining) AS points FROM customer_pending_brand_points p
       JOIN brand_profiles b ON b.id = p.brand_id WHERE p.customer_id = $1 AND p.status IN ('PENDING','PARTIALLY_CLEARED') GROUP BY b.business_name`,
      [userId]
    );
    return { account, merchantSrc, brandSrc, pendingBrand };
  }

  const alphaSrc = await getSources(alpha);
  const betaSrc = await getSources(beta);
  const gammaSrc = await getSources(gamma);

  function check(name, actual, expected) {
    const pass = actual === expected;
    console.log(`   ${pass ? '✅' : '❌'} ${name}: actual=${actual}, expected=${expected}`);
    results.scenarios.push({ name, actual, expected, pass });
    return pass;
  }

  console.log('\n--- Customer_Alpha ---');
  check('Alpha Merchant Points', Number(alphaSrc.merchantSrc[0]?.points || 0), 20);
  check('Alpha Tory Points (active)', Number(alphaSrc.brandSrc.find((r) => r.business_name.includes('Tory'))?.points || 0), 5);
  check('Alpha Pepsi Points (pending, not active)', Number(alphaSrc.brandSrc.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 0);
  check('Alpha Pepsi Pending Points', Number(alphaSrc.pendingBrand.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 4);

  console.log('\n--- Customer_Beta ---');
  check('Beta Merchant Points', Number(betaSrc.merchantSrc[0]?.points || 0), 10);
  check('Beta Pepsi Pending Points', Number(betaSrc.pendingBrand.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 6);

  console.log('\n--- Customer_Gamma ---');
  check('Gamma Merchant Points', Number(gammaSrc.merchantSrc[0]?.points || 0), 5);
  check('Gamma Tory Points (active)', Number(gammaSrc.brandSrc.find((r) => r.business_name.includes('Tory'))?.points || 0), 10);

  console.log('\n📝 Step 7: Verifying Itemized Notification Messages...');
  const alphaNotif = await getLatestNotification(alpha);
  console.log(`   Alpha notification: "${alphaNotif?.body}"`);
  results.scenarios.push({ name: 'Alpha itemized notification contains merchant+brand breakdown', actual: alphaNotif?.body, pass: /نقطة/.test(alphaNotif?.body || '') });

  console.log('\n📝 Step 8: Verifying Atomic Wallet Deductions...');
  const { rows: [merchantWallet] } = await pool.query('SELECT balance FROM merchant_token_wallets WHERE merchant_id = $1', [merchantA.merchantId]);
  const { rows: [toryWallet] } = await pool.query('SELECT balance FROM brand_token_wallets WHERE brand_id = $1', [tory.brandId]);
  const { rows: [pepsiWallet] } = await pool.query('SELECT balance FROM brand_token_wallets WHERE brand_id = $1', [pepsi.brandId]);
  check('Merchant A wallet deducted (10000 - 35)', Number(merchantWallet.balance), 10000 - (20 + 10 + 5));
  check('Tory wallet deducted (1000 - 15)', Number(toryWallet.balance), 1000 - (5 + 10));
  check('Pepsi wallet unchanged (still 0, points pending)', Number(pepsiWallet.balance), 0);

  console.log('\n📝 Step 9: Recharging Pepsi Wallet to Clear Pending Queue...');
  const recharge = await api('/brand/tokens/recharge', 'POST', { amount: 100 }, pepsiToken);
  console.log(`   Recharge result: ${JSON.stringify(recharge.data)}`);
  results.scenarios.push({ name: 'Pepsi wallet recharge succeeded', actual: recharge.ok, pass: recharge.ok === true });

  const alphaSrcAfter = await getSources(alpha);
  const betaSrcAfter = await getSources(beta);
  console.log('\n--- After Pepsi Recharge ---');
  check('Alpha Pepsi Points now ACTIVE', Number(alphaSrcAfter.brandSrc.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 4);
  check('Beta Pepsi Points now ACTIVE', Number(betaSrcAfter.brandSrc.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 6);
  check('Alpha Pepsi pending cleared', Number(alphaSrcAfter.pendingBrand.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 0);
  check('Beta Pepsi pending cleared', Number(betaSrcAfter.pendingBrand.find((r) => r.business_name.includes('Pepsi'))?.points || 0), 0);

  const allPassed = results.scenarios.every((s) => s.pass);
  results.status = allPassed ? 'PASS' : 'FAIL';

  console.log('\n' + '='.repeat(70));
  console.log(allPassed ? '✅ 100% BRAND+MERCHANT DUAL POINT E2E TEST PASSED!' : '❌ SOME SCENARIOS FAILED');
  console.log('='.repeat(70));
  console.log('\n📊 STRUCTURED REPORT:');
  console.log(JSON.stringify({
    scenario: 'brand_merchant_dual_points_scenario',
    status: results.status,
    merchant: { id: merchantA.merchantId, pointValue: 5 },
    brands: { tory: tory.brandId, pepsi: pepsi.brandId },
    customers: { alpha, beta, gamma },
    invoices: { inv1, inv2, inv3 },
    checks: results.scenarios,
  }, null, 2));

  await pool.end();
  process.exit(allPassed ? 0 : 1);
}

main().catch((e) => {
  console.error('FATAL ERROR:', e);
  process.exit(1);
});
