const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');
require('dotenv').config();

function required(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) throw new Error(`${name}_required`);
  return value;
}

async function main() {
  const ownerEmail = required('KUPUNA_OWNER_EMAIL').toLowerCase();
  const ownerPassword = required('OWNER_PASSWORD');
  if (ownerPassword.length < 12) throw new Error('OWNER_PASSWORD_TOO_SHORT');

  const pool = new Pool({
    host: process.env.PGHOST || '127.0.0.1',
    port: Number(process.env.PGPORT || 5434),
    user: process.env.PGUSER || 'kupuna_user',
    password: required('PGPASSWORD'),
    database: process.env.PGDATABASE || 'kupuna_db',
  });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS is_system_owner BOOLEAN NOT NULL DEFAULT FALSE');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE');
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE');
    await client.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_single_system_owner ON users ((is_system_owner)) WHERE is_system_owner = TRUE');

    const otherOwner = (await client.query(
      'SELECT id, email FROM users WHERE is_system_owner = TRUE AND LOWER(email) <> $1 LIMIT 1',
      [ownerEmail]
    )).rows[0];
    if (otherOwner) throw new Error('SYSTEM_OWNER_ALREADY_EXISTS');

    const hash = await bcrypt.hash(ownerPassword, 12);
    const existing = (await client.query('SELECT id FROM users WHERE LOWER(email) = $1 LIMIT 1', [ownerEmail])).rows[0];
    if (existing) {
      await client.query(
        `UPDATE users
            SET email = $1,
                password_hash = $2,
                role = 'admin',
                is_system_owner = TRUE,
                mfa_enabled = TRUE,
                email_verified = TRUE,
                profile_completed = TRUE,
                token_version = token_version + 1
          WHERE id = $3`,
        [ownerEmail, hash, existing.id]
      );
    } else {
      await client.query(
        `INSERT INTO users
          (id, email, password_hash, role, full_name, profile_completed, is_system_owner, mfa_enabled, email_verified)
         VALUES ($1, $2, $3, 'admin', 'Kupuna System Owner', TRUE, TRUE, TRUE, TRUE)`,
        [crypto.randomUUID(), ownerEmail, hash]
      );
    }

    await client.query('COMMIT');
    console.log('SYSTEM_OWNER_BOOTSTRAPPED');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
