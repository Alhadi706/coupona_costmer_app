BEGIN;

CREATE TABLE IF NOT EXISTS customer_merchant_fraction_balance (
  customer_id TEXT NOT NULL,
  merchant_id TEXT NOT NULL,
  fraction_balance NUMERIC NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (customer_id, merchant_id)
);

CREATE TABLE IF NOT EXISTS points_ledger_merchant (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL,
  merchant_id TEXT NOT NULL,
  invoice_scan_id TEXT,
  points_delta INTEGER NOT NULL,
  fraction_before NUMERIC NOT NULL DEFAULT 0,
  fraction_after NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_points_ledger_merchant_customer
  ON points_ledger_merchant(customer_id, merchant_id, created_at DESC);

COMMIT;
