BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Phase 2A keeps legacy promo_campaigns.source_type/source_id working while
-- preparing real FK ownership columns for the canonical campaign model.
ALTER TABLE promo_campaigns ADD COLUMN IF NOT EXISTS source_merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE SET NULL;
ALTER TABLE promo_campaigns ADD COLUMN IF NOT EXISTS source_brand_id TEXT REFERENCES brand_profiles(id) ON DELETE SET NULL;
ALTER TABLE promo_campaigns ADD COLUMN IF NOT EXISTS source_coalition_id TEXT;

UPDATE promo_campaigns
   SET source_merchant_id = source_id
 WHERE source_type = 'merchant'
   AND source_merchant_id IS NULL;

UPDATE promo_campaigns
   SET source_brand_id = source_id
 WHERE source_type = 'brand'
   AND source_brand_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_promo_campaigns_source_merchant_status
  ON promo_campaigns(source_merchant_id, status, starts_at, ends_at)
  WHERE source_merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_promo_campaigns_source_brand_status
  ON promo_campaigns(source_brand_id, status, starts_at, ends_at)
  WHERE source_brand_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_promo_campaigns_source_coalition_status
  ON promo_campaigns(source_coalition_id, status, starts_at, ends_at)
  WHERE source_coalition_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS campaign_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id TEXT NOT NULL REFERENCES promo_campaigns(id) ON DELETE CASCADE,
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  legacy_coupon_id TEXT UNIQUE REFERENCES promo_campaign_coupons(id) ON DELETE SET NULL,
  assignment_kind TEXT NOT NULL DEFAULT 'gift'
    CHECK (assignment_kind IN ('gift', 'offer', 'raffle', 'coupon')),
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'NOTIFIED', 'VIEWED', 'CLAIMED', 'REDEEMED', 'EXPIRED', 'CANCELLED')),
  idempotency_key TEXT,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notified_at TIMESTAMPTZ,
  viewed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  redeemed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at IS NULL OR expires_at > assigned_at),
  CHECK (cancelled_at IS NULL OR status = 'CANCELLED'),
  CHECK (redeemed_at IS NULL OR status = 'REDEEMED')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_campaign_assignments_campaign_customer_active
  ON campaign_assignments(campaign_id, customer_id)
  WHERE status NOT IN ('CANCELLED', 'EXPIRED');

CREATE UNIQUE INDEX IF NOT EXISTS uq_campaign_assignments_customer_idempotency
  ON campaign_assignments(customer_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_campaign_assignments_customer_status
  ON campaign_assignments(customer_id, status, assigned_at DESC);

CREATE INDEX IF NOT EXISTS idx_campaign_assignments_campaign_status
  ON campaign_assignments(campaign_id, status, assigned_at DESC);

CREATE TABLE IF NOT EXISTS gift_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id UUID NOT NULL REFERENCES campaign_assignments(id) ON DELETE CASCADE,
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'CLAIMED'
    CHECK (status IN ('CLAIMED', 'TOKENIZED', 'VERIFIED', 'REDEEMED', 'EXPIRED', 'CANCELLED')),
  idempotency_key TEXT,
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tokenized_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  redeemed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at IS NULL OR expires_at > claimed_at),
  CHECK (cancelled_at IS NULL OR status = 'CANCELLED'),
  CHECK (redeemed_at IS NULL OR status = 'REDEEMED')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_gift_claims_assignment_active
  ON gift_claims(assignment_id)
  WHERE status IN ('CLAIMED', 'TOKENIZED', 'VERIFIED', 'REDEEMED');

CREATE UNIQUE INDEX IF NOT EXISTS uq_gift_claims_customer_idempotency
  ON gift_claims(customer_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gift_claims_customer_status
  ON gift_claims(customer_id, status, claimed_at DESC);

CREATE INDEX IF NOT EXISTS idx_gift_claims_assignment_status
  ON gift_claims(assignment_id, status, claimed_at DESC);

COMMIT;