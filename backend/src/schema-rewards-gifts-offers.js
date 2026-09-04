const fs = require('fs/promises');
const path = require('path');
const { pool } = require('./db');

const PHASE_2_MIGRATIONS = [
  '019_phase2a_assignment_claim_foundation.sql',
  '020_phase2b_token_scan_redemption_foundation.sql',
  '021_phase2c_reward_inventory_fulfillment.sql',
  '022_phase2d_gift_definitions_contributors.sql',
  '023_phase2e_transactions_idempotency_reversals.sql',
  '024_phase2f_events_audit_notifications.sql',
  '025_remove_legacy_free_gift_campaigns.sql',
  '026_cash_voucher_claims_canonical_redemption.sql',
  '027_cash_value_idempotency_type.sql',
];

async function createRewardsGiftsOffersTables() {
  const migrationsDir = path.join(__dirname, '..', 'migrations');
  for (const fileName of PHASE_2_MIGRATIONS) {
    const sql = await fs.readFile(path.join(migrationsDir, fileName), 'utf8');
    await pool.query(sql);
  }
}

module.exports = createRewardsGiftsOffersTables;