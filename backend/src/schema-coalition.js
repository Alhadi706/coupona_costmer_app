// Coalition Engine schema: coalitions, membership, cross-redemption ledger, clearinghouse
module.exports = async function createCoalitionTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS coalitions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'general', -- general | category | regional | private
      category TEXT,
      region TEXT,
      created_by TEXT REFERENCES merchant_profiles(id) ON DELETE SET NULL,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS customer_point_tiers (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      tier TEXT NOT NULL CHECK (tier IN ('bronze', 'silver', 'gold')),
      merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
      balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
      lifetime_earned INTEGER NOT NULL DEFAULT 0 CHECK (lifetime_earned >= 0),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_point_tier_scope
      ON customer_point_tiers(customer_id, tier, COALESCE(merchant_id, ''), COALESCE(coalition_id, ''));

    ALTER TABLE merchant_profiles
      ADD COLUMN IF NOT EXISTS is_public_coalition_active BOOLEAN NOT NULL DEFAULT FALSE;

    CREATE TABLE IF NOT EXISTS coalition_members (
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      point_conversion_rate NUMERIC(6,4) NOT NULL DEFAULT 1.0,
      joined_at TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (coalition_id, merchant_id)
    );

    CREATE TABLE IF NOT EXISTS brand_coalition_members (
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      brand_id TEXT NOT NULL REFERENCES brand_profiles(id) ON DELETE CASCADE,
      joined_at TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (coalition_id, brand_id)
    );

    CREATE INDEX IF NOT EXISTS idx_brand_coalition_members_brand
      ON brand_coalition_members(brand_id);

    CREATE TABLE IF NOT EXISTS coalition_invitations (
      id TEXT PRIMARY KEY,
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      invited_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      invited_by TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'pending', -- pending | accepted | rejected
      created_at TIMESTAMPTZ DEFAULT NOW(),
      responded_at TIMESTAMPTZ
    );

    -- Cross-redemption ledger: tracks every time a customer redeems points from Merchant A at Merchant B
    CREATE TABLE IF NOT EXISTS coalition_ledger (
      id TEXT PRIMARY KEY,
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      from_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      to_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      customer_id TEXT NOT NULL REFERENCES users(id),
      reward_claim_id TEXT,
      points_redeemed INTEGER NOT NULL CHECK (points_redeemed > 0),
      conversion_rate NUMERIC(6,4) NOT NULL DEFAULT 1.0,
      net_points INTEGER NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );


    -- Monthly clearinghouse balances: what Merchant A owes Merchant B this month
    CREATE TABLE IF NOT EXISTS coalition_clearinghouse (
      id TEXT,
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      from_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      to_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      period TEXT NOT NULL, -- YYYY-MM
      total_points INTEGER NOT NULL DEFAULT 0,
      settled BOOLEAN NOT NULL DEFAULT FALSE,
      settled_at TIMESTAMPTZ,
      PRIMARY KEY (coalition_id, from_merchant_id, to_merchant_id, period)
    );

    -- Spending caps per merchant per coalition per month
    CREATE TABLE IF NOT EXISTS coalition_spending_caps (
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      monthly_points_cap INTEGER NOT NULL DEFAULT 10000,
      PRIMARY KEY (coalition_id, merchant_id)
    );

    -- Merchant-level auto gift trigger configuration
    CREATE TABLE IF NOT EXISTS coalition_gift_triggers (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL UNIQUE REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      threshold_points INTEGER NOT NULL CHECK (threshold_points > 0),
      merchant_name TEXT,
      message_template TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    -- Shared coalition gift catalog (multi-sponsor vouchers)
    CREATE TABLE IF NOT EXISTS coalition_gift_catalog (
      id TEXT PRIMARY KEY,
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      created_by_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      title TEXT NOT NULL,
      description TEXT,
      image_url TEXT,
      required_points INTEGER NOT NULL CHECK (required_points > 0),
      monetary_value NUMERIC(10,2),
      campaign_type TEXT DEFAULT 'standard', -- standard | new_acquisition | vip_loyalty
      discount_percentage INTEGER DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
      quantity_limit INTEGER,
      quantity_redeemed INTEGER DEFAULT 0,
      expires_at TIMESTAMPTZ,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    -- Pro-rata redemption split tracking (who contributed which % of points)
    CREATE TABLE IF NOT EXISTS coalition_redemption_splits (
      id TEXT PRIMARY KEY,
      gift_catalog_id TEXT NOT NULL REFERENCES coalition_gift_catalog(id) ON DELETE CASCADE,
      customer_id TEXT NOT NULL REFERENCES users(id),
      fulfiller_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      total_points_used INTEGER NOT NULL,
      redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE(gift_catalog_id, customer_id, redeemed_at)
    );

    -- Individual merchant contributions for each redemption
    CREATE TABLE IF NOT EXISTS coalition_redemption_contributions (
      id TEXT PRIMARY KEY,
      redemption_split_id TEXT NOT NULL REFERENCES coalition_redemption_splits(id) ON DELETE CASCADE,
      contributor_merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id),
      points_contributed INTEGER NOT NULL CHECK (points_contributed > 0),
      contribution_percentage NUMERIC(5,2) NOT NULL CHECK (contribution_percentage > 0 AND contribution_percentage <= 100),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    -- Customer point balance per merchant (for pro-rata calculation)
    CREATE TABLE IF NOT EXISTS customer_merchant_point_balances (
      customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
      points_balance INTEGER NOT NULL DEFAULT 0,
      last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (customer_id, merchant_id, coalition_id)
    );

    -- Campaign targeting metadata
    CREATE TABLE IF NOT EXISTS coalition_gift_targeting (
      gift_catalog_id TEXT PRIMARY KEY REFERENCES coalition_gift_catalog(id) ON DELETE CASCADE,
      target_new_customers BOOLEAN DEFAULT FALSE,
      target_vip_customers BOOLEAN DEFAULT FALSE,
      min_purchase_frequency INTEGER,
      max_days_since_last_visit INTEGER,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS customer_pending_points (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      invoice_id TEXT NOT NULL UNIQUE REFERENCES invoice_scans(id) ON DELETE CASCADE,
      points INTEGER NOT NULL CHECK (points > 0),
      points_remaining INTEGER NOT NULL CHECK (points_remaining >= 0 AND points_remaining <= points),
      tier TEXT NOT NULL CHECK (tier IN ('bronze', 'silver', 'gold')),
      coalition_id TEXT REFERENCES coalitions(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIALLY_CLEARED', 'CLEARED', 'CONVERTED_BRONZE')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      cleared_at TIMESTAMPTZ,
      converted_at TIMESTAMPTZ
    );

    CREATE INDEX IF NOT EXISTS idx_pending_points_merchant_fifo
      ON customer_pending_points(merchant_id, status, created_at);
    CREATE INDEX IF NOT EXISTS idx_pending_points_customer
      ON customer_pending_points(customer_id, status, created_at);

    CREATE INDEX IF NOT EXISTS idx_gift_catalog_coalition ON coalition_gift_catalog(coalition_id, is_active);
    CREATE INDEX IF NOT EXISTS idx_redemption_splits_customer ON coalition_redemption_splits(customer_id);
    CREATE INDEX IF NOT EXISTS idx_redemption_contributions_merchant ON coalition_redemption_contributions(contributor_merchant_id);
    CREATE INDEX IF NOT EXISTS idx_customer_points_merchant ON customer_merchant_point_balances(merchant_id);
    CREATE INDEX IF NOT EXISTS idx_customer_points_coalition ON customer_merchant_point_balances(coalition_id);
  `);

  await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'merchant_token_wallets_balance_nonnegative'
        ) THEN
          ALTER TABLE merchant_token_wallets
            ADD CONSTRAINT merchant_token_wallets_balance_nonnegative CHECK (balance >= 0);
        END IF;
      END $$;
  `);

  await pool.query(`
    INSERT INTO coalitions (id, name, type, category, region, is_active)
    VALUES ('public-platform-coalition', 'Coupona Public Loyalty Network', 'public', 'all', 'global', TRUE)
    ON CONFLICT (id) DO UPDATE SET type = 'public', is_active = TRUE
  `);
};
