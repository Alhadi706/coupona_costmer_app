BEGIN;

CREATE TABLE IF NOT EXISTS community_offers (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('FOOD', 'REAL_ESTATE', 'SERVICES', 'RENTALS')),
  images_json JSONB NOT NULL DEFAULT '[]'::jsonb,
  price_lyd NUMERIC NOT NULL DEFAULT 0,
  accepts_points_trade BOOLEAN NOT NULL DEFAULT FALSE,
  visibility_scope TEXT NOT NULL DEFAULT 'PUBLIC_COMMUNITY' CHECK (visibility_scope IN ('MY_MERCHANTS_ONLY', 'PUBLIC_COMMUNITY')),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SOLD', 'ARCHIVED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_offers_customer ON community_offers(customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_offers_cat_status ON community_offers(category, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_offers_scope_status ON community_offers(visibility_scope, status, created_at DESC);

COMMIT;
