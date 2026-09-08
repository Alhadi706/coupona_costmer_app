BEGIN;

-- Bind dynamic cash vouchers to a specific merchant so point validation and
-- redemption are scoped to the store the customer selected in the calculator.
ALTER TABLE cash_voucher_claims
  ADD COLUMN IF NOT EXISTS merchant_id TEXT REFERENCES merchant_profiles(id);

CREATE INDEX IF NOT EXISTS idx_cash_voucher_claims_merchant
  ON cash_voucher_claims(merchant_id, status)
  WHERE merchant_id IS NOT NULL;

COMMIT;
