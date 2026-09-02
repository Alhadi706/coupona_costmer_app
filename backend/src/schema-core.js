const { pool } = require('./db');
const { SYSTEM_POINT_VALUE } = require('./system-policy');

async function createCoreTables() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'customer',
      phone TEXT,
      full_name TEXT,
      gender TEXT,
      birth_date DATE,
      city TEXT,
      country TEXT,
      profile_completed BOOLEAN NOT NULL DEFAULT FALSE,
      points INTEGER NOT NULL DEFAULT 0,
      points_history JSONB NOT NULL DEFAULT '[]'::jsonb,
      token_version INTEGER NOT NULL DEFAULT 0,
      is_system_owner BOOLEAN NOT NULL DEFAULT FALSE,
      mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      email_verified BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS owner_mfa_challenges (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      code_hash TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS customer_profiles (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS merchant_profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      business_name TEXT,
      commercial_registration TEXT,
      phone TEXT,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      location_address TEXT,
      point_value NUMERIC NOT NULL DEFAULT 0.1,
      status TEXT NOT NULL DEFAULT 'pending_activation',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS brand_profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      business_name TEXT,
      commercial_registration TEXT,
      phone TEXT,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      location_address TEXT,
      point_value NUMERIC NOT NULL DEFAULT 0.1,
      status TEXT NOT NULL DEFAULT 'pending_activation',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS cashier_profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      merchant_id TEXT,
      branch_id TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS role_requests (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role_type TEXT NOT NULL,
      role_profile_id TEXT,
      status TEXT NOT NULL DEFAULT 'pending_admin_review',
      plan_type TEXT,
      request_data JSONB NOT NULL DEFAULT '{}'::jsonb,
      rejection_reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      reviewed_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS subscriptions (
      id TEXT PRIMARY KEY,
      role_profile_id TEXT NOT NULL,
      role_type TEXT NOT NULL,
      plan_type TEXT,
      status TEXT NOT NULL,
      trial_duration_days INTEGER NOT NULL DEFAULT 30,
      trial_start_date TIMESTAMPTZ,
      trial_end_date TIMESTAMPTZ,
      billing_cycle TEXT,
      next_billing_date TIMESTAMPTZ,
      payment_method_ref TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      title TEXT,
      body TEXT,
      target_screen TEXT,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_push_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token TEXT NOT NULL UNIQUE,
      platform TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS uploaded_files (
      file_name TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mime_type TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS offers (
      id TEXT PRIMARY KEY,
      owner_id TEXT,
      offer_type TEXT,
      category TEXT,
      title_type TEXT,
      discount_type TEXT,
      discount_value TEXT,
      price TEXT,
      description TEXT,
      start_date TIMESTAMPTZ,
      end_date TIMESTAMPTZ,
      location TEXT,
      image_url TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      lifecycle_status TEXT NOT NULL DEFAULT 'pending_review',
      lifecycle_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      lifecycle_reason TEXT,
      published_at TIMESTAMPTZ,
      redeemed_at TIMESTAMPTZ,
      expired_at TIMESTAMPTZ,
      archived_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS stores (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT,
      description TEXT,
      phone TEXT,
      location TEXT,
      lat DOUBLE PRECISION NOT NULL,
      lng DOUBLE PRECISION NOT NULL
    );

    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      members INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS group_messages (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      sender_id TEXT,
      sender_name TEXT,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS group_message_replies (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      message_id TEXT NOT NULL,
      sender_id TEXT,
      sender_name TEXT,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS group_message_reactions (
      message_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      emoji TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(message_id, user_id, emoji)
    );

    CREATE TABLE IF NOT EXISTS private_chats (
      id TEXT PRIMARY KEY,
      title TEXT,
      last_message TEXT,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS private_chat_participants (
      chat_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      PRIMARY KEY(chat_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS private_messages (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      sender_id TEXT,
      sender_name TEXT,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_id TEXT NOT NULL,
      blocked_id TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(blocker_id, blocked_id)
    );

    CREATE TABLE IF NOT EXISTS private_chat_user_state (
      user_id TEXT NOT NULL,
      chat_id TEXT NOT NULL,
      is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
      is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
      is_muted BOOLEAN NOT NULL DEFAULT FALSE,
      is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
      last_read_at TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(user_id, chat_id)
    );

    CREATE TABLE IF NOT EXISTS rewards (
      id TEXT PRIMARY KEY,
      reward_name TEXT NOT NULL,
      description TEXT,
      value INTEGER NOT NULL DEFAULT 0,
      kind TEXT NOT NULL DEFAULT 'physical',
      source_type TEXT,
      source_id TEXT,
      image_url TEXT,
      expires_at TIMESTAMPTZ,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      quantity_limit INTEGER,
      quantity_redeemed INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS activity_logs (
      id TEXT PRIMARY KEY,
      customer_email TEXT NOT NULL,
      amount NUMERIC NOT NULL DEFAULT 0,
      transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS wallet_accounts (
      owner_id TEXT PRIMARY KEY,
      balance NUMERIC NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'SAR',
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS point_accounts (
      owner_id TEXT PRIMARY KEY,
      available_points INTEGER NOT NULL DEFAULT 0,
      lifetime_points INTEGER NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS ledger_entries (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount NUMERIC NOT NULL DEFAULT 0,
      points INTEGER NOT NULL DEFAULT 0,
      reference TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS invoice_scans (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      merchant_name TEXT,
      merchant_key TEXT NOT NULL,
      invoice_fingerprint TEXT,
      invoice_number TEXT,
      order_number TEXT,
      invoice_date DATE,
      total_amount NUMERIC,
      currency TEXT NOT NULL DEFAULT 'SAR',
      category TEXT NOT NULL DEFAULT 'general',
      raw_text TEXT NOT NULL,
      reward_applied BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await pool.query('ALTER TABLE merchant_profiles ALTER COLUMN point_value SET DEFAULT 0.1');
  await pool.query('ALTER TABLE brand_profiles ALTER COLUMN point_value SET DEFAULT 0.1');
  await pool.query('UPDATE merchant_profiles SET point_value = $1 WHERE point_value IS DISTINCT FROM $1', [SYSTEM_POINT_VALUE]);
  await pool.query('UPDATE brand_profiles SET point_value = $1 WHERE point_value IS DISTINCT FROM $1', [SYSTEM_POINT_VALUE]);

  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS order_number TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS invoice_fingerprint TEXT');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_address TEXT');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS location_address TEXT');

  await pool.query('CREATE INDEX IF NOT EXISTS idx_customer_profiles_user_id ON customer_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_merchant_profiles_user_id ON merchant_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_brand_profiles_user_id ON brand_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_cashier_profiles_user_id ON cashier_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_role_requests_user_type ON role_requests(user_id, role_type, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_role_requests_status ON role_requests(status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_subscriptions_profile ON subscriptions(role_profile_id, role_type, updated_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status, trial_end_date)');

  await pool.query(
    `INSERT INTO app_settings (key, value) VALUES
      ('trial_duration_days_default', '30'),
      ('grace_period_days_default', '7')
     ON CONFLICT (key) DO NOTHING`
  );

  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_scans_owner_created ON invoice_scans(owner_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_scans_merchant_key ON invoice_scans(merchant_key)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_scans_fingerprint ON invoice_scans(invoice_fingerprint)');
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS ux_invoice_scans_dedupe
      ON invoice_scans(
        owner_id,
        merchant_key,
        COALESCE(invoice_number, ''),
        COALESCE(order_number, ''),
        COALESCE(invoice_date, DATE '1970-01-01'),
        COALESCE(total_amount, -1)
      )
  `);
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS ux_invoice_scans_fingerprint
      ON invoice_scans(invoice_fingerprint)
      WHERE invoice_fingerprint IS NOT NULL
  `);

  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS image_hash TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT \'approved\'');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS review_note TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS original_image_path TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS digital_code TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS redeemed_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS redeemed_by TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS settlement_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT \'digital\'');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_type TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS branches (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      name TEXT NOT NULL,
      address TEXT,
      location TEXT,
      latitude DOUBLE PRECISION,
      longitude DOUBLE PRECISION,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS branch_manager_permissions (
      branch_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      can_review_invoices BOOLEAN NOT NULL DEFAULT FALSE,
      can_create_offers BOOLEAN NOT NULL DEFAULT FALSE,
      can_manage_group BOOLEAN NOT NULL DEFAULT FALSE,
      can_view_reports BOOLEAN NOT NULL DEFAULT FALSE,
      can_view_settlements BOOLEAN NOT NULL DEFAULT FALSE,
      can_add_cashiers BOOLEAN NOT NULL DEFAULT FALSE,
      can_reply_reports BOOLEAN NOT NULL DEFAULT FALSE,
      can_edit_point_value BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(branch_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS merchant_team_invitations (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      branch_id TEXT NOT NULL,
      invited_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      invited_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role_type TEXT NOT NULL CHECK (role_type IN ('manager', 'cashier')),
      permissions JSONB NOT NULL DEFAULT '{}'::jsonb,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      responded_at TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS uq_merchant_team_pending_invitation
      ON merchant_team_invitations(branch_id, invited_user_id, role_type)
      WHERE status = 'pending'
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_merchant_team_invited_user ON merchant_team_invitations(invited_user_id, status)');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_team_members (
      brand_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      can_manage_products BOOLEAN NOT NULL DEFAULT FALSE,
      can_view_geo_distribution BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(brand_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_team_invitations (
      id TEXT PRIMARY KEY,
      brand_id TEXT NOT NULL REFERENCES brand_profiles(id) ON DELETE CASCADE,
      invited_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      invited_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      permissions JSONB NOT NULL DEFAULT '{}'::jsonb,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','cancelled')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      responded_at TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query("CREATE UNIQUE INDEX IF NOT EXISTS uq_brand_team_pending_invitation ON brand_team_invitations(brand_id, invited_user_id) WHERE status = 'pending'");
  await pool.query('CREATE INDEX IF NOT EXISTS idx_brand_team_invited_user ON brand_team_invitations(invited_user_id, status)');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_merchant_fraction_balance (
      customer_id TEXT NOT NULL,
      merchant_id TEXT NOT NULL,
      fraction_balance NUMERIC NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(customer_id, merchant_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS merchant_token_wallets (
      merchant_id TEXT PRIMARY KEY REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      balance INTEGER NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'SAR',
      is_local_mode BOOLEAN NOT NULL DEFAULT FALSE,
      last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS merchant_token_ledger (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      customer_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      receipt_id TEXT,
      type TEXT NOT NULL,
      amount INTEGER NOT NULL DEFAULT 0,
      balance_after INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS points_ledger_merchant (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      merchant_id TEXT NOT NULL,
      invoice_scan_id TEXT,
      points_delta INTEGER NOT NULL,
      fraction_before NUMERIC NOT NULL DEFAULT 0,
      fraction_after NUMERIC NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);


}

module.exports = createCoreTables;
