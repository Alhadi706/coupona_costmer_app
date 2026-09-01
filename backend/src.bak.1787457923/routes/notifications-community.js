const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerNotificationsCommunityRoutes(app, deps) {
  const {
    pool, CANONICAL_ROLES,
    PORT, JWT_SECRET, POS_GRANT_TOKEN_SECRET, POS_GRANT_TOKEN_TTL_SECONDS, FCM_SERVER_KEY,
    PAYMENT_WEBHOOK_SECRET, GEMINI_API_KEY, GEMINI_MODEL, ACCESS_TOKEN_TTL, KUPUNA_OWNER_EMAIL,
    OWNER_ENFORCEMENT_ENABLED, DEV_OWNER_BYPASS, SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD,
    EMAIL_FROM, OWNER_MFA_CODE_TTL_MS, OWNER_MFA_MAX_ATTEMPTS, DEV_OWNER_CHALLENGE_TTL_MS,
    devOwnerChallenges, GEMINI_FALLBACK_MODELS, AI_ONLY_MODE, UPLOAD_DIR, INVOICES_UPLOAD_DIR,
    CORS_ALLOWED_ORIGINS, AUTH_RATE_LIMIT_WINDOW_MS, LOGIN_RATE_LIMIT_MAX, SIGNUP_RATE_LIMIT_MAX,
    UPLOAD_RATE_LIMIT_WINDOW_MS, UPLOAD_RATE_LIMIT_MAX, requiredEnv, parseList, corsGuard,
    createRateLimiter, loginRateLimit, signupRateLimit, uploadRateLimit, ownerLoginRateLimit,
    ownerVerifyRateLimit, ownerResendRateLimit,
    id, normalizeRole, signAccessToken, isSystemOwner, smtpConfigured, ownerMailer,
    sendOwnerMfaCode, hashOwnerCode, ownerCode, isAdmin, isLoopbackRequest, canAccessUserObject,
    detectImageMime, toIso, normalizeMerchantKey, canonicalMerchantName, normalizeForFingerprint,
    buildInvoiceFingerprint, parseFlexibleDate, haversineDistanceKm, calculateAgeYears,
    parseTargetingCriteria, extractJsonObject, normalizeAiInvoiceFields, analyzeInvoiceWithGemini,
    auth, requireAdmin, ensureCustomerProfile, getIntSetting, canManageInvoice, canRedeemClaim,
    runSubscriptionTransitions, hasBlockRelation, isPrivateChatParticipant, getPeerUserId,
    sendFcmToTokens, getActivePushTokens, insertNotification, ensureCommunityGroupForRole,
    ensureCommunityMembership, joinCustomerToMerchantCommunity, joinCustomerToBrandCommunities,
    canModerateCommunityGroup, canTransitionSubscription, getSubscriptionOwnerUserId,
    syncCashierProfilesForMerchantSubscription, applySubscriptionTransition,
    assertMerchantSubscriptionWritable, isMerchantSubscriptionReadOnlyError,
    ensurePrivateChatBetweenUsers, applyInvoiceApprovalRewards, offerMatchesTargeting,
    calculatePointsWithFraction, getMerchantProfileIdByUser, getBrandProfileIdByUser,
    normalizeRoleType, resolveMerchantProfileIdByKey, autoMatchLineItemToBrand,
    matchesPeerAdCategory, parseGeoJson, matchesPeerAdGeo, mapRewardRow, validateRewardSource,
    analyticsRangeDays, analyticsDaysAgo, analyticsSafeNumber, analyticsPercentChange,
    analyticsAgeBucket, analyticsCountEntries, analyticsTopEntries,
  } = deps;

app.post('/api/notifications/push-token/register', auth, async (req, res) => {
  const token = String((req.body || {}).token || '').trim();
  const platform = String((req.body || {}).platform || '').trim() || null;
  if (!token) return res.status(400).json({ error: 'token_required' });

  await pool.query(
    `INSERT INTO user_push_tokens (id, user_id, token, platform, is_active, updated_at)
     VALUES ($1, $2, $3, $4, TRUE, NOW())
     ON CONFLICT (token)
     DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, is_active = TRUE, updated_at = NOW()`,
    [id(), req.user.userId, token, platform]
  );
  return res.json({ ok: true });
});

app.post('/api/notifications/push-token/unregister', auth, async (req, res) => {
  const token = String((req.body || {}).token || '').trim();
  if (!token) return res.status(400).json({ error: 'token_required' });
  await pool.query(
    `UPDATE user_push_tokens
        SET is_active = FALSE,
            updated_at = NOW()
      WHERE user_id = $1
        AND token = $2`,
    [req.user.userId, token]
  );
  return res.json({ ok: true });
});

app.post('/api/notifications/push-test', auth, async (req, res) => {
  const title = String((req.body || {}).title || 'Kupuna push test').trim();
  const body = String((req.body || {}).body || 'Push channel is active.').trim();
  const tokens = await getActivePushTokens(pool, req.user.userId);
  const result = await sendFcmToTokens(tokens, title, body, { source: 'push_test' });
  return res.json({ ok: true, tokenCount: tokens.length, fcm: result });
});

app.get('/api/notifications/my', auth, async (req, res) => {
  const rows = (await pool.query(
    `SELECT id, type, title, body, target_screen, payload, is_read, read_at, created_at
       FROM notifications
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT 200`,
    [req.user.userId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    targetScreen: row.target_screen,
    payload: row.payload || {},
    isRead: Boolean(row.is_read),
    readAt: toIso(row.read_at),
    createdAt: toIso(row.created_at),
  })));
});

app.get('/api/notifications/badge', auth, async (req, res) => {
  const row = (await pool.query(
    `SELECT
        COUNT(*) FILTER (WHERE is_read = FALSE)::int AS unread_total,
        COUNT(*) FILTER (WHERE is_read = FALSE AND type = 'group_message')::int AS unread_group_messages,
        COUNT(*) FILTER (WHERE is_read = FALSE AND type <> 'group_message')::int AS unread_non_group
       FROM notifications
      WHERE user_id = $1`,
    [req.user.userId]
  )).rows[0] || {};

  const unreadTotal = Number(row.unread_total || 0);
  const unreadGroupMessages = Number(row.unread_group_messages || 0);
  const unreadNonGroup = Number(row.unread_non_group || 0);

  return res.json({
    unreadTotal,
    unreadGroupMessages,
    unreadNonGroup,
    hasRedDot: unreadTotal > 0,
  });
});

app.post('/api/notifications/:id/read', auth, async (req, res) => {
  await pool.query(
    `UPDATE notifications
        SET is_read = TRUE,
            read_at = NOW()
      WHERE id = $1
        AND user_id = $2`,
    [req.params.id, req.user.userId]
  );
  return res.json({ ok: true });
});

app.get('/api/community/groups/my', auth, async (req, res) => {
  const eligibleMerchantGroups = (await pool.query(
    `SELECT DISTINCT cg.id
       FROM community_groups cg
       JOIN invoice_scans i ON i.merchant_profile_id = cg.role_profile_id
      WHERE cg.role_type = 'merchant'
        AND i.owner_id = $1
        AND i.state = 'approved'`,
    [req.user.userId]
  )).rows;
  for (const row of eligibleMerchantGroups) {
    const banned = (await pool.query(
      'SELECT 1 FROM community_group_bans WHERE group_id = $1 AND user_id = $2 LIMIT 1',
      [row.id, req.user.userId]
    )).rows[0];
    if (!banned) {
      await ensureCommunityMembership(pool, row.id, req.user.userId);
    }
  }
  const rows = (await pool.query(
    `SELECT cg.id, cg.role_type, cg.role_profile_id, cg.name, cg.owner_user_id,
            (SELECT COUNT(*)::int FROM community_group_members m WHERE m.group_id = cg.id) AS members_count,
            (
              SELECT COUNT(*)::int
                FROM notifications n
               WHERE n.user_id = $1
                 AND n.type = 'group_message'
                 AND n.is_read = FALSE
                 AND (n.payload->>'groupId') = cg.id
            ) AS unread_count
       FROM community_group_members m
       JOIN community_groups cg ON cg.id = m.group_id
      WHERE m.user_id = $1
      ORDER BY cg.created_at DESC`,
    [req.user.userId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    roleType: row.role_type,
    roleProfileId: row.role_profile_id,
    name: row.name,
    ownerUserId: row.owner_user_id,
    membersCount: Number(row.members_count || 0),
    unreadCount: Number(row.unread_count || 0),
  })));
});

app.get('/api/community/badge', auth, async (req, res) => {
  const row = (await pool.query(
    `SELECT COUNT(*)::int AS unread_count
       FROM notifications
      WHERE user_id = $1
        AND type = 'group_message'
        AND is_read = FALSE`,
    [req.user.userId]
  )).rows[0] || { unread_count: 0 };

  return res.json({
    unreadCount: Number(row.unread_count || 0),
  });
});

app.get('/api/community/groups/:id/messages', auth, async (req, res) => {
  const groupId = req.params.id;
  const member = (await pool.query(
    'SELECT 1 FROM community_group_members WHERE group_id = $1 AND user_id = $2 LIMIT 1',
    [groupId, req.user.userId]
  )).rows[0];
  if (!member) return res.status(403).json({ error: 'group_membership_required' });

  await pool.query(
    `UPDATE notifications
        SET is_read = TRUE,
            read_at = NOW()
      WHERE user_id = $1
        AND type = 'group_message'
        AND is_read = FALSE
        AND (payload->>'groupId') = $2`,
    [req.user.userId, groupId]
  );

  const rows = (await pool.query(
    `SELECT id, sender_id, sender_name, text, image_url, message_type, poll_json, is_pinned, is_deleted, created_at, updated_at
       FROM community_messages
      WHERE group_id = $1
      ORDER BY is_pinned DESC, created_at ASC`,
    [groupId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    senderId: row.sender_id,
    senderName: row.sender_name,
    text: row.is_deleted ? '[deleted]' : row.text,
    imageUrl: row.image_url,
    messageType: row.message_type || 'post',
    poll: row.poll_json || null,
    isPinned: Boolean(row.is_pinned),
    isDeleted: Boolean(row.is_deleted),
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  })));
});

app.get('/api/community/groups/:id/members', auth, async (req, res) => {
  const member = (await pool.query(
    'SELECT 1 FROM community_group_members WHERE group_id = $1 AND user_id = $2 LIMIT 1',
    [req.params.id, req.user.userId]
  )).rows[0];
  if (!member) return res.status(403).json({ error: 'group_membership_required' });
  const rows = (await pool.query(
    `SELECT m.user_id, u.email, m.joined_at,
            EXISTS (SELECT 1 FROM community_group_bans b WHERE b.group_id = m.group_id AND b.user_id = m.user_id) AS is_banned
       FROM community_group_members m
       JOIN users u ON u.id = m.user_id
      WHERE m.group_id = $1
      ORDER BY m.joined_at ASC`,
    [req.params.id]
  )).rows;
  return res.json(rows.map((row) => ({ userId: row.user_id, label: row.email, joinedAt: toIso(row.joined_at), isBanned: Boolean(row.is_banned) })));
});

app.post('/api/community/groups/:id/messages', auth, async (req, res) => {
  const groupId = req.params.id;
  const text = String((req.body || {}).text || '').trim();
  const imageUrl = String((req.body || {}).imageUrl || '').trim() || null;
  const messageType = (req.body || {}).poll && typeof (req.body || {}).poll === 'object' ? 'poll' : 'post';
  const poll = messageType === 'poll' ? (req.body || {}).poll : null;
  if (!text && !imageUrl && !poll) return res.status(400).json({ error: 'message_content_required' });

  const member = (await pool.query(
    'SELECT 1 FROM community_group_members WHERE group_id = $1 AND user_id = $2 LIMIT 1',
    [groupId, req.user.userId]
  )).rows[0];
  if (!member) return res.status(403).json({ error: 'group_membership_required' });

  const banned = (await pool.query(
    'SELECT 1 FROM community_group_bans WHERE group_id = $1 AND user_id = $2 LIMIT 1',
    [groupId, req.user.userId]
  )).rows[0];
  if (banned) return res.status(403).json({ error: 'user_banned' });

  const user = (await pool.query('SELECT email FROM users WHERE id = $1 LIMIT 1', [req.user.userId])).rows[0];
  const messageId = id();
  await pool.query(
    `INSERT INTO community_messages (id, group_id, sender_id, sender_name, text, image_url, message_type, poll_json)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
    [messageId, groupId, req.user.userId, user?.email || 'User', text, imageUrl, messageType, poll ? JSON.stringify(poll) : null]
  );

  const recipients = (await pool.query(
    `SELECT user_id
       FROM community_group_members
      WHERE group_id = $1
        AND user_id <> $2`,
    [groupId, req.user.userId]
  )).rows;
  for (const row of recipients) {
    await insertNotification(
      pool,
      row.user_id,
      'group_message',
      'New community message',
      'A new message was posted in one of your communities.',
      { groupId, messageId, targetScreen: 'community_group' }
    );
  }

  return res.json({ ok: true, id: messageId });
});

app.post('/api/community/groups/:id/messages/:messageId/pin', auth, async (req, res) => {
  const groupId = req.params.id;
  const canModerate = await canModerateCommunityGroup(pool, groupId, req.user.userId);
  if (!canModerate) return res.status(403).json({ error: 'moderator_required' });
  await pool.query(
    `UPDATE community_messages
        SET is_pinned = TRUE,
            updated_at = NOW()
      WHERE id = $1
        AND group_id = $2`,
    [req.params.messageId, groupId]
  );
  return res.json({ ok: true });
});

app.post('/api/community/groups/:id/broadcast', auth, async (req, res) => {
  const groupId = req.params.id;
  if (!(await canModerateCommunityGroup(pool, groupId, req.user.userId))) {
    return res.status(403).json({ error: 'moderator_required' });
  }
  const text = String((req.body || {}).text || '').trim();
  if (!text) return res.status(400).json({ error: 'text_required' });
  const recipients = (await pool.query(
    'SELECT user_id FROM community_group_members WHERE group_id = $1 AND user_id <> $2',
    [groupId, req.user.userId]
  )).rows;
  for (const row of recipients) {
    await insertNotification(pool, row.user_id, 'merchant_broadcast', 'Community update', text, { groupId, targetScreen: 'community_group' });
  }
  return res.json({ ok: true, recipientCount: recipients.length });
});

app.post('/api/community/groups/:id/messages/:messageId/poll-vote', auth, async (req, res) => {
  const member = (await pool.query(
    'SELECT 1 FROM community_group_members WHERE group_id = $1 AND user_id = $2 LIMIT 1',
    [req.params.id, req.user.userId]
  )).rows[0];
  if (!member) return res.status(403).json({ error: 'group_membership_required' });
  const option = String((req.body || {}).option || '').trim();
  const row = (await pool.query(
    'SELECT poll_json FROM community_messages WHERE id = $1 AND group_id = $2 AND message_type = \'poll\' LIMIT 1',
    [req.params.messageId, req.params.id]
  )).rows[0];
  if (!row || !option) return res.status(404).json({ error: 'poll_not_found' });
  const poll = row.poll_json || {};
  const options = Array.isArray(poll.options) ? poll.options : [];
  if (!options.includes(option)) return res.status(400).json({ error: 'poll_option_invalid' });
  const votes = poll.votes && typeof poll.votes === 'object' ? poll.votes : {};
  votes[option] = Number(votes[option] || 0) + 1;
  await pool.query('UPDATE community_messages SET poll_json = $1::jsonb, updated_at = NOW() WHERE id = $2', [JSON.stringify({ ...poll, votes }), req.params.messageId]);
  return res.json({ ok: true, votes });
});

app.delete('/api/community/groups/:id/messages/:messageId', auth, async (req, res) => {
  const groupId = req.params.id;
  const canModerate = await canModerateCommunityGroup(pool, groupId, req.user.userId);
  if (!canModerate) return res.status(403).json({ error: 'moderator_required' });
  await pool.query(
    `UPDATE community_messages
        SET is_deleted = TRUE,
            updated_at = NOW()
      WHERE id = $1
        AND group_id = $2`,
    [req.params.messageId, groupId]
  );
  return res.json({ ok: true });
});

app.post('/api/community/groups/:id/members/:userId/ban', auth, async (req, res) => {
  const groupId = req.params.id;
  const targetUserId = req.params.userId;
  const canModerate = await canModerateCommunityGroup(pool, groupId, req.user.userId);
  if (!canModerate) return res.status(403).json({ error: 'moderator_required' });
  const reason = String((req.body || {}).reason || '').trim() || null;
  await pool.query(
    `INSERT INTO community_group_bans (group_id, user_id, banned_by, reason)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (group_id, user_id)
     DO UPDATE SET banned_by = EXCLUDED.banned_by, reason = EXCLUDED.reason, created_at = NOW()`,
    [groupId, targetUserId, req.user.userId, reason]
  );
  await pool.query('DELETE FROM community_group_members WHERE group_id = $1 AND user_id = $2', [groupId, targetUserId]);
  return res.json({ ok: true });
});

};
