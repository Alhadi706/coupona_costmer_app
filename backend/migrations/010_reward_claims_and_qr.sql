BEGIN;

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
);

CREATE INDEX IF NOT EXISTS idx_reward_claims_owner_status
  ON reward_claims(owner_id, status, created_at DESC);

COMMIT;
