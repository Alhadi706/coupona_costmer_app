BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS gift_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE CASCADE,
  source_brand_id TEXT REFERENCES brand_profiles(id) ON DELETE CASCADE,
  source_coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
  product_id TEXT REFERENCES product_registry(id) ON DELETE SET NULL,
  gift_type TEXT NOT NULL
    CHECK (gift_type IN ('PHYSICAL_PRODUCT', 'VOUCHER', 'DISCOUNT', 'SERVICE', 'STORE_CREDIT')),
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  value_amount NUMERIC(12,2),
  discount_percentage INTEGER CHECK (discount_percentage IS NULL OR (discount_percentage >= 0 AND discount_percentage <= 100)),
  terms TEXT,
  pickup_instructions TEXT,
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'ACTIVE', 'PAUSED', 'EXPIRED', 'ARCHIVED')),
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(source_merchant_id, source_brand_id, source_coalition_id) = 1),
  CHECK (expires_at IS NULL OR starts_at IS NULL OR expires_at > starts_at),
  CHECK (gift_type <> 'DISCOUNT' OR discount_percentage IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_gift_definitions_source_merchant_status
  ON gift_definitions(source_merchant_id, status, created_at DESC)
  WHERE source_merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gift_definitions_source_brand_status
  ON gift_definitions(source_brand_id, status, created_at DESC)
  WHERE source_brand_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gift_definitions_source_coalition_status
  ON gift_definitions(source_coalition_id, status, created_at DESC)
  WHERE source_coalition_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS gift_contributors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_definition_id UUID NOT NULL REFERENCES gift_definitions(id) ON DELETE CASCADE,
  contributor_merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE CASCADE,
  contributor_brand_id TEXT REFERENCES brand_profiles(id) ON DELETE CASCADE,
  contributor_coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
  contribution_model TEXT NOT NULL DEFAULT 'FIXED_AMOUNT'
    CHECK (contribution_model IN ('FIXED_AMOUNT', 'PERCENTAGE', 'PRODUCT_CONTRIBUTION', 'SERVICE_CONTRIBUTION', 'SHARED_POOL')),
  contribution_amount NUMERIC(12,2),
  contribution_percentage NUMERIC(5,2)
    CHECK (contribution_percentage IS NULL OR (contribution_percentage > 0 AND contribution_percentage <= 100)),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(contributor_merchant_id, contributor_brand_id, contributor_coalition_id) = 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_gift_contributors_participant
  ON gift_contributors(
    gift_definition_id,
    COALESCE(contributor_merchant_id, ''),
    COALESCE(contributor_brand_id, ''),
    COALESCE(contributor_coalition_id, '')
  );

CREATE INDEX IF NOT EXISTS idx_gift_contributors_gift
  ON gift_contributors(gift_definition_id);

ALTER TABLE promo_campaigns ADD COLUMN IF NOT EXISTS gift_definition_id UUID REFERENCES gift_definitions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_promo_campaigns_gift_definition
  ON promo_campaigns(gift_definition_id)
  WHERE gift_definition_id IS NOT NULL;

ALTER TABLE gift_claims ADD COLUMN IF NOT EXISTS gift_definition_id UUID REFERENCES gift_definitions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_gift_claims_gift_definition_status
  ON gift_claims(gift_definition_id, status, claimed_at DESC)
  WHERE gift_definition_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS gift_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_definition_id UUID NOT NULL REFERENCES gift_definitions(id) ON DELETE CASCADE,
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_gift_inventory_scope
  ON gift_inventory(
    gift_definition_id,
    scope_type,
    COALESCE(branch_id, ''),
    COALESCE(merchant_id, ''),
    COALESCE(coalition_id, '')
  );

CREATE INDEX IF NOT EXISTS idx_gift_inventory_gift_scope
  ON gift_inventory(gift_definition_id, scope_type);

CREATE INDEX IF NOT EXISTS idx_gift_inventory_branch
  ON gift_inventory(branch_id)
  WHERE branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gift_inventory_coalition
  ON gift_inventory(coalition_id, merchant_id)
  WHERE coalition_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS gift_fulfillment_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_definition_id UUID NOT NULL REFERENCES gift_definitions(id) ON DELETE CASCADE,
  merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE CASCADE,
  branch_id TEXT REFERENCES branches(id) ON DELETE CASCADE,
  coalition_id TEXT REFERENCES coalitions(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (merchant_id IS NOT NULL OR branch_id IS NOT NULL),
  CHECK (coalition_id IS NULL OR merchant_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_gift_fulfillment_location
  ON gift_fulfillment_locations(
    gift_definition_id,
    COALESCE(merchant_id, ''),
    COALESCE(branch_id, ''),
    COALESCE(coalition_id, '')
  )
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_gift_fulfillment_gift_active
  ON gift_fulfillment_locations(gift_definition_id, is_active);

CREATE INDEX IF NOT EXISTS idx_gift_fulfillment_branch_active
  ON gift_fulfillment_locations(branch_id, is_active)
  WHERE branch_id IS NOT NULL;

ALTER TABLE coalition_fulfillment_members ADD COLUMN IF NOT EXISTS gift_definition_id UUID REFERENCES gift_definitions(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS uq_coalition_fulfillment_member_gift
  ON coalition_fulfillment_members(
    coalition_id,
    merchant_id,
    COALESCE(branch_id, ''),
    COALESCE(gift_definition_id::text, ''),
    fulfillment_scope
  )
  WHERE is_active = TRUE AND gift_definition_id IS NOT NULL;

COMMIT;