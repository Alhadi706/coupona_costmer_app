BEGIN;

ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS payment_method_ref TEXT;

COMMIT;
