BEGIN;

CREATE TABLE IF NOT EXISTS loyalty_health_scores (
  id TEXT PRIMARY KEY,
  merchant_id TEXT NOT NULL,
  score NUMERIC NOT NULL,
  trend TEXT NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMIT;
