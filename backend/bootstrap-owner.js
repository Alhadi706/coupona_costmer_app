/**
 * bootstrap-owner.js
 * Secure first-time owner account creation via environment variables only.
 * 
 * Usage:
 *   KUPUNA_OWNER_EMAIL=owner@example.com \
 *   OWNER_PASSWORD='secure-password-min-8-chars' \
 *   node bootstrap-owner.js
 * 
 * Features:
 * - NO hardcoded credentials
 * - NO interactive prompts (fail-closed if env vars missing)
 * - Prevents duplicate owner creation
 * - Enforces email + password validation
 * - Sets mfa_enabled and email_verified flags
 * - Logs security event to owner_audit_log
 */

const crypto = require('crypto');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

// =============================================================================
// CONFIGURATION & VALIDATION
// =============================================================================

function requiredEnv(key) {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

const KUPUNA_OWNER_EMAIL = String(process.env.KUPUNA_OWNER_EMAIL || '').trim().toLowerCase();
const OWNER_PASSWORD = String(process.env.OWNER_PASSWORD || '').trim();

// Validation: fail closed if incomplete
if (!KUPUNA_OWNER_EMAIL || !KUPUNA_OWNER_EMAIL.includes('@')) {
  console.error('ERROR: KUPUNA_OWNER_EMAIL must be a valid email address');
  process.exit(1);
}

if (!OWNER_PASSWORD || OWNER_PASSWORD.length < 8) {
  console.error('ERROR: OWNER_PASSWORD must be at least 8 characters');
  process.exit(1);
}

const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5434),
  user: process.env.PGUSER || 'kupuna_user',
  password: requiredEnv('PGPASSWORD'),
  database: process.env.PGDATABASE || 'kupuna_db',
});

// =============================================================================
// BOOTSTRAP LOGIC
// =============================================================================

async function bootstrapOwner() {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Step 1: Check if an owner already exists
    const existing = (await client.query(
      'SELECT id, email FROM users WHERE is_system_owner = TRUE LIMIT 1'
    )).rows[0];

    if (existing) {
      console.error(`ERROR: Owner account already exists: ${existing.email}`);
      await client.query('ROLLBACK');
      process.exit(1);
    }

    // Step 2: Check if email is already taken
    const emailExists = (await client.query(
      'SELECT id FROM users WHERE email = $1 LIMIT 1',
      [KUPUNA_OWNER_EMAIL]
    )).rows[0];

    if (emailExists) {
      console.error(`ERROR: Email already in use: ${KUPUNA_OWNER_EMAIL}`);
      await client.query('ROLLBACK');
      process.exit(1);
    }

    // Step 3: Hash password with bcrypt (10 rounds)
    const passwordHash = await bcrypt.hash(OWNER_PASSWORD, 10);

    // Step 4: Create owner user with admin role
    const ownerId = crypto.randomUUID().toString();
    await client.query(
      `INSERT INTO users (
        id, email, password_hash, role, is_system_owner, 
        email_verified, mfa_enabled, token_version, profile_completed
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        ownerId,
        KUPUNA_OWNER_EMAIL,
        passwordHash,
        'admin',
        true,              // is_system_owner
        true,              // email_verified (trusted via bootstrap)
        true,              // mfa_enabled (required for owner)
        0,                 // token_version
        true,              // profile_completed
      ]
    );

    // Step 5: Log security event
    await client.query(
      `INSERT INTO owner_audit_log (event_type, user_id, event_data)
       VALUES ($1, $2, $3)`,
      [
        'owner_bootstrap',
        ownerId,
        JSON.stringify({
          email: KUPUNA_OWNER_EMAIL,
          timestamp: new Date().toISOString(),
          mfa_enabled: true,
          email_verified: true,
        }),
      ]
    );

    await client.query('COMMIT');

    console.log('✓ Owner account created successfully');
    console.log(`  Email: ${KUPUNA_OWNER_EMAIL}`);
    console.log(`  User ID: ${ownerId}`);
    console.log(`  Role: admin`);
    console.log(`  MFA Enabled: true`);
    console.log(`  Email Verified: true`);
    console.log('');
    console.log('Next steps:');
    console.log('1. Set OWNER_ENFORCEMENT_ENABLED=true in environment when ready');
    console.log('2. Log in via /api/auth/owner/login endpoint');
    console.log('3. Enter password + receive MFA code via email');
    console.log('4. Verify code via /api/auth/owner/verify endpoint');

    process.exit(0);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('ERROR: Bootstrap failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

// =============================================================================
// RUN BOOTSTRAP
// =============================================================================

bootstrapOwner().catch((err) => {
  console.error('FATAL:', err.message);
  process.exit(1);
});
