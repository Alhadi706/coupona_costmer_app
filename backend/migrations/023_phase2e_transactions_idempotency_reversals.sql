BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS redemption_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  idempotency_key TEXT NOT NULL,
  request_type TEXT NOT NULL
    CHECK (request_type IN ('REWARD_REDEMPTION', 'GIFT_REDEMPTION', 'OFFER_USE', 'REVERSAL')),
  request_hash TEXT,
  status TEXT NOT NULL DEFAULT 'STARTED'
    CHECK (status IN ('STARTED', 'COMPLETED', 'FAILED')),
  redemption_id UUID REFERENCES redemptions(id) ON DELETE SET NULL,
  response_json JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(actor_user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_redemption_requests_actor_created
  ON redemption_requests(actor_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_redemption_requests_redemption
  ON redemption_requests(redemption_id)
  WHERE redemption_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS inventory_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  redemption_id UUID REFERENCES redemptions(id) ON DELETE SET NULL,
  reward_inventory_id UUID REFERENCES reward_inventory(id) ON DELETE SET NULL,
  gift_inventory_id UUID REFERENCES gift_inventory(id) ON DELETE SET NULL,
  adjustment_type TEXT NOT NULL
    CHECK (adjustment_type IN ('REDEEMED', 'REVERSAL_RESTOCK', 'ADMIN_CORRECTION')),
  quantity_delta INTEGER NOT NULL CHECK (quantity_delta <> 0),
  reason TEXT,
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(reward_inventory_id, gift_inventory_id) = 1)
);

CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_redemption
  ON inventory_adjustments(redemption_id)
  WHERE redemption_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_reward_inventory
  ON inventory_adjustments(reward_inventory_id, created_at DESC)
  WHERE reward_inventory_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_gift_inventory
  ON inventory_adjustments(gift_inventory_id, created_at DESC)
  WHERE gift_inventory_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS reversals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  redemption_id UUID NOT NULL REFERENCES redemptions(id) ON DELETE RESTRICT,
  actor_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'APPROVED'
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  compensating_ledger_entry_id TEXT REFERENCES ledger_entries(id) ON DELETE SET NULL,
  settlement_adjustment_id TEXT REFERENCES settlements(id) ON DELETE SET NULL,
  inventory_adjustment_id UUID REFERENCES inventory_adjustments(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(redemption_id)
);

CREATE INDEX IF NOT EXISTS idx_reversals_actor_created
  ON reversals(actor_user_id, created_at DESC);

ALTER TABLE ledger_entries ADD COLUMN IF NOT EXISTS redemption_id UUID REFERENCES redemptions(id) ON DELETE SET NULL;
ALTER TABLE ledger_entries ADD COLUMN IF NOT EXISTS reversal_id UUID REFERENCES reversals(id) ON DELETE SET NULL;
ALTER TABLE ledger_entries ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_ledger_entries_redemption
  ON ledger_entries(redemption_id)
  WHERE redemption_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ledger_entries_reversal
  ON ledger_entries(reversal_id)
  WHERE reversal_id IS NOT NULL;

ALTER TABLE settlements ADD COLUMN IF NOT EXISTS redemption_id UUID REFERENCES redemptions(id) ON DELETE SET NULL;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS reversal_id UUID REFERENCES reversals(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_settlements_redemption
  ON settlements(redemption_id)
  WHERE redemption_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_settlements_reversal
  ON settlements(reversal_id)
  WHERE reversal_id IS NOT NULL;

CREATE OR REPLACE FUNCTION register_redemption_request(
  p_actor_user_id TEXT,
  p_idempotency_key TEXT,
  p_request_type TEXT,
  p_request_hash TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_request_id UUID;
BEGIN
  INSERT INTO redemption_requests(actor_user_id, idempotency_key, request_type, request_hash)
  VALUES (p_actor_user_id, p_idempotency_key, p_request_type, p_request_hash)
  ON CONFLICT (actor_user_id, idempotency_key)
  DO UPDATE SET updated_at = redemption_requests.updated_at
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;