-- System Owner & MFA Enhancement
-- Add fields for single system owner with email-based 2FA

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_system_owner BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_challenge_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_challenge_code_hash VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_challenge_expires_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_challenge_attempts INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_owner_login_at TIMESTAMPTZ;

-- Constraint: Maximum 1 system owner
CREATE OR REPLACE FUNCTION check_single_owner()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_system_owner THEN
    IF (SELECT COUNT(*) FROM users WHERE is_system_owner = TRUE AND id != NEW.id) > 0 THEN
      RAISE EXCEPTION 'Only one system owner allowed';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ensure_single_owner ON users;
CREATE TRIGGER ensure_single_owner
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION check_single_owner();

-- Audit: log owner changes
CREATE TABLE IF NOT EXISTS owner_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(50) NOT NULL,
  user_id TEXT REFERENCES users(id),
  event_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- MFA Challenges for owner login
CREATE TABLE IF NOT EXISTS owner_mfa_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id TEXT NOT NULL REFERENCES users(id),
  code_hash VARCHAR(255) NOT NULL,
  attempts INT DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_owner_mfa_owner ON owner_mfa_challenges(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_owner_mfa_expires ON owner_mfa_challenges(expires_at);

CREATE INDEX IF NOT EXISTS idx_owner_audit_user ON owner_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_owner_audit_created ON owner_audit_log(created_at);
