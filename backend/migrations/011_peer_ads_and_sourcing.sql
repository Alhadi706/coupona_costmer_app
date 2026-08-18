BEGIN;

CREATE TABLE IF NOT EXISTS peer_ads (
  id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  content TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_value TEXT,
  fee_paid NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft',
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sourcing_inquiries (
  id TEXT PRIMARY KEY,
  peer_ad_id TEXT NOT NULL,
  merchant_user_id TEXT NOT NULL,
  owner_user_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'opened',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_peer_ads_status_created ON peer_ads(status, created_at DESC);

COMMIT;
