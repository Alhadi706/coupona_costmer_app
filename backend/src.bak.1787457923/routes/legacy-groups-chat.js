const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerLegacyGroupsChatRoutes(app, deps) {
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

app.get('/api/stores', auth, async (_req, res) => {
  const q = _req.query || {};
  const categoryFilter = String(q.category || '').trim().toLowerCase();
  const userLat = Number(q.lat);
  const userLng = Number(q.lng);
  const hasUserLocation = Number.isFinite(userLat) && Number.isFinite(userLng);

  const [seedRows, branchRows] = await Promise.all([
    pool.query('SELECT * FROM stores'),
    pool.query(
      `SELECT b.id,
              b.name AS branch_name,
              b.address,
              b.location,
              b.latitude,
              b.longitude,
              b.category,
              b.status,
              m.id AS merchant_id,
              m.business_name,
              m.phone,
              m.commercial_registration,
              m.status AS merchant_status
         FROM branches b
         JOIN merchant_profiles m ON m.id = b.merchant_id
        WHERE b.status = 'active'
          AND m.status = 'active'`
    ),
  ]);

  const normalizedSeed = seedRows.rows.map((s) => ({
    id: s.id,
    source: 'seed_store',
    name: s.name,
    branchName: null,
    merchantId: null,
    branchId: null,
    category: s.category,
    description: s.description,
    phone: s.phone,
    location: s.location,
    lat: s.lat == null ? null : Number(s.lat),
    lng: s.lng == null ? null : Number(s.lng),
  }));

  const normalizedBranches = branchRows.rows.map((b) => ({
    id: `merchant-${b.merchant_id}-branch-${b.id}`,
    source: 'merchant_branch',
    name: b.business_name,
    branchName: b.branch_name,
    merchantId: b.merchant_id,
    branchId: b.id,
    category: b.category || 'general',
    description: b.commercial_registration || null,
    phone: b.phone || null,
    location: b.location || b.address || null,
    lat: b.latitude == null ? null : Number(b.latitude),
    lng: b.longitude == null ? null : Number(b.longitude),
  }));

  let stores = [...normalizedSeed, ...normalizedBranches];
  if (categoryFilter) {
    stores = stores.filter((s) => String(s.category || '').toLowerCase() === categoryFilter);
  }

  stores = stores.map((s) => {
    if (!hasUserLocation || !Number.isFinite(s.lat) || !Number.isFinite(s.lng)) {
      return { ...s, distanceKm: null };
    }
    return {
      ...s,
      distanceKm: Number(haversineDistanceKm(userLat, userLng, Number(s.lat), Number(s.lng)).toFixed(3)),
    };
  });

  if (hasUserLocation) {
    stores.sort((a, b) => {
      const da = a.distanceKm == null ? Number.POSITIVE_INFINITY : a.distanceKm;
      const db = b.distanceKm == null ? Number.POSITIVE_INFINITY : b.distanceKm;
      if (da !== db) return da - db;
      return String(a.name || '').localeCompare(String(b.name || ''), 'ar');
    });
  } else {
    stores.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'ar'));
  }

  res.json(stores);
});

app.get('/api/groups', auth, async (_req, res) => {
  const rows = (await pool.query('SELECT * FROM groups ORDER BY name ASC')).rows;
  res.json(rows.map((g) => ({ id: g.id, name: g.name, desc: g.description, members: g.members })));
});

app.post('/api/groups', auth, async (req, res) => {
  const name = String((req.body || {}).name || '').trim();
  const description = String((req.body || {}).description || '').trim();
  if (!name) {
    return res.status(400).json({ error: 'name_required' });
  }
  const groupId = id();
  await pool.query(
    'INSERT INTO groups (id, name, description, members) VALUES ($1, $2, $3, $4)',
    [groupId, name, description || null, 1]
  );
  res.json({
    ok: true,
    id: groupId,
    name,
    desc: description,
    members: 1,
  });
});

app.get('/api/groups/:id/messages', auth, async (req, res) => {
  const rows = (await pool.query(
    `SELECT gm.*,
            COALESCE((SELECT COUNT(*)::int FROM group_message_replies r WHERE r.message_id = gm.id), 0) AS replies_count,
            COALESCE((SELECT COUNT(*)::int FROM group_message_reactions gr WHERE gr.message_id = gm.id), 0) AS reactions_count,
            COALESCE((SELECT COUNT(*)::int FROM group_message_reactions gr WHERE gr.message_id = gm.id AND gr.emoji = '👍'), 0) AS thumbs_up_count,
            COALESCE((SELECT COUNT(*)::int FROM group_message_reactions gr WHERE gr.message_id = gm.id AND gr.emoji = '❤️'), 0) AS heart_count,
            COALESCE((SELECT gr.emoji FROM group_message_reactions gr WHERE gr.message_id = gm.id AND gr.user_id = $2 LIMIT 1), '') AS my_reaction
       FROM group_messages gm
      WHERE gm.group_id = $1
      ORDER BY gm.created_at ASC`,
    [req.params.id, req.user.userId]
  )).rows;
  res.json(rows.map((m) => ({
    id: m.id,
    senderId: m.sender_id,
    senderName: m.sender_name,
    text: m.text,
    createdAt: toIso(m.created_at),
    repliesCount: Number(m.replies_count || 0),
    reactionsCount: Number(m.reactions_count || 0),
    thumbsUpCount: Number(m.thumbs_up_count || 0),
    heartCount: Number(m.heart_count || 0),
    myReaction: m.my_reaction || '',
  })));
});

app.post('/api/groups/:id/messages', auth, async (req, res) => {
  const text = String((req.body || {}).text || '').trim();
  if (!text) return res.status(400).json({ error: 'text_required' });
  const user = (await pool.query('SELECT id, email FROM users WHERE id = $1', [req.user.userId])).rows[0];
  await pool.query(
    'INSERT INTO group_messages (id, group_id, sender_id, sender_name, text) VALUES ($1,$2,$3,$4,$5)',
    [id(), req.params.id, req.user.userId, (user && user.email) || 'مستخدم', text]
  );
  res.json({ ok: true });
});

app.post('/api/groups/:id/messages/:messageId/replies', auth, async (req, res) => {
  const text = String((req.body || {}).text || '').trim();
  if (!text) return res.status(400).json({ error: 'text_required' });
  const user = (await pool.query('SELECT id, email FROM users WHERE id = $1', [req.user.userId])).rows[0];
  const exists = (await pool.query('SELECT 1 FROM group_messages WHERE id = $1 AND group_id = $2 LIMIT 1', [req.params.messageId, req.params.id])).rows[0];
  if (!exists) return res.status(404).json({ error: 'message_not_found' });
  await pool.query(
    'INSERT INTO group_message_replies (id, group_id, message_id, sender_id, sender_name, text) VALUES ($1,$2,$3,$4,$5,$6)',
    [id(), req.params.id, req.params.messageId, req.user.userId, (user && user.email) || 'مستخدم', text]
  );
  res.json({ ok: true });
});

app.get('/api/groups/:id/messages/:messageId/replies', auth, async (req, res) => {
  const exists = (await pool.query('SELECT 1 FROM group_messages WHERE id = $1 AND group_id = $2 LIMIT 1', [req.params.messageId, req.params.id])).rows[0];
  if (!exists) return res.status(404).json({ error: 'message_not_found' });
  const rows = (await pool.query(
    `SELECT id, sender_id, sender_name, text, created_at
       FROM group_message_replies
      WHERE group_id = $1 AND message_id = $2
      ORDER BY created_at ASC`,
    [req.params.id, req.params.messageId]
  )).rows;
  res.json(rows.map((row) => ({
    id: row.id,
    senderId: row.sender_id,
    senderName: row.sender_name,
    text: row.text,
    createdAt: toIso(row.created_at),
  })));
});

app.post('/api/groups/:id/messages/:messageId/reactions', auth, async (req, res) => {
  const emoji = String((req.body || {}).emoji || '').trim();
  if (!emoji) return res.status(400).json({ error: 'emoji_required' });
  const exists = (await pool.query('SELECT 1 FROM group_messages WHERE id = $1 AND group_id = $2 LIMIT 1', [req.params.messageId, req.params.id])).rows[0];
  if (!exists) return res.status(404).json({ error: 'message_not_found' });
  await pool.query(
    `INSERT INTO group_message_reactions (message_id, user_id, emoji, created_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (message_id, user_id, emoji)
     DO NOTHING`,
    [req.params.messageId, req.user.userId, emoji]
  );
  res.json({ ok: true });
});

app.get('/api/private-chats', auth, async (req, res) => {
  const userId = req.user.userId;
  const rows = (await pool.query(
    `SELECT c.*, p2.user_id AS peer_user_id, u.email AS peer_email,
            EXISTS(
              SELECT 1
                FROM user_blocks ub
               WHERE ub.blocker_id = $1 AND ub.blocked_id = p2.user_id
            ) AS blocked_by_me,
            COALESCE(s.is_muted, FALSE) AS is_muted,
            COALESCE(s.is_pinned, FALSE) AS is_pinned,
            COALESCE(
              (
                SELECT COUNT(*)::int
                  FROM private_messages pm
                 WHERE pm.chat_id = c.id
                   AND pm.sender_id <> $1
                   AND (
                     s.last_read_at IS NULL
                     OR pm.created_at > s.last_read_at
                   )
              ),
              0
            ) AS unread_count
       FROM private_chats c
       JOIN private_chat_participants p1 ON p1.chat_id = c.id AND p1.user_id = $1
       JOIN private_chat_participants p2 ON p2.chat_id = c.id AND p2.user_id <> $1
       LEFT JOIN users u ON u.id = p2.user_id
       LEFT JOIN private_chat_user_state s ON s.user_id = $1 AND s.chat_id = c.id
      WHERE COALESCE(s.is_hidden, FALSE) = FALSE
        AND COALESCE(s.is_deleted, FALSE) = FALSE
      ORDER BY COALESCE(s.is_pinned, FALSE) DESC, c.updated_at DESC`,
    [userId]
  )).rows;
  res.json(rows.map((c) => ({
    id: c.id,
    title: c.title || 'محادثة خاصة',
    lastMessage: c.last_message || '',
    updatedAt: toIso(c.updated_at),
    peerUserId: c.peer_user_id,
    peerEmail: c.peer_email,
    blockedByMe: Boolean(c.blocked_by_me),
    isMuted: Boolean(c.is_muted),
    isPinned: Boolean(c.is_pinned),
    unreadCount: Number(c.unread_count || 0),
  })));
});

app.post('/api/private-chats', auth, async (req, res) => {
  const targetUserId = String((req.body || {}).targetUserId || '').trim();
  const title = String((req.body || {}).title || '').trim() || 'محادثة خاصة';
  if (!targetUserId) {
    return res.status(400).json({ error: 'targetUserId_required' });
  }
  if (targetUserId === req.user.userId) {
    return res.status(400).json({ error: 'self_chat_not_supported' });
  }
  if (await hasBlockRelation(req.user.userId, targetUserId)) {
    return res.status(403).json({ error: 'blocked_relationship' });
  }

  const participants = [req.user.userId, targetUserId].sort();
  const existing = (await pool.query(
    `SELECT c.id, c.title, c.last_message, c.updated_at
       FROM private_chats c
       JOIN private_chat_participants p1 ON p1.chat_id = c.id AND p1.user_id = $1
       JOIN private_chat_participants p2 ON p2.chat_id = c.id AND p2.user_id = $2
      LIMIT 1`,
    [participants[0], participants[1]]
  )).rows[0];

  if (existing) {
    await pool.query(
      `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
       VALUES ($1, $2, FALSE, FALSE, NOW())
       ON CONFLICT (user_id, chat_id)
       DO UPDATE SET is_hidden = FALSE, is_deleted = FALSE, updated_at = NOW()`,
      [req.user.userId, existing.id]
    );
    return res.json({
      ok: true,
      id: existing.id,
      title: existing.title || title,
      lastMessage: existing.last_message || '',
      updatedAt: toIso(existing.updated_at),
    });
  }

  const chatId = id();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'INSERT INTO private_chats (id, title, last_message, updated_at) VALUES ($1, $2, $3, NOW())',
      [chatId, title, '']
    );
    await client.query(
      'INSERT INTO private_chat_participants (chat_id, user_id) VALUES ($1, $2), ($1, $3)',
      [chatId, req.user.userId, targetUserId]
    );
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'create_chat_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }

  res.json({ ok: true, id: chatId, title, lastMessage: '', updatedAt: new Date().toISOString() });
});

app.get('/api/private-chats/:id/messages', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  const rows = (await pool.query('SELECT * FROM private_messages WHERE chat_id = $1 ORDER BY created_at ASC', [chatId])).rows;
  res.json(rows.map((m) => ({ id: m.id, senderId: m.sender_id, senderName: m.sender_name, text: m.text, createdAt: toIso(m.created_at) })));
});

app.post('/api/private-chats/:id/messages', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  const peerUserId = await getPeerUserId(chatId, req.user.userId);
  if (!peerUserId) {
    return res.status(400).json({ error: 'invalid_chat_participants' });
  }
  if (await hasBlockRelation(req.user.userId, peerUserId)) {
    return res.status(403).json({ error: 'blocked_relationship' });
  }

  const text = String((req.body || {}).text || '').trim();
  if (!text) return res.status(400).json({ error: 'text_required' });
  const user = (await pool.query('SELECT id, email FROM users WHERE id = $1', [req.user.userId])).rows[0];
  await pool.query('INSERT INTO private_messages (id, chat_id, sender_id, sender_name, text) VALUES ($1,$2,$3,$4,$5)', [id(), chatId, req.user.userId, (user && user.email) || 'مستخدم', text]);
  await pool.query('UPDATE private_chats SET last_message = $1, updated_at = NOW() WHERE id = $2', [text, chatId]);
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
     VALUES ($1, $3, FALSE, FALSE, NOW()), ($2, $3, FALSE, FALSE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_hidden = FALSE, is_deleted = FALSE, updated_at = NOW()`,
    [req.user.userId, peerUserId, chatId]
  );
  await pool.query(
    `UPDATE private_chat_user_state
        SET last_read_at = NOW()
      WHERE user_id = $1 AND chat_id = $2`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/hide', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
     VALUES ($1, $2, TRUE, FALSE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_hidden = TRUE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/unhide', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
     VALUES ($1, $2, FALSE, FALSE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_hidden = FALSE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/delete', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
     VALUES ($1, $2, TRUE, TRUE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_hidden = TRUE, is_deleted = TRUE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/restore', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
     VALUES ($1, $2, FALSE, FALSE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_hidden = FALSE, is_deleted = FALSE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/mute', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, is_muted, updated_at)
     VALUES ($1, $2, FALSE, FALSE, TRUE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_muted = TRUE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/unmute', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, is_muted, updated_at)
     VALUES ($1, $2, FALSE, FALSE, FALSE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_muted = FALSE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/pin', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, is_pinned, updated_at)
     VALUES ($1, $2, FALSE, FALSE, TRUE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_pinned = TRUE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/unpin', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, is_pinned, updated_at)
     VALUES ($1, $2, FALSE, FALSE, FALSE, NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET is_pinned = FALSE, updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

app.post('/api/private-chats/:id/read', auth, async (req, res) => {
  const chatId = req.params.id;
  if (!(await isPrivateChatParticipant(chatId, req.user.userId))) {
    return res.status(404).json({ error: 'chat_not_found' });
  }
  await pool.query(
    `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, last_read_at, updated_at)
     VALUES ($1, $2, FALSE, FALSE, NOW(), NOW())
     ON CONFLICT (user_id, chat_id)
     DO UPDATE SET last_read_at = NOW(), updated_at = NOW()`,
    [req.user.userId, chatId]
  );
  res.json({ ok: true });
});

};
