BEGIN;

ALTER TABLE redemption_requests DROP CONSTRAINT IF EXISTS redemption_requests_request_type_check;
ALTER TABLE redemption_requests ADD CONSTRAINT redemption_requests_request_type_check
  CHECK (request_type IN ('REWARD_REDEMPTION', 'GIFT_REDEMPTION', 'OFFER_USE', 'REVERSAL', 'CASH_VALUE_REDEMPTION'));

COMMIT;