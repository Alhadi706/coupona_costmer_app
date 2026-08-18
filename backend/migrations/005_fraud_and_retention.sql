BEGIN;

CREATE TABLE IF NOT EXISTS fraud_flags (
  id TEXT PRIMARY KEY,
  owner_id TEXT,
  invoice_scan_id TEXT,
  reason TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS image_hash TEXT;
ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_fraud_flags_owner_created ON fraud_flags(owner_id, created_at DESC);

INSERT INTO app_settings (key, value)
VALUES ('daily_invoice_limit', '10'), ('invoice_retention_months', '24')
ON CONFLICT (key) DO NOTHING;

COMMIT;
