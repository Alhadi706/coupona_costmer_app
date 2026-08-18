BEGIN;

ALTER TABLE merchant_profiles
  ADD COLUMN IF NOT EXISTS point_value NUMERIC;

ALTER TABLE brand_profiles
  ADD COLUMN IF NOT EXISTS point_value NUMERIC;

COMMIT;
