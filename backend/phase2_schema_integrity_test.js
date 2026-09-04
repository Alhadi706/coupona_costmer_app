const assert = require('node:assert/strict');
const test = require('node:test');
const path = require('node:path');
const { Pool } = require('pg');

require('dotenv').config({ path: path.join(__dirname, '.env') });

function createPool() {
  return new Pool({
    host: process.env.PHASE2_SCHEMA_TEST_PGHOST || '127.0.0.1',
    port: Number(process.env.PHASE2_SCHEMA_TEST_PGPORT || 5434),
    user: process.env.PHASE2_SCHEMA_TEST_PGUSER || 'kupuna_user',
    password: process.env.PGPASSWORD,
    database: process.env.PHASE2_SCHEMA_TEST_PGDATABASE || 'kupuna_db',
  });
}

async function withRollback(testContext, callback) {
  const pool = createPool();
  let client = null;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    await callback(client);
  } catch (error) {
    if (error.code === 'ECONNREFUSED' || /password authentication failed/i.test(String(error.message || ''))) {
      testContext.skip(`PostgreSQL unavailable: ${error.message}`);
      return;
    }
    throw error;
  } finally {
    if (client) {
      try { await client.query('ROLLBACK'); } catch (_rollbackError) {}
      client.release();
    }
    await pool.end();
  }
}

async function expectDbError(client, sql, params, expectedCode) {
  await client.query('SAVEPOINT expected_error');
  try {
    await client.query(sql, params);
    assert.fail(`Expected PostgreSQL error ${expectedCode}`);
  } catch (error) {
    assert.equal(error.code, expectedCode);
    await client.query('ROLLBACK TO SAVEPOINT expected_error');
  } finally {
    await client.query('RELEASE SAVEPOINT expected_error');
  }
}

async function insertUser(client, userId, email) {
  await client.query(
    `INSERT INTO users (id, email, password_hash, role)
     VALUES ($1, $2, 'test-hash', 'customer')`,
    [userId, email]
  );
}

test('phase 2 canonical tables exist', async (testContext) => {
  await withRollback(testContext, async (client) => {
    const expectedTables = [
      'campaign_assignments',
      'gift_claims',
      'offer_uses',
      'redemption_tokens',
      'token_scans',
      'redemptions',
      'cash_voucher_claims',
      'reward_inventory',
      'gift_definitions',
      'gift_contributors',
      'gift_inventory',
      'gift_fulfillment_locations',
      'redemption_requests',
      'reversals',
      'business_events',
      'audit_logs',
    ];
    const result = await client.query(
      `SELECT table_name
         FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = ANY($1::text[])`,
      [expectedTables]
    );
    assert.deepEqual(
      result.rows.map((row) => row.table_name).sort(),
      expectedTables.sort()
    );
  });
});

test('redemption tokens enforce exactly one parent and one active token per parent', async (testContext) => {
  await withRollback(testContext, async (client) => {
    await insertUser(client, 'phase2-token-user', 'phase2-token@example.com');
    await client.query(
      `INSERT INTO reward_claims (id, owner_id, source_type, source_id, points_cost, reward_kind, pickup_qr_code, status)
       VALUES ('phase2-claim', 'phase2-token-user', 'merchant', 'merchant-1', 10, 'physical', 'phase2-qr', 'pending_pickup')`
    );

    await expectDbError(
      client,
      `INSERT INTO redemption_tokens (token_hash) VALUES ('no-parent-token')`,
      [],
      '23514'
    );

    await client.query(
      `INSERT INTO redemption_tokens (reward_claim_id, token_hash, status)
       VALUES ('phase2-claim', 'token-hash-1', 'ACTIVE')`
    );

    await expectDbError(
      client,
      `INSERT INTO redemption_tokens (reward_claim_id, token_hash, status)
       VALUES ('phase2-claim', 'token-hash-2', 'ACTIVE')`,
      [],
      '23505'
    );
  });
});

test('gift claim and redemption uniqueness prevent duplicate completion', async (testContext) => {
  await withRollback(testContext, async (client) => {
    await insertUser(client, 'phase2-gift-user', 'phase2-gift@example.com');
    await client.query(
      `INSERT INTO promo_campaigns (id, source_type, source_id, campaign_type, title, segment_filter, starts_at, ends_at, status)
       VALUES ('phase2-campaign', 'merchant', 'merchant-1', 'free_gift', 'Phase 2 Gift', 'all', NOW(), NOW() + INTERVAL '7 days', 'active')`
    );
    const assignment = await client.query(
      `INSERT INTO campaign_assignments (campaign_id, customer_id, assignment_kind, status)
       VALUES ('phase2-campaign', 'phase2-gift-user', 'gift', 'CLAIMED')
       RETURNING id`
    );
    const assignmentId = assignment.rows[0].id;
    const claim = await client.query(
      `INSERT INTO gift_claims (assignment_id, customer_id, status)
       VALUES ($1, 'phase2-gift-user', 'TOKENIZED')
       RETURNING id`,
      [assignmentId]
    );
    const giftClaimId = claim.rows[0].id;

    await expectDbError(
      client,
      `INSERT INTO gift_claims (assignment_id, customer_id, status)
       VALUES ($1, 'phase2-gift-user', 'CLAIMED')`,
      [assignmentId],
      '23505'
    );

    const token = await client.query(
      `INSERT INTO redemption_tokens (gift_claim_id, token_hash, status)
       VALUES ($1, 'gift-token-hash-1', 'USED')
       RETURNING id`,
      [giftClaimId]
    );
    const tokenId = token.rows[0].id;

    await client.query(
      `INSERT INTO redemptions (token_id, gift_claim_id, redemption_kind, customer_id, status, completed_at)
       VALUES ($1, $2, 'GIFT', 'phase2-gift-user', 'COMPLETED', NOW())`,
      [tokenId, giftClaimId]
    );

    await expectDbError(
      client,
      `INSERT INTO redemptions (gift_claim_id, redemption_kind, customer_id, status, completed_at)
       VALUES ($1, 'GIFT', 'phase2-gift-user', 'COMPLETED', NOW())`,
      [giftClaimId],
      '23505'
    );
  });
});

test('redemption request idempotency returns the same request id', async (testContext) => {
  await withRollback(testContext, async (client) => {
    await insertUser(client, 'phase2-idem-user', 'phase2-idem@example.com');
    const first = await client.query(
      `SELECT register_redemption_request($1, $2, $3, $4) AS id`,
      ['phase2-idem-user', 'idem-key-1', 'GIFT_REDEMPTION', 'hash-1']
    );
    const second = await client.query(
      `SELECT register_redemption_request($1, $2, $3, $4) AS id`,
      ['phase2-idem-user', 'idem-key-1', 'GIFT_REDEMPTION', 'hash-1']
    );
    assert.equal(second.rows[0].id, first.rows[0].id);
  });
});

test('one approved reversal is allowed per redemption', async (testContext) => {
  await withRollback(testContext, async (client) => {
    await insertUser(client, 'phase2-reversal-user', 'phase2-reversal@example.com');
    await client.query(
      `INSERT INTO reward_claims (id, owner_id, source_type, source_id, points_cost, reward_kind, pickup_qr_code, status)
       VALUES ('phase2-reversal-claim', 'phase2-reversal-user', 'merchant', 'merchant-1', 10, 'physical', 'phase2-reversal-qr', 'redeemed')`
    );
    const redemption = await client.query(
      `INSERT INTO redemptions (reward_claim_id, redemption_kind, customer_id, status, completed_at)
       VALUES ('phase2-reversal-claim', 'REWARD', 'phase2-reversal-user', 'COMPLETED', NOW())
       RETURNING id`
    );
    const redemptionId = redemption.rows[0].id;

    await client.query(
      `INSERT INTO reversals (redemption_id, actor_user_id, reason, status)
       VALUES ($1, 'phase2-reversal-user', 'test reversal', 'APPROVED')`,
      [redemptionId]
    );

    await expectDbError(
      client,
      `INSERT INTO reversals (redemption_id, actor_user_id, reason, status)
       VALUES ($1, 'phase2-reversal-user', 'duplicate reversal', 'APPROVED')`,
      [redemptionId],
      '23505'
    );
  });
});