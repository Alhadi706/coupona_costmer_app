BEGIN;

CREATE INDEX IF NOT EXISTS idx_role_requests_status_created
  ON role_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status_next
  ON subscriptions(status, next_billing_date);

COMMIT;
