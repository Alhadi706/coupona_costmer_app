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

    CREATE TABLE IF NOT EXISTS coalition_members (
      coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
      merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
      point_conversion_rate NUMERIC(6,4) NOT NULL DEFAULT 1.0,
      joined_at TIMESTAMPTZ DEFAULT NOW(),
      PRIMARY KEY (coalition_id, merchant_id)
    );

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
      id TEXT PRIMARY KEY,
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
  `);
};
