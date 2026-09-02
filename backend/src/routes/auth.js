const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerAuthRoutes(app, deps) {
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

app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.post('/api/auth/signup', signupRateLimit, async (req, res) => {
  const { email, password, fullName, gender, birthDate, locationLat, locationLng, phone } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password required' });
  }
  const normalizedPhone = String(phone || '').trim() || null;
  const normalizedGender = String(gender || '').trim().toLowerCase();
  const genderValue = normalizedGender || null;
  const parsedBirthDate = birthDate ? new Date(String(birthDate)) : null;
  const safeBirthDate = parsedBirthDate && !Number.isNaN(parsedBirthDate.getTime())
    ? parsedBirthDate.toISOString().slice(0, 10)
    : null;
  const lat = Number(locationLat);
  const lng = Number(locationLng);
  const safeLat = Number.isFinite(lat) ? lat : null;
  const safeLng = Number.isFinite(lng) ? lng : null;
  const hash = await bcrypt.hash(password, 10);
  const userId = id();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'INSERT INTO users (id, email, password_hash, role, phone, full_name, gender, birth_date, profile_completed) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)',
      [
        userId,
        String(email).toLowerCase(),
        hash,
        'customer',
        normalizedPhone,
        fullName ? String(fullName).trim() : null,
        genderValue,
        safeBirthDate,
        Boolean(fullName && genderValue && safeBirthDate),
      ]
    );
    await ensureCustomerProfile(client, userId);
    if (safeLat != null && safeLng != null) {
      await client.query(
        `UPDATE customer_profiles
            SET location_lat = $2,
                location_lng = $3
          WHERE user_id = $1`,
        [userId, safeLat, safeLng]
      );
    }
    await client.query('COMMIT');
    return res.json({
      userId,
      email: String(email).toLowerCase(),
        role: 'customer',
      phone: normalizedPhone,
      fullName: fullName ? String(fullName).trim() : null,
      gender: genderValue,
      birthDate: safeBirthDate,
      locationLat: safeLat,
      locationLng: safeLng,
    });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(409).json({ error: 'signup_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/auth/owner/login', ownerLoginRateLimit, async (req, res) => {
  const email = String((req.body || {}).email || '').trim().toLowerCase();
  const password = String((req.body || {}).password || '');
  if (!KUPUNA_OWNER_EMAIL || email !== KUPUNA_OWNER_EMAIL || !password) {
    return res.status(401).json({ error: 'invalid_owner_credentials' });
  }

  const user = (await pool.query(
    `SELECT id, email, role, password_hash, token_version, is_system_owner, mfa_enabled, email_verified
       FROM users
      WHERE email = $1 AND role = 'admin' AND is_system_owner = TRUE
      LIMIT 1`,
    [KUPUNA_OWNER_EMAIL]
  )).rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'invalid_owner_credentials' });
  }

  if (DEV_OWNER_BYPASS && isLoopbackRequest(req)) {
    const challengeId = id();
    devOwnerChallenges.set(challengeId, {
      ownerUserId: user.id,
      expiresAt: Date.now() + DEV_OWNER_CHALLENGE_TTL_MS,
    });
    return res.json({
      challengeId,
      expiresInSeconds: Math.floor(DEV_OWNER_CHALLENGE_TTL_MS / 1000),
      devBypass: true,
    });
  }

  if (!user.mfa_enabled || !user.email_verified || !smtpConfigured()) {
    return res.status(503).json({ error: 'owner_mfa_not_configured' });
  }

  const challengeId = id();
  const code = ownerCode();
  await pool.query(
    'INSERT INTO owner_mfa_challenges (id, owner_user_id, code_hash, expires_at) VALUES ($1, $2, $3, $4)',
    [challengeId, user.id, hashOwnerCode(code), new Date(Date.now() + OWNER_MFA_CODE_TTL_MS)]
  );
  try {
    await sendOwnerMfaCode(code);
  } catch (_e) {
    await pool.query('DELETE FROM owner_mfa_challenges WHERE id = $1', [challengeId]);
    return res.status(503).json({ error: 'owner_mfa_delivery_failed' });
  }
  return res.json({ challengeId, expiresInSeconds: Math.floor(OWNER_MFA_CODE_TTL_MS / 1000) });
});

app.post('/api/auth/owner/resend', ownerResendRateLimit, async (req, res) => {
  const challengeId = String((req.body || {}).challengeId || '').trim();
  if (!challengeId || !KUPUNA_OWNER_EMAIL) return res.status(401).json({ error: 'invalid_owner_challenge' });
  const row = (await pool.query(
    `SELECT c.id, u.id AS owner_user_id, u.email
       FROM owner_mfa_challenges c
       JOIN users u ON u.id = c.owner_user_id
      WHERE c.id = $1 AND u.email = $2 AND u.is_system_owner = TRUE AND c.used_at IS NULL
      LIMIT 1`,
    [challengeId, KUPUNA_OWNER_EMAIL]
  )).rows[0];
  if (!row) return res.status(401).json({ error: 'invalid_owner_challenge' });
  const code = ownerCode();
  await pool.query(
    'UPDATE owner_mfa_challenges SET code_hash = $1, attempts = 0, expires_at = $2 WHERE id = $3',
    [hashOwnerCode(code), new Date(Date.now() + OWNER_MFA_CODE_TTL_MS), challengeId]
  );
  try {
    await sendOwnerMfaCode(code);
  } catch (_e) {
    return res.status(503).json({ error: 'owner_mfa_delivery_failed' });
  }
  return res.json({ challengeId, expiresInSeconds: Math.floor(OWNER_MFA_CODE_TTL_MS / 1000) });
});

app.post('/api/auth/owner/verify', ownerVerifyRateLimit, async (req, res) => {
  const challengeId = String((req.body || {}).challengeId || '').trim();
  const code = String((req.body || {}).code || '').trim();
  const devChallenge = devOwnerChallenges.get(challengeId);
  if (DEV_OWNER_BYPASS && isLoopbackRequest(req) && devChallenge) {
    devOwnerChallenges.delete(challengeId);
    if (devChallenge.expiresAt <= Date.now()) {
      return res.status(401).json({ error: 'invalid_owner_challenge' });
    }
    const row = (await pool.query(
      `SELECT id, email, role, token_version, is_system_owner, mfa_enabled, email_verified
         FROM users
        WHERE id = $1 AND email = $2 AND role = 'admin' AND is_system_owner = TRUE
        LIMIT 1`,
      [devChallenge.ownerUserId, KUPUNA_OWNER_EMAIL]
    )).rows[0];
    if (!row) return res.status(401).json({ error: 'invalid_owner_challenge' });
    const token = signAccessToken({
      id: row.id,
      email: row.email,
      role: row.role,
      token_version: row.token_version,
      ownerMfaVerified: true,
    });
    return res.json({ token, userId: row.id, role: 'admin', mfaVerified: true, devBypass: true });
  }
  if (!challengeId || !/^\d{6}$/.test(code)) return res.status(401).json({ error: 'invalid_owner_challenge' });
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(challengeId)) {
    return res.status(401).json({ error: 'invalid_owner_challenge' });
  }
  const row = (await pool.query(
    `SELECT c.id, c.code_hash, c.attempts, c.expires_at, c.used_at,
            u.id, u.email, u.role, u.token_version, u.is_system_owner, u.mfa_enabled, u.email_verified
       FROM owner_mfa_challenges c
       JOIN users u ON u.id = c.owner_user_id
      WHERE c.id = $1 AND u.email = $2 AND u.is_system_owner = TRUE AND u.role = 'admin'
      LIMIT 1`,
    [challengeId, KUPUNA_OWNER_EMAIL]
  )).rows[0];
  if (!row || row.used_at || row.mfa_enabled !== true || row.email_verified !== true || new Date(row.expires_at).getTime() <= Date.now() || row.attempts >= OWNER_MFA_MAX_ATTEMPTS) {
    return res.status(401).json({ error: 'invalid_owner_challenge' });
  }
  const expected = Buffer.from(row.code_hash, 'hex');
  const actual = Buffer.from(hashOwnerCode(code), 'hex');
  const matches = expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  if (!matches) {
    await pool.query('UPDATE owner_mfa_challenges SET attempts = attempts + 1 WHERE id = $1', [challengeId]);
    return res.status(401).json({ error: 'invalid_owner_challenge' });
  }
  await pool.query('UPDATE owner_mfa_challenges SET used_at = NOW() WHERE id = $1', [challengeId]);
  const token = signAccessToken({
    id: row.id,
    email: row.email,
    role: row.role,
    token_version: row.token_version,
    ownerMfaVerified: true,
  });
  return res.json({ token, userId: row.id, role: 'admin', mfaVerified: true });
});

app.post('/api/auth/login', loginRateLimit, async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password required' });
  }
  const r = await pool.query('SELECT * FROM users WHERE email = $1', [String(email).toLowerCase()]);
  if (!r.rows.length) return res.status(401).json({ error: 'invalid_credentials' });
  const user = r.rows[0];
  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) return res.status(401).json({ error: 'invalid_credentials' });
  if (user.is_system_owner === true) {
    return res.status(403).json({ error: 'owner_mfa_required' });
  }
  const token = signAccessToken(user);
  return res.json({ token, userId: user.id, role: user.role, email: user.email });
});

app.post('/api/auth/logout', auth, async (req, res) => {
  await pool.query('UPDATE users SET token_version = token_version + 1 WHERE id = $1', [req.user.userId]);
  return res.json({ ok: true });
});

app.patch('/api/auth/change-password', auth, async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'current_password_and_new_password_required' });
  }
  if (String(newPassword).trim().length < 8) {
    return res.status(400).json({ error: 'new_password_min_length_8' });
  }

  const userRow = (await pool.query('SELECT password_hash FROM users WHERE id = $1 LIMIT 1', [req.user.userId])).rows[0];
  if (!userRow) {
    return res.status(404).json({ error: 'user_not_found' });
  }
  const matches = await bcrypt.compare(String(currentPassword), userRow.password_hash);
  if (!matches) {
    return res.status(401).json({ error: 'invalid_current_password' });
  }

  const hash = await bcrypt.hash(String(newPassword), 10);
  await pool.query('UPDATE users SET password_hash = $1, token_version = token_version + 1 WHERE id = $2', [hash, req.user.userId]);
  return res.json({ ok: true, message: 'password_changed' });
});

app.patch('/api/auth/update-profile', auth, async (req, res) => {
  if (isSystemOwner(req.user)) {
    return res.status(403).json({ error: 'owner_email_change_requires_owner_flow' });
  }
  const { email, fullName } = req.body || {};
  const normalizedEmail = String(email || '').trim().toLowerCase();
  const normalizedName = String(fullName || '').trim();

  if (!normalizedEmail) {
    return res.status(400).json({ error: 'email_required' });
  }

  const emailExists = (await pool.query('SELECT id FROM users WHERE email = $1 AND id <> $2 LIMIT 1', [normalizedEmail, req.user.userId])).rows[0];
  if (emailExists) {
    return res.status(409).json({ error: 'email_already_taken' });
  }

  await pool.query(
    'UPDATE users SET email = $1, full_name = $2 WHERE id = $3',
    [normalizedEmail, normalizedName || null, req.user.userId]
  );

  return res.json({
    ok: true,
    email: normalizedEmail,
    fullName: normalizedName || null,
  });
});

app.post('/api/uploads/image', auth, uploadRateLimit, async (req, res) => {
  const body = req.body || {};
  const mimeType = String(body.mimeType || 'image/jpeg').trim().toLowerCase();
  const allowed = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
  };
  const extension = allowed[mimeType];
  if (!extension) {
    return res.status(400).json({ error: 'unsupported_image_type' });
  }

  let imageBase64 = String(body.imageBase64 || '').trim();
  const dataUrl = imageBase64.match(/^data:(image\/[a-z0-9.+-]+);base64,(.+)$/i);
  if (dataUrl) {
    imageBase64 = dataUrl[2];
  }
  if (!imageBase64) {
    return res.status(400).json({ error: 'image_required' });
  }

  let buffer;
  try {
    buffer = Buffer.from(imageBase64, 'base64');
  } catch (_e) {
    return res.status(400).json({ error: 'invalid_image' });
  }
  if (!buffer.length || buffer.length > 5 * 1024 * 1024) {
    return res.status(400).json({ error: 'image_size_invalid' });
  }
  if (detectImageMime(buffer) !== mimeType) {
    return res.status(400).json({ error: 'image_content_mismatch' });
  }

  await fs.promises.mkdir(UPLOAD_DIR, { recursive: true });
  const fileName = `${Date.now()}_${crypto.randomBytes(8).toString('hex')}.${extension}`;
  await fs.promises.writeFile(path.join(UPLOAD_DIR, fileName), buffer);
  await pool.query(
    'INSERT INTO uploaded_files (file_name, owner_user_id, mime_type, size_bytes) VALUES ($1, $2, $3, $4)',
    [fileName, req.user.userId, mimeType, buffer.length]
  );
  const url = `/api/uploads/${fileName}`;
  return res.json({ ok: true, url });
});

app.get('/api/uploads/:fileName', auth, async (req, res) => {
  const fileName = String(req.params.fileName || '').trim();
  if (!/^[0-9]+_[a-f0-9]{16}\.(jpg|png|webp|gif)$/.test(fileName)) {
    return res.status(404).json({ error: 'not_found' });
  }
  const row = (await pool.query(
    'SELECT file_name, owner_user_id, mime_type FROM uploaded_files WHERE file_name = $1 LIMIT 1',
    [fileName]
  )).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, row.owner_user_id)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  return res.type(row.mime_type).sendFile(path.join(UPLOAD_DIR, fileName));
});

};
