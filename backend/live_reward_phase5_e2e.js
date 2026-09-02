const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PGHOST,
  port: Number(process.env.PGPORT || 5432),
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE,
});

const baseUrl = `http://127.0.0.1:${process.env.PORT || 3006}`;
const rewardId = `phase5-reward-${crypto.randomUUID()}`;
const idempotencyKey = `phase5-request-${crypto.randomUUID()}`;
const pointsCost = 25;
let claimId = null;
let settlementId = null;
let merchantId = null;
let customerId = null;
let escrowId = null;
let escrowExisted = false;
let merchantWalletExisted = false;
let customerPointsBefore = 0;
let escrowBefore = 0;
let merchantWalletBefore = 0;

function token(user) {
  return jwt.sign({
    userId: user.id,
    email: user.email,
    role: user.role,
    tokenVersion: Number(user.token_version || 0),
    ownerMfaVerified: false,
  }, process.env.JWT_SECRET, { expiresIn: '5m' });
}

async function api(path, method, bearer, body) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${bearer}`,
      'Content-Type': 'application/json',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(`${method} ${path} ${response.status}: ${JSON.stringify(data)}`);
  return data;
}

async function cleanup() {
  if (claimId) {
    await pool.query('DELETE FROM merchant_token_ledger WHERE receipt_id = $1', [claimId]);
    await pool.query('DELETE FROM ledger_entries WHERE reference = $1', [`reward_claim:${claimId}`]);
    await pool.query('DELETE FROM coalition_ledger WHERE reward_claim_id = $1', [claimId]);
    await pool.query('DELETE FROM reward_claims WHERE id = $1', [claimId]);
  }
  if (settlementId) await pool.query('DELETE FROM settlements WHERE id = $1', [settlementId]);
  await pool.query('DELETE FROM rewards WHERE id = $1', [rewardId]);
  if (customerId) {
    await pool.query('UPDATE point_accounts SET available_points = $2 WHERE owner_id = $1', [customerId, customerPointsBefore]);
  }
  if (merchantId) {
    if (merchantWalletExisted) {
      await pool.query('UPDATE merchant_token_wallets SET balance = $2 WHERE merchant_id = $1', [merchantId, merchantWalletBefore]);
    } else {
      await pool.query('DELETE FROM merchant_token_wallets WHERE merchant_id = $1', [merchantId]);
    }
    if (escrowExisted) {
      await pool.query('UPDATE escrow_accounts SET balance = $2 WHERE id = $1', [escrowId, escrowBefore]);
    } else if (escrowId) {
      await pool.query('DELETE FROM escrow_accounts WHERE id = $1', [escrowId]);
    }
  }
}

async function main() {
  const cashier = (await pool.query(`
    SELECT u.id, u.email, u.role, u.token_version, cp.merchant_id
      FROM cashier_profiles cp
      JOIN users u ON u.id = cp.user_id
     WHERE cp.is_active = TRUE AND cp.merchant_id IS NOT NULL
     LIMIT 1
  `)).rows[0];
  if (!cashier) throw new Error('active_cashier_required');
  merchantId = cashier.merchant_id;

  const customer = (await pool.query(`
    SELECT u.id, u.email, u.role, u.token_version
      FROM users u
     WHERE u.is_system_owner = FALSE
       AND u.id <> $1
     ORDER BY u.created_at ASC
     LIMIT 1
  `, [cashier.id])).rows[0];
  if (!customer) throw new Error('customer_required');
  customerId = customer.id;

  await pool.query(`
    INSERT INTO point_accounts (owner_id, available_points, lifetime_points)
    VALUES ($1, 0, 0) ON CONFLICT (owner_id) DO NOTHING
  `, [customerId]);
  customerPointsBefore = Number((await pool.query(
    'SELECT available_points FROM point_accounts WHERE owner_id = $1', [customerId]
  )).rows[0].available_points || 0);
  await pool.query('UPDATE point_accounts SET available_points = $2 WHERE owner_id = $1', [customerId, customerPointsBefore + pointsCost]);

  const escrow = (await pool.query(`
    SELECT id, balance FROM escrow_accounts
     WHERE source_type = 'merchant' AND source_id = $1
     ORDER BY created_at ASC LIMIT 1
  `, [merchantId])).rows[0];
  escrowExisted = Boolean(escrow);
  escrowId = escrow?.id || `phase5-escrow-${crypto.randomUUID()}`;
  escrowBefore = Number(escrow?.balance || 0);
  if (escrow) {
    await pool.query('UPDATE escrow_accounts SET balance = $2 WHERE id = $1', [escrowId, escrowBefore + pointsCost]);
  } else {
    await pool.query(`INSERT INTO escrow_accounts (id, source_type, source_id, balance) VALUES ($1,'merchant',$2,$3)`, [escrowId, merchantId, pointsCost]);
  }

  const merchantWallet = (await pool.query('SELECT balance FROM merchant_token_wallets WHERE merchant_id = $1', [merchantId])).rows[0];
  merchantWalletExisted = Boolean(merchantWallet);
  merchantWalletBefore = Number(merchantWallet?.balance || 0);

  await pool.query(`
    INSERT INTO rewards
      (id, reward_name, description, value, kind, source_type, source_id, is_active, quantity_limit, quantity_redeemed)
    VALUES ($1, 'Phase 5 E2E Reward', 'Temporary self-cleaning reward', $2, 'physical', 'merchant', $3, TRUE, 1, 0)
  `, [rewardId, pointsCost, merchantId]);

  const claim = await api('/api/reward-claims/create', 'POST', token(customer), {
    rewardId,
    pointsCost,
    idempotencyKey,
    sourceType: 'brand',
    sourceId: 'forged-source',
    rewardKind: 'digital',
  });
  claimId = claim.id;
  if (claim.reference !== `reward_claim:${claimId}` || claim.status !== 'pending_pickup') {
    throw new Error(`authoritative_claim_failed: ${JSON.stringify(claim)}`);
  }

  const replay = await api('/api/reward-claims/create', 'POST', token(customer), {
    rewardId,
    pointsCost,
    idempotencyKey,
  });
  if (replay.id !== claimId || replay.idempotentReplay !== true) throw new Error('idempotent_replay_failed');

  const redemption = await api('/api/cashier/redeem-claim', 'POST', token(cashier), {
    pickupQrCode: claim.pickupQrCode,
  });
  settlementId = redemption.settlementId;

  const verification = (await pool.query(`
    SELECT rc.status, rc.source_type, rc.source_id, rc.reward_kind, rc.settlement_id,
           (SELECT COUNT(*) FROM ledger_entries le WHERE le.owner_id = rc.owner_id AND le.reference = 'reward_claim:' || rc.id AND le.type = 'rewardClaimCreated') AS customer_ledger_count,
           (SELECT COUNT(*) FROM merchant_token_ledger ml WHERE ml.receipt_id = rc.id AND ml.type = 'reward_points_received') AS merchant_ledger_count,
           (SELECT available_points FROM point_accounts WHERE owner_id = rc.owner_id) AS customer_points,
           (SELECT balance FROM escrow_accounts WHERE id = $2) AS escrow_balance,
           (SELECT balance FROM merchant_token_wallets WHERE merchant_id = $3) AS merchant_wallet_balance
      FROM reward_claims rc WHERE rc.id = $1
  `, [claimId, escrowId, merchantId])).rows[0];

  const expected = {
    status: 'redeemed',
    source_type: 'merchant',
    source_id: merchantId,
    reward_kind: 'physical',
    customer_ledger_count: '1',
    merchant_ledger_count: '1',
    customer_points: customerPointsBefore,
    escrow_balance: String(escrowBefore),
    merchant_wallet_balance: merchantWalletBefore + pointsCost,
  };
  for (const [key, value] of Object.entries(expected)) {
    if (String(verification[key]) !== String(value)) {
      throw new Error(`verification_failed ${key}: expected ${value}, got ${verification[key]}`);
    }
  }
  if (verification.settlement_id !== settlementId) throw new Error('settlement_reference_mismatch');
  console.log(JSON.stringify({ok: true, claimId, reference: claim.reference, settlementId, verification}));
}

main()
  .then(cleanup)
  .then(() => pool.end())
  .catch(async (error) => {
    console.error(error);
    try { await cleanup(); } finally { await pool.end(); }
    process.exit(1);
  });