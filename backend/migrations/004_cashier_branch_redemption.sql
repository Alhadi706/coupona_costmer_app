BEGIN;

ALTER TABLE cashier_profiles ADD COLUMN IF NOT EXISTS merchant_id TEXT;
ALTER TABLE cashier_profiles ADD COLUMN IF NOT EXISTS branch_id TEXT;
ALTER TABLE cashier_profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_cashier_profiles_user_branch
  ON cashier_profiles(user_id, branch_id, is_active);

COMMIT;
