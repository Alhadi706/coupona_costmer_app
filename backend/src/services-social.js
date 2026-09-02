const { pool } = require('./db');
const { FCM_SERVER_KEY } = require('./app');
const { id, toIso } = require('./helpers');
const { getIntSetting } = require('./access-control');

async function runSubscriptionTransitions() {
  const client = await pool.connect();
  const now = new Date();
  try {
    await client.query('BEGIN');
    const graceDays = await getIntSetting(client, 'grace_period_days_default', 7);

    const trialRows = (await client.query(
      `SELECT s.id, s.trial_end_date, rr.user_id
         FROM subscriptions s
         LEFT JOIN role_requests rr ON rr.role_profile_id = s.role_profile_id AND rr.role_type = s.role_type
        WHERE s.status = 'trial'`
    )).rows;

    for (const row of trialRows) {
      if (!row.trial_end_date) continue;
      const trialEnd = new Date(row.trial_end_date);
      if (Number.isNaN(trialEnd.getTime())) continue;

      const msLeft = trialEnd.getTime() - now.getTime();
      const daysLeft = Math.ceil(msLeft / (24 * 60 * 60 * 1000));

      if ((daysLeft === 7 || daysLeft === 1) && row.user_id) {
        await client.query(
          `INSERT INTO notifications (id, user_id, type, title, body, payload)
           VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
          [
            id(),
            row.user_id,
            'subscription_trial_reminder',
            'Trial ending soon',
            `Trial ends in ${daysLeft} day(s).`,
            JSON.stringify({ subscriptionId: row.id, daysLeft }),
          ]
        );
      }

      if (now >= trialEnd) {
        await applySubscriptionTransition(client, row.id, 'grace_period', {
          nextBillingDate: new Date(now.getTime() + graceDays * 24 * 60 * 60 * 1000).toISOString(),
          trialEndDate: trialEnd.toISOString(),
        });
      }
    }

    const graceRows = (await client.query(
      `SELECT id
         FROM subscriptions
        WHERE status = 'grace_period'
          AND next_billing_date IS NOT NULL
          AND next_billing_date <= NOW()`
    )).rows;
    for (const row of graceRows) {
      await applySubscriptionTransition(client, row.id, 'suspended');
    }

    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

async function hasBlockRelation(userA, userB) {
  const row = (await pool.query(
    `SELECT EXISTS(
       SELECT 1
         FROM user_blocks
        WHERE (blocker_id = $1 AND blocked_id = $2)
           OR (blocker_id = $2 AND blocked_id = $1)
     ) AS blocked`,
    [userA, userB]
  )).rows[0];
  return Boolean(row && row.blocked);
}

async function isPrivateChatParticipant(chatId, userId) {
  const row = (await pool.query(
    'SELECT 1 FROM private_chat_participants WHERE chat_id = $1 AND user_id = $2 LIMIT 1',
    [chatId, userId]
  )).rows[0];
  return Boolean(row);
}

async function getPeerUserId(chatId, userId) {
  const row = (await pool.query(
    'SELECT user_id FROM private_chat_participants WHERE chat_id = $1 AND user_id <> $2 LIMIT 1',
    [chatId, userId]
  )).rows[0];
  return row ? row.user_id : null;
}

async function sendFcmToTokens(tokens, title, body, data = {}) {
  if (!Array.isArray(tokens) || tokens.length === 0) {
    return { sent: false, reason: 'no_tokens' };
  }
  if (!FCM_SERVER_KEY) {
    return { sent: false, reason: 'missing_fcm_server_key' };
  }

  const payload = JSON.stringify({
    registration_ids: tokens,
    notification: {
      title: String(title || 'Kupuna'),
      body: String(body || ''),
    },
    data,
  });

  return new Promise((resolve) => {
    const req = https.request(
      {
        hostname: 'fcm.googleapis.com',
        path: '/fcm/send',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          Authorization: `key=${FCM_SERVER_KEY}`,
        },
      },
      (res) => {
        let bodyText = '';
        res.on('data', (chunk) => {
          bodyText += chunk.toString('utf8');
        });
        res.on('end', () => {
          resolve({
            sent: res.statusCode >= 200 && res.statusCode < 300,
            statusCode: res.statusCode,
            response: bodyText,
          });
        });
      }
    );

    req.on('error', (err) => {
      resolve({ sent: false, reason: 'network_error', error: String(err.message || err) });
    });

    req.write(payload);
    req.end();
  });
}

async function getActivePushTokens(db, userId) {
  const rows = (await db.query(
    `SELECT token
       FROM user_push_tokens
      WHERE user_id = $1
        AND is_active = TRUE
      ORDER BY updated_at DESC
      LIMIT 10`,
    [userId]
  )).rows;
  return rows.map((row) => String(row.token || '').trim()).filter(Boolean);
}

async function insertNotification(db, userId, type, title, body, payload = {}) {
  if (!userId) return;
  const notificationId = id();
  const targetScreen = payload?.target_screen || payload?.targetScreen || null;
  await db.query(
    `INSERT INTO notifications (id, user_id, type, title, body, target_screen, payload)
     VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)`,
    [notificationId, userId, type, title || null, body || null, targetScreen, JSON.stringify(payload || {})]
  );

  const tokens = await getActivePushTokens(db, userId);
  await sendFcmToTokens(tokens, title, body, {
    type,
    notificationId,
    ...payload,
  });
}

async function ensureCommunityGroupForRole(client, roleType, roleProfileId, ownerUserId, fallbackName) {
  const existing = (await client.query(
    `SELECT id, name
       FROM community_groups
      WHERE role_type = $1
        AND role_profile_id = $2
      LIMIT 1`,
    [roleType, roleProfileId]
  )).rows[0];
  if (existing) return existing;

  const groupId = id();
  const groupName = String(fallbackName || `${roleType} community`).trim();
  await client.query(
    `INSERT INTO community_groups (id, role_type, role_profile_id, owner_user_id, name)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (role_type, role_profile_id) DO NOTHING`,
    [groupId, roleType, roleProfileId, ownerUserId, groupName]
  );

  const inserted = (await client.query(
    `SELECT id, name
       FROM community_groups
      WHERE role_type = $1
        AND role_profile_id = $2
      LIMIT 1`,
    [roleType, roleProfileId]
  )).rows[0];

  if (inserted) {
    await client.query(
      `INSERT INTO community_group_members (group_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (group_id, user_id) DO NOTHING`,
      [inserted.id, ownerUserId]
    );
  }

  return inserted || { id: groupId, name: groupName };
}

async function ensureCommunityMembership(client, groupId, userId) {
  await client.query(
    `INSERT INTO community_group_members (group_id, user_id)
     VALUES ($1, $2)
     ON CONFLICT (group_id, user_id) DO NOTHING`,
    [groupId, userId]
  );
}

async function joinCustomerToMerchantCommunity(client, customerId, merchantProfileId) {
  if (!merchantProfileId) return;
  const approvedCount = (await client.query(
    `SELECT COUNT(*)::int AS c
       FROM invoice_scans
      WHERE owner_id = $1
        AND merchant_profile_id = $2
        AND state = 'approved'`,
    [customerId, merchantProfileId]
  )).rows[0]?.c || 0;
  if (approvedCount > 1) return;

  const group = (await client.query(
    `SELECT id
       FROM community_groups
      WHERE role_type = 'merchant'
        AND role_profile_id = $1
      LIMIT 1`,
    [merchantProfileId]
  )).rows[0];
  if (!group) return;
  const ban = (await client.query(
    `SELECT 1
       FROM community_group_bans
      WHERE group_id = $1 AND user_id = $2
      LIMIT 1`,
    [group.id, customerId]
  )).rows[0];
  if (ban) return;
  await ensureCommunityMembership(client, group.id, customerId);
}

async function joinCustomerToBrandCommunities(client, customerId, invoiceScanId) {
  const brandRows = (await client.query(
    `SELECT DISTINCT bm.brand_id
       FROM brand_matches bm
       JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
      WHERE li.invoice_scan_id = $1`,
    [invoiceScanId]
  )).rows;

  for (const row of brandRows) {
    const approvedCount = (await client.query(
      `SELECT COUNT(DISTINCT s.id)::int AS c
         FROM invoice_scans s
         JOIN invoice_line_items li ON li.invoice_scan_id = s.id
         JOIN brand_matches bm ON bm.invoice_line_item_id = li.id
        WHERE s.owner_id = $1
          AND s.state = 'approved'
          AND bm.brand_id = $2`,
      [customerId, row.brand_id]
    )).rows[0]?.c || 0;
    if (approvedCount > 1) continue;

    const group = (await client.query(
      `SELECT id
         FROM community_groups
        WHERE role_type = 'brand'
          AND role_profile_id = $1
        LIMIT 1`,
      [row.brand_id]
    )).rows[0];
    if (!group) continue;
    const ban = (await client.query(
      `SELECT 1
         FROM community_group_bans
        WHERE group_id = $1 AND user_id = $2
        LIMIT 1`,
      [group.id, customerId]
    )).rows[0];
    if (ban) continue;
    await ensureCommunityMembership(client, group.id, customerId);
  }
}

async function canModerateCommunityGroup(client, groupId, userId) {
  const owner = (await client.query(
    `SELECT 1
       FROM community_groups
      WHERE id = $1
        AND owner_user_id = $2
      LIMIT 1`,
    [groupId, userId]
  )).rows[0];
  if (owner) return true;

  const manager = (await client.query(
    `SELECT 1
       FROM community_groups cg
       JOIN branches b ON b.merchant_id = cg.role_profile_id
       JOIN branch_manager_permissions bmp ON bmp.branch_id = b.id AND bmp.user_id = $2
      WHERE cg.id = $1
        AND cg.role_type = 'merchant'
        AND bmp.can_manage_group = TRUE
      LIMIT 1`,
    [groupId, userId]
  )).rows[0];
  if (manager) return true;

  const brandTeam = (await client.query(
    `SELECT 1
       FROM community_groups cg
       JOIN brand_team_members btm ON btm.brand_id = cg.role_profile_id AND btm.user_id = $2
      WHERE cg.id = $1
        AND cg.role_type = 'brand'
        AND btm.can_manage_products = TRUE
      LIMIT 1`,
    [groupId, userId]
  )).rows[0];
  return Boolean(brandTeam);
}

function canTransitionSubscription(from, to) {
  if (from === to) return true;
  switch (from) {
    case 'trial':
      return to === 'active' || to === 'grace_period';
    case 'active':
      return to === 'grace_period' || to === 'suspended';
    case 'grace_period':
      return to === 'active' || to === 'suspended';
    case 'suspended':
      return to === 'active';
    default:
      return false;
  }
}

async function getSubscriptionOwnerUserId(client, roleType, roleProfileId) {
  if (roleType === 'merchant') {
    const row = (await client.query('SELECT user_id FROM merchant_profiles WHERE id = $1 LIMIT 1', [roleProfileId])).rows[0];
    return row ? row.user_id : null;
  }
  if (roleType === 'brand') {
    const row = (await client.query('SELECT user_id FROM brand_profiles WHERE id = $1 LIMIT 1', [roleProfileId])).rows[0];
    return row ? row.user_id : null;
  }
  return null;
}

async function syncCashierProfilesForMerchantSubscription(client, merchantId, subscriptionStatus) {
  if (!merchantId) return;
  const cashierActive = subscriptionStatus !== 'suspended';
  await client.query(
    'UPDATE cashier_profiles SET is_active = $2 WHERE merchant_id = $1',
    [merchantId, cashierActive]
  );
}

async function applySubscriptionTransition(client, subscriptionId, targetStatus, options = {}) {
  const row = (await client.query(
    `SELECT id, role_profile_id, role_type, status, trial_end_date, next_billing_date
       FROM subscriptions
      WHERE id = $1
      LIMIT 1`,
    [subscriptionId]
  )).rows[0];
  if (!row) {
    throw new Error('subscription_not_found');
  }

  const fromStatus = String(row.status || '').trim();
  if (!canTransitionSubscription(fromStatus, targetStatus)) {
    throw new Error(`invalid_subscription_transition:${fromStatus}->${targetStatus}`);
  }

  const ownerUserId = await getSubscriptionOwnerUserId(client, row.role_type, row.role_profile_id);
  const patch = {
    trialEndDate: row.trial_end_date,
    nextBillingDate: row.next_billing_date,
    ...options,
  };

  if (targetStatus === 'grace_period' && !patch.nextBillingDate) {
    const graceDays = await getIntSetting(client, 'grace_period_days_default', 7);
    patch.nextBillingDate = new Date(Date.now() + graceDays * 24 * 60 * 60 * 1000).toISOString();
  }

  if (targetStatus === 'active') {
    const nextBilling = patch.nextBillingDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    patch.nextBillingDate = nextBilling;
  }

  await client.query(
    `UPDATE subscriptions
        SET status = $2,
            trial_end_date = COALESCE($3, trial_end_date),
            next_billing_date = $4,
            updated_at = NOW()
      WHERE id = $1`,
    [subscriptionId, targetStatus, patch.trialEndDate, patch.nextBillingDate || null]
  );

  if (row.role_type === 'merchant') {
    await syncCashierProfilesForMerchantSubscription(client, row.role_profile_id, targetStatus);
  }

  if (ownerUserId) {
    let type = 'subscription_updated';
    let title = 'Subscription updated';
    let body = `Subscription status is now ${targetStatus}.`;
    if (targetStatus === 'grace_period') {
      type = 'subscription_grace_period';
      title = 'Trial ended';
      body = 'Your subscription entered grace period. Full dashboard access remains available until billing is due.';
    } else if (targetStatus === 'suspended') {
      type = 'subscription_suspended';
      title = 'Subscription suspended';
      body = 'Your dashboard is now read-only until subscription reactivation.';
    } else if (targetStatus === 'active') {
      type = 'subscription_reactivated';
      title = 'Subscription reactivated';
      body = 'Your dashboard access has been fully restored.';
    }
    await insertNotification(client, ownerUserId, type, title, body, {
      subscriptionId,
      roleType: row.role_type,
      roleProfileId: row.role_profile_id,
      status: targetStatus,
    });
  }

  return {
    id: row.id,
    roleProfileId: row.role_profile_id,
    roleType: row.role_type,
    fromStatus,
    status: targetStatus,
    trialEndDate: patch.trialEndDate ? toIso(patch.trialEndDate) : toIso(row.trial_end_date),
    nextBillingDate: patch.nextBillingDate ? toIso(patch.nextBillingDate) : toIso(row.next_billing_date),
  };
}

async function assertMerchantSubscriptionWritable(client, merchantId) {
  const row = (await client.query(
    `SELECT status
       FROM subscriptions
      WHERE role_type = 'merchant'
        AND role_profile_id = $1
      ORDER BY updated_at DESC
      LIMIT 1`,
    [merchantId]
  )).rows[0];
  if (!row) {
    throw new Error('merchant_subscription_not_found');
  }
  if (String(row.status || '') === 'suspended') {
    const err = new Error('merchant_subscription_read_only');
    err.code = 'merchant_subscription_read_only';
    throw err;
  }
  return row;
}

function isMerchantSubscriptionReadOnlyError(error) {
  return error?.code === 'merchant_subscription_read_only' || String(error?.message || '') === 'merchant_subscription_read_only';
}

async function ensurePrivateChatBetweenUsers(client, userA, userB, title) {
  const participants = [String(userA), String(userB)].sort();
  const existing = (await client.query(
    `SELECT c.id
       FROM private_chats c
       JOIN private_chat_participants p1 ON p1.chat_id = c.id AND p1.user_id = $1
       JOIN private_chat_participants p2 ON p2.chat_id = c.id AND p2.user_id = $2
      LIMIT 1`,
    [participants[0], participants[1]]
  )).rows[0];

  if (existing) return existing.id;

  const chatId = id();
  await client.query(
    'INSERT INTO private_chats (id, title, last_message, updated_at) VALUES ($1, $2, $3, NOW())',
    [chatId, title || 'Private chat', '']
  );
  await client.query(
    'INSERT INTO private_chat_participants (chat_id, user_id) VALUES ($1, $2), ($1, $3)',
    [chatId, participants[0], participants[1]]
  );
  return chatId;
}


module.exports = {
  runSubscriptionTransitions,
  hasBlockRelation,
  isPrivateChatParticipant,
  getPeerUserId,
  sendFcmToTokens,
  getActivePushTokens,
  insertNotification,
  ensureCommunityGroupForRole,
  ensureCommunityMembership,
  joinCustomerToMerchantCommunity,
  joinCustomerToBrandCommunities,
  canModerateCommunityGroup,
  canTransitionSubscription,
  getSubscriptionOwnerUserId,
  syncCashierProfilesForMerchantSubscription,
  applySubscriptionTransition,
  assertMerchantSubscriptionWritable,
  isMerchantSubscriptionReadOnlyError,
  ensurePrivateChatBetweenUsers,
};
