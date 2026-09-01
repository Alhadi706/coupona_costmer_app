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

async function upsertMerchant({ email, password, businessName, pointValue = 10 }) {
  const userId = await ensureUser({ email, password, fullName: businessName, role: 'merchant' });
  const profileId = await pool.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId]);
  if (profileId.rows[0]) {
    await pool.query(
      `UPDATE merchant_profiles SET business_name = $2, point_value = $3, status = 'active' WHERE user_id = $1`,
      [userId, businessName, pointValue]
    );
    return profileId.rows[0].id;
  }
  const merchantId = uid('merchant');
  await pool.query(
    `INSERT INTO merchant_profiles (id, user_id, business_name, point_value, status, created_at)
     VALUES ($1, $2, $3, $4, 'active', NOW())`,
    [merchantId, userId, businessName, pointValue]
  );
  await pool.query(
    `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
     VALUES ($1, 0, 'SAR', FALSE, NOW())
     ON CONFLICT (merchant_id) DO NOTHING`,
    [merchantId]
  );
  return merchantId;
}

async function upsertCustomer({ email, password, fullName = 'Demo Customer' }) {
  const userId = await ensureUser({ email, password, fullName, role: 'customer' });
  await pool.query(
    `INSERT INTO customer_profiles (user_id, location_lat, location_lng, created_at)
     VALUES ($1, 24.7136, 46.6753, NOW())
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
  return userId;
}

async function createCoalitionWithMembers({ coalitionName, merchants, type = 'private' }) {
  const coalitionId = uid('coalition');
  await pool.query(
    `INSERT INTO coalitions (id, name, type, category, region, created_by, is_active, created_at)
     VALUES ($1, $2, $3, 'demo', 'global', $4, TRUE, NOW())
     ON CONFLICT (id) DO NOTHING`,
    [coalitionId, coalitionName, type, merchants[0]]
  );
  for (const merchantId of merchants) {
    await pool.query(
      `INSERT INTO coalition_members (coalition_id, merchant_id, point_conversion_rate, joined_at)
       VALUES ($1, $2, 1.0, NOW())
       ON CONFLICT (coalition_id, merchant_id) DO NOTHING`,
      [coalitionId, merchantId]
    );
  }
  return coalitionId;
}

async function seedCustomerTiers(customerId) {
  const tierRows = [
    { tier: 'gold', balance: 160 },
    { tier: 'silver', balance: 90 },
    { tier: 'bronze', balance: 45 },
  ];
  for (const row of tierRows) {
    await pool.query(
      `INSERT INTO customer_point_tiers (id, customer_id, tier, merchant_id, coalition_id, balance, lifetime_earned, updated_at)
       VALUES ($1, $2, $3, NULL, NULL, $4, $4, NOW())
       ON CONFLICT (customer_id, tier, COALESCE(merchant_id, ''), COALESCE(coalition_id, ''))
       DO UPDATE SET balance = customer_point_tiers.balance + EXCLUDED.balance,
                     lifetime_earned = customer_point_tiers.lifetime_earned + EXCLUDED.lifetime_earned,
                     updated_at = NOW()`,
      [uid('tier'), customerId, row.tier, row.balance]
    );
  }
}

async function seedPendingPoints({ customerId, merchantId, coalitionId, points, tier = 'silver', invoiceSuffix = 'pending' }) {
  const invoiceId = uid('invoice');
  await pool.query(
    `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, raw_text, reward_applied, created_at)
     VALUES ($1, $2, $3, $4, $5, FALSE, NOW())
     ON CONFLICT (id) DO NOTHING`,
    [invoiceId, customerId, `Pending Demo ${invoiceSuffix}`, `pending-${invoiceSuffix}`, `Pending scenario ${invoiceSuffix}`,]
  );
  const pendingId = uid('pending');
  await pool.query(
    `INSERT INTO customer_pending_points (id, customer_id, merchant_id, invoice_id, points, points_remaining, tier, coalition_id, status, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'PENDING', NOW())
     ON CONFLICT (id) DO NOTHING`,
    [pendingId, customerId, merchantId, invoiceId, points, points, tier, coalitionId]
  );
}

async function seedCoalitionBalances({ customerId, coalitionId, merchants }) {
  const balances = [
    { merchantId: merchants[0], points: 120 },
    { merchantId: merchants[1], points: 75 },
    { merchantId: merchants[2], points: 45 },
  ];
  for (const row of balances) {
    await pool.query(
      `INSERT INTO customer_merchant_point_balances (customer_id, merchant_id, coalition_id, points_balance, last_updated)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (customer_id, merchant_id, coalition_id)
       DO UPDATE SET points_balance = customer_merchant_point_balances.points_balance + EXCLUDED.points_balance,
                     last_updated = NOW()`,
      [customerId, row.merchantId, coalitionId, row.points]
    );
  }
}

async function setMerchantWalletBalance(merchantId, balance) {
  await pool.query(
    `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
     VALUES ($1, $2, 'SAR', FALSE, NOW())
     ON CONFLICT (merchant_id) DO UPDATE SET balance = EXCLUDED.balance, is_local_mode = FALSE, last_updated_at = NOW()`,
    [merchantId, balance]
  );
}

async function ensurePointAccount(userId, availablePoints) {
  await pool.query(
    `INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at)
     VALUES ($1, $2, $2, NOW())
     ON CONFLICT (owner_id) DO UPDATE SET available_points = EXCLUDED.available_points,
                                           lifetime_points = EXCLUDED.lifetime_points,
                                           updated_at = NOW()`,
    [userId, availablePoints]
  );
  await pool.query(
    `UPDATE users
        SET points = $2
      WHERE id = $1`,
    [userId, availablePoints]
  );
}

async function main() {
  const merchantAEmail = `coalition.merchant.a.${Date.now()}@kupuna.test`;
  const merchantBEmail = `coalition.merchant.b.${Date.now()}@kupuna.test`;
  const merchantCEmail = `coalition.merchant.c.${Date.now()}@kupuna.test`;
  const customerEmail = `coalition.customer.${Date.now()}@kupuna.test`;
  const merchantPassword = 'Test1234!';
  const customerPassword = 'Test1234!';

  const merchantAId = await upsertMerchant({ email: merchantAEmail, password: merchantPassword, businessName: 'Coalition Merchant A', pointValue: 10 });
  const merchantBId = await upsertMerchant({ email: merchantBEmail, password: merchantPassword, businessName: 'Coalition Merchant B', pointValue: 8 });
  const merchantCId = await upsertMerchant({ email: merchantCEmail, password: merchantPassword, businessName: 'Coalition Merchant C', pointValue: 6 });
  const customerId = await upsertCustomer({ email: customerEmail, password: customerPassword, fullName: 'Coalition Demo Customer' });

  const coalitionId = await createCoalitionWithMembers({ coalitionName: `Demo Coalition ${Date.now()}`, merchants: [merchantAId, merchantBId, merchantCId], type: 'private' });

  await seedCustomerTiers(customerId);
  await ensurePointAccount(customerId, 450);
  await seedCoalitionBalances({ customerId, coalitionId, merchants: [merchantAId, merchantBId, merchantCId] });

  await setMerchantWalletBalance(merchantAId, 220);
  await setMerchantWalletBalance(merchantBId, 120);
  await setMerchantWalletBalance(merchantCId, 90);

  await seedPendingPoints({ customerId, merchantId: merchantAId, coalitionId, points: 65, tier: 'gold', invoiceSuffix: 'a' });
  await seedPendingPoints({ customerId, merchantId: merchantBId, coalitionId, points: 40, tier: 'silver', invoiceSuffix: 'b' });
  await seedPendingPoints({ customerId, merchantId: merchantCId, coalitionId, points: 25, tier: 'bronze', invoiceSuffix: 'c' });

  const merchantAToken = (await login(merchantAEmail, merchantPassword)).token;
  const customerToken = (await login(customerEmail, customerPassword)).token;

  const recharge = await api('/merchant/tokens/recharge', 'POST', { amount: 150 }, merchantAToken);
  const pendingSummary = await api('/merchant/wallet/pending-points', 'GET', null, merchantAToken);
  const customerTiers = await api('/customer/wallet/tiers', 'GET', null, customerToken);
  const customerPending = await api('/customer/wallet/pending-points', 'GET', null, customerToken);

  const giftCreate = await api(`/merchant/coalitions/${coalitionId}/gifts`, 'POST', {
    title: 'Coalition Demo Gift',
    description: 'Redeem shared points across coalition merchants.',
    required_points: 90,
    monetary_value: 100,
    campaign_type: 'standard',
    quantity_limit: 5,
  }, merchantAToken);

  const giftId = giftCreate.data?.gift_id;
  const balancesBeforeRedeem = await api(`/customer/coalitions/${coalitionId}/balances`, 'GET', null, customerToken);
  const redemption = giftId
    ? await api('/customer/coalitions/redeem-gift', 'POST', {
        gift_id: giftId,
        fulfiller_merchant_id: merchantAId,
      }, customerToken)
    : { ok: false, data: { error: 'gift_not_created' } };

  const ledger = await api('/merchant/coalitions/ledger', 'GET', null, merchantAToken);

  const summary = {
    scenario: 'live_coalition_integrated_scenario',
    merchants: { merchantAId, merchantBId, merchantCId, merchantAEmail, merchantBEmail, merchantCEmail },
    customer: { customerId, email: customerEmail },
    coalitionId,
    recharge,
    pendingSummary,
    customerTiers,
    customerPending,
    giftCreate,
    balancesBeforeRedeem,
    redemption,
    ledger,
  };

  console.log(JSON.stringify(summary, null, 2));
  await pool.end();
}

main().catch((err) => {
  console.error('LIVE_COALITION_INTEGRATED_SCENARIO_FAILED');
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
