BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS cash_voucher_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  points_cost INTEGER NOT NULL CHECK (points_cost > 0),
  cash_value_lyd NUMERIC(12,2) NOT NULL CHECK (cash_value_lyd > 0),
  status TEXT NOT NULL DEFAULT 'CLAIMED'
    CHECK (status IN ('CLAIMED', 'TOKENIZED', 'VERIFIED', 'REDEEMED', 'EXPIRED', 'CANCELLED', 'REVERSED')),
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
  CHECK (redeemed_at IS NULL OR status IN ('REDEEMED', 'REVERSED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_voucher_claims_customer_idempotency
  ON cash_voucher_claims(customer_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cash_voucher_claims_customer_status
  ON cash_voucher_claims(customer_id, status, claimed_at DESC);

ALTER TABLE redemption_tokens ADD COLUMN IF NOT EXISTS cash_voucher_claim_id UUID REFERENCES cash_voucher_claims(id) ON DELETE CASCADE;

DROP INDEX IF EXISTS uq_redemption_tokens_cash_voucher_active;
CREATE UNIQUE INDEX uq_redemption_tokens_cash_voucher_active
  ON redemption_tokens(cash_voucher_claim_id, purpose)
  WHERE cash_voucher_claim_id IS NOT NULL AND status IN ('ISSUED', 'ACTIVE', 'SCANNED', 'VERIFIED');

ALTER TABLE redemption_tokens DROP CONSTRAINT IF EXISTS redemption_tokens_check;
ALTER TABLE redemption_tokens DROP CONSTRAINT IF EXISTS redemption_tokens_exactly_one_parent;
ALTER TABLE redemption_tokens ADD CONSTRAINT redemption_tokens_exactly_one_parent
  CHECK (num_nonnulls(reward_claim_id, gift_claim_id, offer_use_id, cash_voucher_claim_id) = 1);

ALTER TABLE redemptions ADD COLUMN IF NOT EXISTS cash_voucher_claim_id UUID REFERENCES cash_voucher_claims(id) ON DELETE CASCADE;

ALTER TABLE redemptions DROP CONSTRAINT IF EXISTS redemptions_redemption_kind_check;
ALTER TABLE redemptions ADD CONSTRAINT redemptions_redemption_kind_check
  CHECK (redemption_kind IN ('REWARD', 'GIFT', 'OFFER', 'CASH_VALUE'));

ALTER TABLE redemptions DROP CONSTRAINT IF EXISTS redemptions_check;
ALTER TABLE redemptions DROP CONSTRAINT IF EXISTS redemptions_exactly_one_parent;
ALTER TABLE redemptions ADD CONSTRAINT redemptions_exactly_one_parent
  CHECK (num_nonnulls(reward_claim_id, gift_claim_id, offer_use_id, cash_voucher_claim_id) = 1);

ALTER TABLE redemptions DROP CONSTRAINT IF EXISTS redemptions_check4;
ALTER TABLE redemptions DROP CONSTRAINT IF EXISTS redemptions_kind_matches_parent;
ALTER TABLE redemptions ADD CONSTRAINT redemptions_kind_matches_parent
  CHECK (
    (redemption_kind = 'REWARD' AND reward_claim_id IS NOT NULL AND gift_claim_id IS NULL AND offer_use_id IS NULL AND cash_voucher_claim_id IS NULL) OR
    (redemption_kind = 'GIFT' AND gift_claim_id IS NOT NULL AND reward_claim_id IS NULL AND offer_use_id IS NULL AND cash_voucher_claim_id IS NULL) OR
    (redemption_kind = 'OFFER' AND offer_use_id IS NOT NULL AND reward_claim_id IS NULL AND gift_claim_id IS NULL AND cash_voucher_claim_id IS NULL) OR
    (redemption_kind = 'CASH_VALUE' AND cash_voucher_claim_id IS NOT NULL AND reward_claim_id IS NULL AND gift_claim_id IS NULL AND offer_use_id IS NULL)
  );

CREATE UNIQUE INDEX IF NOT EXISTS uq_redemptions_cash_voucher_completed
  ON redemptions(cash_voucher_claim_id)
  WHERE cash_voucher_claim_id IS NOT NULL AND status = 'COMPLETED';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_cash_voucher_claims_updated_at') THEN
    CREATE TRIGGER trg_cash_voucher_claims_updated_at
    BEFORE UPDATE ON cash_voucher_claims
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;
END $$;

COMMIT;