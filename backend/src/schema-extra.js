const { pool } = require('./db');

async function createExtraTables() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_brand_fraction_balance (
      customer_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      fraction_balance NUMERIC NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(customer_id, brand_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_token_wallets (
      brand_id TEXT PRIMARY KEY REFERENCES brand_profiles(id) ON DELETE CASCADE,
      balance INTEGER NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'SAR',
      is_local_mode BOOLEAN NOT NULL DEFAULT FALSE,
      last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_token_ledger (
      id TEXT PRIMARY KEY,
      brand_id TEXT NOT NULL REFERENCES brand_profiles(id) ON DELETE CASCADE,
      customer_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      receipt_id TEXT,
      type TEXT NOT NULL,
      amount INTEGER NOT NULL DEFAULT 0,
      balance_after INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_pending_brand_points (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      invoice_id TEXT,
      points INTEGER NOT NULL,
      points_remaining INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      cleared_at TIMESTAMPTZ,
      converted_at TIMESTAMPTZ
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS points_ledger_brand (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      invoice_scan_id TEXT,
      points_delta INTEGER NOT NULL,
      fraction_before NUMERIC NOT NULL DEFAULT 0,
      fraction_after NUMERIC NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS fraud_flags (
      id TEXT PRIMARY KEY,
      owner_id TEXT,
      invoice_scan_id TEXT,
      reason TEXT NOT NULL,
      details JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  // One-time-use ledger for POS grant-points QR tokens (nonce is unique per issued token).
  // Inserting the nonce here is how a second scan of the same QR is rejected atomically.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS pos_grant_token_uses (
      nonce TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_pos_grant_token_uses_used_at ON pos_grant_token_uses(used_at)');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS pos_manual_override BOOLEAN NOT NULL DEFAULT FALSE');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS product_registry (
      id TEXT PRIMARY KEY,
      brand_id TEXT NOT NULL,
      name TEXT NOT NULL,
      image_url TEXT,
      barcode TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('ALTER TABLE product_registry ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE');
  await pool.query('ALTER TABLE product_registry ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_product_audit_logs (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      actor_user_id TEXT NOT NULL,
      action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'deactivated')),
      previous_data JSONB,
      new_data JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_brand_product_audit_product_created ON brand_product_audit_logs(product_id, created_at DESC)');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS invoice_line_items (
      id TEXT PRIMARY KEY,
      invoice_scan_id TEXT NOT NULL,
      item_name TEXT NOT NULL,
      quantity INTEGER,
      unit_price NUMERIC,
      line_total NUMERIC,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_matches (
      id TEXT PRIMARY KEY,
      invoice_line_item_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      product_id TEXT,
      confidence NUMERIC NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      report_type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'new',
      target_store_id TEXT,
      target_brand_id TEXT,
      description TEXT,
      thank_you_sent_at TIMESTAMPTZ,
      reward_granted BOOLEAN NOT NULL DEFAULT FALSE,
      reward_type TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS report_updates (
      id TEXT PRIMARY KEY,
      report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
      author_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      author_role TEXT NOT NULL,
      message TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_report_updates_report_created ON report_updates(report_id, created_at ASC)');
  await pool.query(`
    CREATE TABLE IF NOT EXISTS disputes (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      invoice_scan_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'new',
      reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS escrow_accounts (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      balance NUMERIC NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS settlements (
      id TEXT PRIMARY KEY,
      escrow_account_id TEXT NOT NULL,
      amount NUMERIC NOT NULL,
      settlement_type TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'internal_accounting_only'");
  await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS execution_provider TEXT");
  await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS external_transfer_reference TEXT");
  await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS is_external_transfer_executed BOOLEAN NOT NULL DEFAULT FALSE");
  await pool.query(`
    CREATE TABLE IF NOT EXISTS exchange_rate_config (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      destination_type TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      source_point_value NUMERIC NOT NULL,
      destination_point_value NUMERIC NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS exchange_transactions (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      reward_id TEXT,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      destination_type TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      source_points NUMERIC NOT NULL,
      destination_points NUMERIC NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS exchange_rate_settings (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      destination_type TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      source_point_value NUMERIC NOT NULL,
      destination_point_value NUMERIC NOT NULL,
      rate NUMERIC NOT NULL,
      configured_by TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (source_type, source_id, destination_type, destination_id)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS reward_claims (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      points_cost INTEGER NOT NULL,
      reward_kind TEXT NOT NULL,
      pickup_qr_code TEXT,
      status TEXT NOT NULL DEFAULT 'issued',
      points_deducted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS peer_ads (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL,
      content TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_value TEXT,
      target_category TEXT,
      target_geo_json JSONB,
      fee_paid NUMERIC NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'draft',
      rejection_reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS sourcing_inquiries (
      id TEXT PRIMARY KEY,
      peer_ad_id TEXT NOT NULL,
      merchant_user_id TEXT NOT NULL,
      owner_user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'opened',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS loyalty_health_scores (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      score NUMERIC NOT NULL,
      trend TEXT NOT NULL,
      generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_groups (
      id TEXT PRIMARY KEY,
      role_type TEXT NOT NULL,
      role_profile_id TEXT NOT NULL,
      owner_user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (role_type, role_profile_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_group_members (
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(group_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_group_bans (
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      banned_by TEXT NOT NULL,
      reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(group_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_messages (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      sender_name TEXT,
      text TEXT NOT NULL,
      is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
      is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
      image_url TEXT,
      message_type TEXT NOT NULL DEFAULT 'post',
      poll_json JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS offer_targeting_rules (
      offer_id TEXT PRIMARY KEY,
      target_type TEXT NOT NULL,
      target_value TEXT,
      min_points INTEGER,
      criteria_json JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('ALTER TABLE offer_targeting_rules ADD COLUMN IF NOT EXISTS criteria_json JSONB');
  await pool.query('ALTER TABLE peer_ads ADD COLUMN IF NOT EXISTS target_category TEXT');
  await pool.query('ALTER TABLE peer_ads ADD COLUMN IF NOT EXISTS target_geo_json JSONB');
  await pool.query('ALTER TABLE community_messages ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query("ALTER TABLE community_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'post'");
  await pool.query('ALTER TABLE community_messages ADD COLUMN IF NOT EXISTS poll_json JSONB');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS working_hours TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()');

  await pool.query('CREATE INDEX IF NOT EXISTS idx_branches_merchant_id ON branches(merchant_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_cashier_profiles_branch_id ON cashier_profiles(branch_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_points_ledger_merchant_customer ON points_ledger_merchant(customer_id, merchant_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_points_ledger_brand_customer ON points_ledger_brand(customer_id, brand_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_fraud_flags_owner_created ON fraud_flags(owner_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_line_items_invoice ON invoice_line_items(invoice_scan_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_brand_matches_brand_id ON brand_matches(brand_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_reports_owner_status ON reports(owner_id, status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_reward_claims_owner_status ON reward_claims(owner_id, status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_peer_ads_status_created ON peer_ads(status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_community_groups_role ON community_groups(role_type, role_profile_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_group_members(user_id, joined_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_community_messages_group ON community_messages(group_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_offer_targeting_type ON offer_targeting_rules(target_type, target_value)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_active ON user_push_tokens(user_id, is_active, updated_at DESC)');

  await pool.query(
    `INSERT INTO app_settings (key, value) VALUES
      ('daily_invoice_limit', '10'),
      ('invoice_retention_months', '24')
     ON CONFLICT (key) DO NOTHING`
  );

  await pool.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query("ALTER TABLE rewards ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'physical'");
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_type TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS quantity_limit INTEGER');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS quantity_redeemed INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS pickup_instructions TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_enabled BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_winner_user_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_completed_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS reward_id TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS idempotency_key TEXT');
  await pool.query('CREATE UNIQUE INDEX IF NOT EXISTS uq_reward_claim_owner_idempotency ON reward_claims(owner_id, idempotency_key) WHERE idempotency_key IS NOT NULL');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS cta_type TEXT NOT NULL DEFAULT \'store\'');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS cta_value TEXT');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS impressions INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS clicks INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS target_screen TEXT');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS is_system_owner BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_single_system_owner ON users ((is_system_owner)) WHERE is_system_owner = TRUE');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_uploaded_files_owner ON uploaded_files(owner_user_id, created_at DESC)');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS birth_date DATE');
  await pool.query('ALTER TABLE customer_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE customer_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS category TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS target_store_name_snapshot TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS target_brand_name_snapshot TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolved_by_user_id TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolution_note TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS reward_points INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS product_name TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS location_address TEXT');
  await pool.query("ALTER TABLE reports ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal'");
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS assigned_to_user_id TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS category TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS working_hours TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS merchant_profile_id TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS branch_id TEXT');

  await pool.query(`
    ALTER TABLE private_chat_user_state ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE private_chat_user_state ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE private_chat_user_state ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ;
  `);

  const storesCount = await pool.query('SELECT COUNT(*)::int AS c FROM stores');
  if (storesCount.rows[0].c === 0) {
    await pool.query(
      `INSERT INTO stores (id, name, category, description, phone, location, lat, lng) VALUES
      ($1,'مخبز المدينة','غذائية','مخبوزات طازجة','0910000001','طرابلس',32.8872,13.1913),
      ($2,'عيادة الشفاء','عيادات','خدمات طبية','0910000002','طرابلس',32.9001,13.2102),
      ($3,'متجر التقنية','إلكترونيات','إكسسوارات وهواتف','0910000003','طرابلس',32.8754,13.1801)`,
      [id(), id(), id()]
    );
  }

  const groupsCount = await pool.query('SELECT COUNT(*)::int AS c FROM groups');
  if (groupsCount.rows[0].c === 0) {
    await pool.query(
      `INSERT INTO groups (id, name, description, members) VALUES
      ($1,'مجموعة العروض','مناقشة العروض اليومية',12),
      ($2,'مجموعة النقاط','نصائح زيادة النقاط',8)`,
      [id(), id()]
    );
  }

  const rewardsCount = await pool.query('SELECT COUNT(*)::int AS c FROM rewards');
  if (rewardsCount.rows[0].c === 0) {
    await pool.query(
      `INSERT INTO rewards (id, reward_name, description, value, kind) VALUES
      ($1,'قسيمة 10 دينار','خصم مباشر عند الاستبدال - رمز رقمي فوري',10,'digital'),
      ($2,'قسيمة 25 دينار','خصم مميز عند الاستبدال - رمز رقمي فوري',25,'digital')`,
      [id(), id()]
    );
  }

  // One-time, idempotent backfill: link the still-generic seed rewards to a real active
  // merchant/brand if one exists, so the catalog stops showing unattributed coupons.
  // Safe to run on every boot: it only touches rows where source_type is still empty.
  const unlinkedMerchantReward = (await pool.query(
    `SELECT id FROM rewards WHERE reward_name = 'قسيمة 10 دينار' AND (source_type IS NULL OR source_type = '') LIMIT 1`
  )).rows[0];
  if (unlinkedMerchantReward) {
    const merchant = (await pool.query(
      `SELECT id FROM merchant_profiles WHERE status = 'active' ORDER BY created_at ASC LIMIT 1`
    )).rows[0];
    if (merchant) {
      await pool.query(
        `UPDATE rewards SET source_type = 'merchant', source_id = $2, expires_at = NOW() + INTERVAL '90 days' WHERE id = $1`,
        [unlinkedMerchantReward.id, merchant.id]
      );
    }
  }
  const unlinkedBrandReward = (await pool.query(
    `SELECT id FROM rewards WHERE reward_name = 'قسيمة 25 دينار' AND (source_type IS NULL OR source_type = '') LIMIT 1`
  )).rows[0];
  if (unlinkedBrandReward) {
    const brand = (await pool.query(
      `SELECT id FROM brand_profiles WHERE status = 'active' ORDER BY created_at ASC LIMIT 1`
    )).rows[0];
    if (brand) {
      await pool.query(
        `UPDATE rewards SET source_type = 'brand', source_id = $2, expires_at = NOW() + INTERVAL '90 days' WHERE id = $1`,
        [unlinkedBrandReward.id, brand.id]
      );
    }
  }

}

module.exports = createExtraTables;
