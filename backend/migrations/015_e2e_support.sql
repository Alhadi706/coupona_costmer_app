BEGIN;

CREATE TABLE IF NOT EXISTS e2e_simulation_runs (
  id TEXT PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'started',
  details JSONB NOT NULL DEFAULT '{}'::jsonb
);

COMMIT;
