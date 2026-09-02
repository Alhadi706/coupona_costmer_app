const { pool } = require('./db');

async function createCampaignTables() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS promo_campaigns (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL CHECK (source_type IN ('merchant', 'brand')),
      source_id TEXT NOT NULL,
      campaign_type TEXT NOT NULL CHECK (campaign_type IN ('free_gift', 'early_access_discount', 'raffle')),
      title TEXT NOT NULL,
      description TEXT,
      discount_percentage NUMERIC,
      gift_description TEXT,
      min_invoice_amount NUMERIC NOT NULL DEFAULT 0,
      segment_filter TEXT NOT NULL DEFAULT 'all',
      segment_params JSONB NOT NULL DEFAULT '{}'::jsonb,
      starts_at TIMESTAMPTZ NOT NULL,
      ends_at TIMESTAMPTZ NOT NULL,
      usage_limit_per_customer INTEGER NOT NULL DEFAULT 1,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_promo_campaigns_source ON promo_campaigns(source_type, source_id)');
  await pool.query("ALTER TABLE promo_campaigns ALTER COLUMN status SET DEFAULT 'draft'");
  await pool.query('ALTER TABLE promo_campaigns ADD COLUMN IF NOT EXISTS launched_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE promo_campaigns ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS promo_campaign_coupons (
      id TEXT PRIMARY KEY,
      campaign_id TEXT NOT NULL REFERENCES promo_campaigns(id) ON DELETE CASCADE,
      customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      qr_code TEXT NOT NULL UNIQUE,
      status TEXT NOT NULL DEFAULT 'issued',
      issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      redeemed_at TIMESTAMPTZ,
      redeemed_by TEXT,
      invoice_id TEXT
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_promo_campaign_coupons_customer ON promo_campaign_coupons(customer_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_promo_campaign_coupons_campaign ON promo_campaign_coupons(campaign_id)');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS raffle_tickets (
      id TEXT PRIMARY KEY,
      campaign_id TEXT NOT NULL REFERENCES promo_campaigns(id) ON DELETE CASCADE,
      customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      invoice_id TEXT,
      ticket_number TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_raffle_tickets_campaign ON raffle_tickets(campaign_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_raffle_tickets_customer ON raffle_tickets(customer_id)');
}

module.exports = createCampaignTables;
