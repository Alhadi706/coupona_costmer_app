const jwt = require('jsonwebtoken');
const { JWT_SECRET, KUPUNA_OWNER_EMAIL, OWNER_ENFORCEMENT_ENABLED } = require('./app');
const { pool } = require('./db');
const { normalizeRole, isAdmin } = require('./helpers');

async function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    return res.status(401).json({ error: 'Missing token' });
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const row = (await pool.query(
      'SELECT id, email, role, token_version, is_system_owner, mfa_enabled, email_verified FROM users WHERE id = $1 LIMIT 1',
      [payload.userId]
    )).rows[0];
    if (!row || Number(row.token_version || 0) !== Number(payload.tokenVersion || 0)) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    if (row.is_system_owner && (
      payload.ownerMfaVerified !== true
      || !KUPUNA_OWNER_EMAIL
      || String(row.email).toLowerCase() !== KUPUNA_OWNER_EMAIL
      || row.mfa_enabled !== true
      || row.email_verified !== true
    )) {
      return res.status(401).json({ error: 'owner_mfa_required' });
    }
    req.user = {
      userId: row.id,
      email: row.email,
      role: normalizeRole(row.role),
      tokenVersion: Number(row.token_version || 0),
      isSystemOwner: row.is_system_owner === true,
      mfaEnabled: row.mfa_enabled === true,
      emailVerified: row.email_verified === true,
      ownerMfaVerified: payload.ownerMfaVerified === true,
    };
    return next();
  } catch (_e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

async function ensureCustomerProfile(client, userId) {
  await client.query(
    `INSERT INTO customer_profiles (user_id)
     VALUES ($1)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
}

async function getIntSetting(client, key, fallback) {
  const row = (await client.query('SELECT value FROM app_settings WHERE key = $1 LIMIT 1', [key])).rows[0];
  const value = Number.parseInt(String(row?.value ?? ''), 10);
  if (!Number.isFinite(value) || value <= 0) return fallback;
  return value;
}

function requireAdmin(req, res, next) {
  if (OWNER_ENFORCEMENT_ENABLED && !isSystemOwner(req.user)) {
    return res.status(403).json({ error: 'system_owner_required' });
  }
  if (isAdmin(req.user)) {
    return next();
  }
  return res.status(403).json({ error: 'admin_required' });
}

async function canManageInvoice(client, user, invoiceId, targetState = null, getMerchantProfileIdByUser) {
  const row = (await client.query(
    'SELECT owner_id, merchant_profile_id, branch_id, state FROM invoice_scans WHERE id = $1 LIMIT 1',
    [invoiceId]
  )).rows[0];
  if (!row) return { allowed: false, status: 404, error: 'invoice_not_found' };
  if (isAdmin(user)) return { allowed: true, row };
  if (row.owner_id === user.userId && row.state === 'rejected' && targetState === 'disputed') {
    return { allowed: true, row };
  }
  if (row.merchant_profile_id && getMerchantProfileIdByUser) {
    const merchant = await getMerchantProfileIdByUser(client, user.userId);
    if (merchant && merchant === row.merchant_profile_id) return { allowed: true, row };
  }
  if (row.branch_id) {
    const manager = (await client.query(
      `SELECT 1
         FROM branch_manager_permissions
        WHERE user_id = $1
          AND branch_id = $2
          AND can_review_invoices = TRUE
        LIMIT 1`,
      [user.userId, row.branch_id]
    )).rows[0];
    if (manager) return { allowed: true, row };
  }
  return { allowed: false, status: 403, error: 'forbidden' };
}

async function canRedeemClaim(client, user, claim) {
  if (isAdmin(user)) return true;
  if (!claim.source_id) return false;
  const fulfiller = (await client.query(
    `SELECT id AS merchant_id FROM merchant_profiles WHERE user_id = $1 AND status = 'active'
     UNION ALL
     SELECT merchant_id FROM cashier_profiles WHERE user_id = $1 AND is_active = TRUE
     LIMIT 1`,
    [user.userId]
  )).rows[0];
  if (!fulfiller?.merchant_id) return false;
  if (claim.source_type === 'merchant') return fulfiller.merchant_id === claim.source_id;
  if (claim.source_type !== 'brand') return false;
  const sharedCoalition = (await client.query(
    `SELECT 1
       FROM brand_coalition_members bcm
       JOIN coalition_members cm ON cm.coalition_id = bcm.coalition_id
       JOIN coalitions c ON c.id = bcm.coalition_id AND c.is_active = TRUE
      WHERE bcm.brand_id = $1 AND cm.merchant_id = $2
      LIMIT 1`,
    [claim.source_id, fulfiller.merchant_id]
  )).rows[0];
  return Boolean(sharedCoalition);
}

async function getManageableBrandProductId(client, userId) {
  const owner = (await client.query(
    'SELECT id FROM brand_profiles WHERE user_id = $1 LIMIT 1',
    [userId]
  )).rows[0];
  if (owner) return owner.id;
  const member = (await client.query(
    `SELECT brand_id
       FROM brand_team_members
      WHERE user_id = $1
        AND can_manage_products = TRUE
      ORDER BY created_at
      LIMIT 1`,
    [userId]
  )).rows[0];
  return member ? member.brand_id : null;
}


module.exports = {
  auth,
  requireAdmin,
  ensureCustomerProfile,
  getIntSetting,
  canManageInvoice,
  canRedeemClaim,
  getManageableBrandProductId,
};
