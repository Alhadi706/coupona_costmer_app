BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS offer_uses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id TEXT NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  campaign_assignment_id UUID REFERENCES campaign_assignments(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'AVAILABLE'
    CHECK (status IN ('AVAILABLE', 'CLAIMED', 'TOKENIZED', 'VERIFIED', 'USED', 'EXPIRED', 'CANCELLED')),
  idempotency_key TEXT,
  claimed_at TIMESTAMPTZ,
  tokenized_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (expires_at IS NULL OR expires_at > created_at),
  CHECK (cancelled_at IS NULL OR status = 'CANCELLED'),
  CHECK (used_at IS NULL OR status = 'USED')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_offer_uses_offer_customer_active
  ON offer_uses(offer_id, customer_id)
  WHERE status NOT IN ('EXPIRED', 'CANCELLED');

CREATE UNIQUE INDEX IF NOT EXISTS uq_offer_uses_customer_idempotency
  ON offer_uses(customer_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_offer_uses_customer_status
  ON offer_uses(customer_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_offer_uses_offer_status
  ON offer_uses(offer_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS redemption_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_claim_id TEXT REFERENCES reward_claims(id) ON DELETE CASCADE,
  gift_claim_id UUID REFERENCES gift_claims(id) ON DELETE CASCADE,
  offer_use_id UUID REFERENCES offer_uses(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL DEFAULT 'REDEMPTION'
    CHECK (purpose IN ('REDEMPTION', 'VERIFICATION', 'CUSTOMER_CONFIRMATION')),
  token_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'ISSUED'
    CHECK (status IN ('ISSUED', 'ACTIVE', 'SCANNED', 'VERIFIED', 'USED', 'EXPIRED', 'REVOKED')),
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  active_at TIMESTAMPTZ,
  scanned_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(reward_claim_id, gift_claim_id, offer_use_id) = 1),
  CHECK (expires_at IS NULL OR expires_at > issued_at),
  CHECK (revoked_at IS NULL OR status = 'REVOKED'),
  CHECK (used_at IS NULL OR status = 'USED')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemption_tokens_reward_claim_active
  ON redemption_tokens(reward_claim_id, purpose)
  WHERE reward_claim_id IS NOT NULL AND status IN ('ISSUED', 'ACTIVE', 'SCANNED', 'VERIFIED');

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemption_tokens_gift_claim_active
  ON redemption_tokens(gift_claim_id, purpose)
  WHERE gift_claim_id IS NOT NULL AND status IN ('ISSUED', 'ACTIVE', 'SCANNED', 'VERIFIED');

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemption_tokens_offer_use_active
  ON redemption_tokens(offer_use_id, purpose)
  WHERE offer_use_id IS NOT NULL AND status IN ('ISSUED', 'ACTIVE', 'SCANNED', 'VERIFIED');

CREATE INDEX IF NOT EXISTS idx_redemption_tokens_status_expires
  ON redemption_tokens(status, expires_at);

CREATE TABLE IF NOT EXISTS token_scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_id UUID NOT NULL REFERENCES redemption_tokens(id) ON DELETE CASCADE,
  scanned_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'SCANNED'
    CHECK (status IN ('SCANNED', 'VERIFIED', 'REJECTED')),
  verification_result TEXT,
  device_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_token_scans_token_created
  ON token_scans(token_id, scanned_at DESC);

CREATE INDEX IF NOT EXISTS idx_token_scans_actor_created
  ON token_scans(scanned_by_user_id, scanned_at DESC);

CREATE TABLE IF NOT EXISTS redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_id UUID REFERENCES redemption_tokens(id) ON DELETE SET NULL,
  reward_claim_id TEXT REFERENCES reward_claims(id) ON DELETE CASCADE,
  gift_claim_id UUID REFERENCES gift_claims(id) ON DELETE CASCADE,
  offer_use_id UUID REFERENCES offer_uses(id) ON DELETE CASCADE,
  redemption_kind TEXT NOT NULL CHECK (redemption_kind IN ('REWARD', 'GIFT', 'OFFER')),
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fulfilled_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  fulfiller_merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE SET NULL,
  fulfiller_brand_id TEXT REFERENCES brand_profiles(id) ON DELETE SET NULL,
  request_actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  idempotency_key TEXT,
  status TEXT NOT NULL DEFAULT 'PENDING_CONFIRMATION'
    CHECK (status IN ('PENDING_CONFIRMATION', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED')),
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  failure_reason TEXT,
  snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(reward_claim_id, gift_claim_id, offer_use_id) = 1),
  CHECK (num_nonnulls(fulfiller_merchant_id, fulfiller_brand_id) <= 1),
  CHECK (completed_at IS NULL OR status IN ('COMPLETED', 'REVERSED')),
  CHECK (cancelled_at IS NULL OR status = 'CANCELLED'),
  CHECK (
    (redemption_kind = 'REWARD' AND reward_claim_id IS NOT NULL AND gift_claim_id IS NULL AND offer_use_id IS NULL) OR
    (redemption_kind = 'GIFT' AND gift_claim_id IS NOT NULL AND reward_claim_id IS NULL AND offer_use_id IS NULL) OR
    (redemption_kind = 'OFFER' AND offer_use_id IS NOT NULL AND reward_claim_id IS NULL AND gift_claim_id IS NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemptions_reward_claim_completed
  ON redemptions(reward_claim_id)
  WHERE reward_claim_id IS NOT NULL AND status = 'COMPLETED';

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemptions_gift_claim_completed
  ON redemptions(gift_claim_id)
  WHERE gift_claim_id IS NOT NULL AND status = 'COMPLETED';

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemptions_offer_use_completed
  ON redemptions(offer_use_id)
  WHERE offer_use_id IS NOT NULL AND status = 'COMPLETED';

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemptions_token_completed
  ON redemptions(token_id)
  WHERE token_id IS NOT NULL AND status = 'COMPLETED';

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemptions_actor_idempotency
  ON redemptions(request_actor_user_id, idempotency_key)
  WHERE request_actor_user_id IS NOT NULL AND idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_redemptions_customer_status
  ON redemptions(customer_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_redemptions_fulfiller_merchant_status
  ON redemptions(fulfiller_merchant_id, status, created_at DESC)
  WHERE fulfiller_merchant_id IS NOT NULL;

COMMIT;