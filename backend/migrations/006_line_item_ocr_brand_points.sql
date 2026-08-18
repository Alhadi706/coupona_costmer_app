BEGIN;

CREATE TABLE IF NOT EXISTS customer_brand_fraction_balance (
  customer_id TEXT NOT NULL,
  brand_id TEXT NOT NULL,
  fraction_balance NUMERIC NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (customer_id, brand_id)
);

CREATE TABLE IF NOT EXISTS points_ledger_brand (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL,
  brand_id TEXT NOT NULL,
  invoice_scan_id TEXT,
  points_delta INTEGER NOT NULL,
  fraction_before NUMERIC NOT NULL DEFAULT 0,
  fraction_after NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_registry (
  id TEXT PRIMARY KEY,
  brand_id TEXT NOT NULL,
  name TEXT NOT NULL,
  image_url TEXT,
  barcode TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS invoice_line_items (
  id TEXT PRIMARY KEY,
  invoice_scan_id TEXT NOT NULL,
  item_name TEXT NOT NULL,
  quantity INTEGER,
  unit_price NUMERIC,
  line_total NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS brand_matches (
  id TEXT PRIMARY KEY,
  invoice_line_item_id TEXT NOT NULL,
  brand_id TEXT NOT NULL,
  product_id TEXT,
  confidence NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT 'approved';

CREATE INDEX IF NOT EXISTS idx_points_ledger_brand_customer
  ON points_ledger_brand(customer_id, brand_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invoice_line_items_invoice ON invoice_line_items(invoice_scan_id);
CREATE INDEX IF NOT EXISTS idx_brand_matches_brand_id ON brand_matches(brand_id);

COMMIT;
