BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS business_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  customer_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  source_merchant_id TEXT REFERENCES merchant_profiles(id) ON DELETE SET NULL,
  source_brand_id TEXT REFERENCES brand_profiles(id) ON DELETE SET NULL,
  source_coalition_id TEXT REFERENCES coalitions(id) ON DELETE SET NULL,
  redemption_id UUID REFERENCES redemptions(id) ON DELETE SET NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (num_nonnulls(source_merchant_id, source_brand_id, source_coalition_id) <= 1)
);

CREATE INDEX IF NOT EXISTS idx_business_events_aggregate_created
  ON business_events(aggregate_type, aggregate_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_business_events_customer_created
  ON business_events(customer_id, created_at DESC)
  WHERE customer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_business_events_redemption_created
  ON business_events(redemption_id, created_at DESC)
  WHERE redemption_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_business_events_type_created
  ON business_events(event_type, created_at DESC);

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  actor_role TEXT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  previous_state JSONB,
  new_state JSONB,
  reason TEXT,
  request_id TEXT,
  device_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_created
  ON audit_logs(entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_created
  ON audit_logs(actor_user_id, created_at DESC)
  WHERE actor_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_audit_logs_request
  ON audit_logs(request_id)
  WHERE request_id IS NOT NULL;

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS business_event_id UUID REFERENCES business_events(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_business_event
  ON notifications(business_event_id)
  WHERE business_event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_campaign_assignments_updated_at') THEN
    CREATE TRIGGER trg_campaign_assignments_updated_at
    BEFORE UPDATE ON campaign_assignments
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_gift_claims_updated_at') THEN
    CREATE TRIGGER trg_gift_claims_updated_at
    BEFORE UPDATE ON gift_claims
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_redemption_tokens_updated_at') THEN
    CREATE TRIGGER trg_redemption_tokens_updated_at
    BEFORE UPDATE ON redemption_tokens
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_redemptions_updated_at') THEN
    CREATE TRIGGER trg_redemptions_updated_at
    BEFORE UPDATE ON redemptions
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_gift_definitions_updated_at') THEN
    CREATE TRIGGER trg_gift_definitions_updated_at
    BEFORE UPDATE ON gift_definitions
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_reversals_updated_at') THEN
    CREATE TRIGGER trg_reversals_updated_at
    BEFORE UPDATE ON reversals
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;
END $$;

COMMIT;