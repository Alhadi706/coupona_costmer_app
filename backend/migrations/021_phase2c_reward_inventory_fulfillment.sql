BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS reward_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id TEXT NOT NULL REFERENCES rewards(id) ON DELETE CASCADE,
  scope_type TEXT NOT NULL DEFAULT 'GLOBAL'
    CHECK (scope_type IN ('GLOBAL', 'BRANCH', 'MERCHANT', 'COALITION_MEMBER')),
  branch_id TEXT REFERENCES branches(id) ON DELETE CASCADE,
  merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE CASCADE,
  coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
  quantity_total INTEGER NOT NULL DEFAULT 0 CHECK (quantity_total >= 0),
  quantity_reserved INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved = 0),
  quantity_redeemed INTEGER NOT NULL DEFAULT 0 CHECK (quantity_redeemed >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (quantity_redeemed <= quantity_total),
  CHECK (
    (scope_type = 'GLOBAL' AND branch_id IS NULL AND merchant_id IS NULL AND coalition_id IS NULL) OR
    (scope_type = 'BRANCH' AND branch_id IS NOT NULL AND coalition_id IS NULL) OR
    (scope_type = 'MERCHANT' AND merchant_id IS NOT NULL AND branch_id IS NULL AND coalition_id IS NULL) OR
    (scope_type = 'COALITION_MEMBER' AND merchant_id IS NOT NULL AND coalition_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_reward_inventory_scope
  ON reward_inventory(
    reward_id,
    scope_type,
    COALESCE(branch_id, ''),
    COALESCE(merchant_id, ''),
    COALESCE(coalition_id, '')
  );

CREATE INDEX IF NOT EXISTS idx_reward_inventory_reward_scope
  ON reward_inventory(reward_id, scope_type);

CREATE INDEX IF NOT EXISTS idx_reward_inventory_branch
  ON reward_inventory(branch_id)
  WHERE branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_reward_inventory_merchant
  ON reward_inventory(merchant_id)
  WHERE merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_reward_inventory_coalition
  ON reward_inventory(coalition_id, merchant_id)
  WHERE coalition_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS reward_fulfillment_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id TEXT NOT NULL REFERENCES rewards(id) ON DELETE CASCADE,
  merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE CASCADE,
  branch_id TEXT REFERENCES branches(id) ON DELETE CASCADE,
  coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (merchant_id IS NOT NULL OR branch_id IS NOT NULL),
  CHECK (coalition_id IS NULL OR merchant_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_reward_fulfillment_location
  ON reward_fulfillment_locations(
    reward_id,
    COALESCE(merchant_id, ''),
    COALESCE(branch_id, ''),
    COALESCE(coalition_id, '')
  )
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_reward_fulfillment_reward_active
  ON reward_fulfillment_locations(reward_id, is_active);

CREATE INDEX IF NOT EXISTS idx_reward_fulfillment_branch_active
  ON reward_fulfillment_locations(branch_id, is_active)
  WHERE branch_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS coalition_fulfillment_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coalition_id TEXT NOT NULL REFERENCES coalitions(id) ON DELETE CASCADE,
  merchant_id TEXT NOT NULL REFERENCES merchant_profiles(id) ON DELETE CASCADE,
  branch_id TEXT REFERENCES branches(id) ON DELETE CASCADE,
  reward_id TEXT REFERENCES rewards(id) ON DELETE CASCADE,
  fulfillment_scope TEXT NOT NULL DEFAULT 'REWARD'
    CHECK (fulfillment_scope IN ('REWARD', 'GIFT', 'BOTH')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_coalition_fulfillment_member_reward
  ON coalition_fulfillment_members(
    coalition_id,
    merchant_id,
    COALESCE(branch_id, ''),
    COALESCE(reward_id, ''),
    fulfillment_scope
  )
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_coalition_fulfillment_members_coalition
  ON coalition_fulfillment_members(coalition_id, is_active);

CREATE INDEX IF NOT EXISTS idx_coalition_fulfillment_members_merchant
  ON coalition_fulfillment_members(merchant_id, is_active);

COMMIT;