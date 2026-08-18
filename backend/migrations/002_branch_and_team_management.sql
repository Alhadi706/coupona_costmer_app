BEGIN;

CREATE TABLE IF NOT EXISTS branches (
  id TEXT PRIMARY KEY,
  merchant_id TEXT NOT NULL,
  name TEXT NOT NULL,
  address TEXT,
  location TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS branch_manager_permissions (
  branch_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  can_review_invoices BOOLEAN NOT NULL DEFAULT FALSE,
  can_create_offers BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage_group BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_reports BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_settlements BOOLEAN NOT NULL DEFAULT FALSE,
  can_add_cashiers BOOLEAN NOT NULL DEFAULT FALSE,
  can_reply_reports BOOLEAN NOT NULL DEFAULT FALSE,
  can_edit_point_value BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (branch_id, user_id)
);

CREATE TABLE IF NOT EXISTS brand_team_members (
  brand_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  can_manage_products BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_geo_distribution BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (brand_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_branches_merchant_id ON branches(merchant_id);
CREATE INDEX IF NOT EXISTS idx_cashier_profiles_branch_id ON cashier_profiles(branch_id);

COMMIT;
