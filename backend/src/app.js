const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const https = require('https');
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();

const PORT = Number(process.env.PORT || 3005);
const JWT_SECRET = requiredEnv('JWT_SECRET');
// Independent secret for POS grant-points QR tokens: derived from JWT_SECRET but
// deliberately distinct so a captured/leaked POS QR token can never be replayed as a
// session auth token (and vice versa) against the main `auth` middleware.
const POS_GRANT_TOKEN_SECRET = crypto.createHmac('sha256', JWT_SECRET).update('kupuna_pos_grant_token_v1').digest('hex');
const POS_GRANT_TOKEN_TTL_SECONDS = 90;
const FCM_SERVER_KEY = String(process.env.FCM_SERVER_KEY || '').trim();
const PAYMENT_WEBHOOK_SECRET = String(process.env.PAYMENT_WEBHOOK_SECRET || '').trim();
const GEMINI_API_KEY = String(process.env.GEMINI_API_KEY || '').trim();
const GEMINI_MODEL = String(process.env.GEMINI_MODEL || 'gemini-1.5-flash').trim();
const ACCESS_TOKEN_TTL = String(process.env.ACCESS_TOKEN_TTL || '1h').trim();
const KUPUNA_OWNER_EMAIL = String(process.env.KUPUNA_OWNER_EMAIL || '').trim().toLowerCase();
const OWNER_ENFORCEMENT_ENABLED = String(process.env.OWNER_ENFORCEMENT_ENABLED || '').toLowerCase() === 'true';
const DEV_OWNER_BYPASS = String(process.env.DEV_OWNER_BYPASS || '').toLowerCase() === 'true';
const SMTP_HOST = String(process.env.SMTP_HOST || '').trim();
const SMTP_PORT = Number(process.env.SMTP_PORT || 587);
const SMTP_USER = String(process.env.SMTP_USER || '').trim();
const SMTP_PASSWORD = String(process.env.SMTP_PASSWORD || '');
const EMAIL_FROM = String(process.env.EMAIL_FROM || '').trim();
const OWNER_MFA_CODE_TTL_MS = Number(process.env.OWNER_MFA_CODE_TTL_MS || 10 * 60 * 1000);
const OWNER_MFA_MAX_ATTEMPTS = Number(process.env.OWNER_MFA_MAX_ATTEMPTS || 5);
const DEV_OWNER_CHALLENGE_TTL_MS = 60 * 1000;
const devOwnerChallenges = new Map();
const GEMINI_FALLBACK_MODELS = [
  GEMINI_MODEL,
  'gemini-2.5-flash',
  'gemini-2.0-flash',
  'gemini-1.5-flash-latest',
  'gemini-1.5-pro-latest',
].filter((v, i, arr) => v && arr.indexOf(v) === i);
const AI_ONLY_MODE = String(process.env.AI_ONLY_MODE || '').toLowerCase() === 'true';
const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}
const INVOICES_UPLOAD_DIR = path.join(UPLOAD_DIR, 'invoices');
if (!fs.existsSync(INVOICES_UPLOAD_DIR)) {
  fs.mkdirSync(INVOICES_UPLOAD_DIR, { recursive: true });
}
const CORS_ALLOWED_ORIGINS = parseList(
  process.env.CORS_ALLOWED_ORIGINS
    || 'http://localhost:3002,http://127.0.0.1:3002,http://localhost:8081,http://127.0.0.1:8081,http://localhost:8088,http://127.0.0.1:8088,http://localhost:8091,http://127.0.0.1:8091,http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173'
);
const AUTH_RATE_LIMIT_WINDOW_MS = Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000);
const LOGIN_RATE_LIMIT_MAX = Number(process.env.LOGIN_RATE_LIMIT_MAX || 20);
const SIGNUP_RATE_LIMIT_MAX = Number(process.env.SIGNUP_RATE_LIMIT_MAX || 10);
const UPLOAD_RATE_LIMIT_WINDOW_MS = Number(process.env.UPLOAD_RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000);
const UPLOAD_RATE_LIMIT_MAX = Number(process.env.UPLOAD_RATE_LIMIT_MAX || 30);

function requiredEnv(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) {
    throw new Error(`${name}_required`);
  }
  return value;
}

function parseList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function corsGuard(req, res, next) {
  const origin = String(req.headers.origin || '').trim();
  if (!origin) return next();
  const isLocalDevelopmentOrigin = process.env.NODE_ENV !== 'production'
    && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  if (!CORS_ALLOWED_ORIGINS.includes(origin) && !isLocalDevelopmentOrigin) {
    return res.status(403).json({ error: 'cors_origin_denied' });
  }
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-kupuna-webhook-secret');
  if (req.method === 'OPTIONS') return res.status(204).end();
  return next();
}

function createRateLimiter({ windowMs, max, keyPrefix, keyParts }) {
  const buckets = new Map();
  return (req, res, next) => {
    if (!Number.isFinite(windowMs) || windowMs <= 0 || !Number.isFinite(max) || max <= 0) {
      return next();
    }
    const now = Date.now();
    const parts = [keyPrefix, req.ip || req.socket?.remoteAddress || 'unknown'];
    if (typeof keyParts === 'function') parts.push(...keyParts(req));
    const key = parts.join(':');
    const current = buckets.get(key);
    if (!current || current.resetAt <= now) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }
    current.count += 1;
    if (current.count > max) {
      const retryAfter = Math.max(1, Math.ceil((current.resetAt - now) / 1000));
      res.setHeader('Retry-After', String(retryAfter));
      return res.status(429).json({ error: 'rate_limited', retryAfterSeconds: retryAfter });
    }
    buckets.set(key, current);
    return next();
  };
}

const loginRateLimit = createRateLimiter({
  windowMs: AUTH_RATE_LIMIT_WINDOW_MS,
  max: LOGIN_RATE_LIMIT_MAX,
  keyPrefix: 'login',
  keyParts: (req) => [String((req.body || {}).email || '').trim().toLowerCase()],
});
const signupRateLimit = createRateLimiter({
  windowMs: AUTH_RATE_LIMIT_WINDOW_MS,
  max: SIGNUP_RATE_LIMIT_MAX,
  keyPrefix: 'signup',
});
const uploadRateLimit = createRateLimiter({
  windowMs: UPLOAD_RATE_LIMIT_WINDOW_MS,
  max: UPLOAD_RATE_LIMIT_MAX,
  keyPrefix: 'upload',
  keyParts: (req) => [String(req.user?.userId || 'anonymous')],
});
const ownerLoginRateLimit = createRateLimiter({
  windowMs: AUTH_RATE_LIMIT_WINDOW_MS,
  max: 5,
  keyPrefix: 'owner-login',
  keyParts: (req) => [String((req.body || {}).email || '').trim().toLowerCase()],
});
const ownerVerifyRateLimit = createRateLimiter({
  windowMs: AUTH_RATE_LIMIT_WINDOW_MS,
  max: 10,
  keyPrefix: 'owner-verify',
  keyParts: (req) => [String((req.body || {}).challengeId || '').trim()],
});
const ownerResendRateLimit = createRateLimiter({
  windowMs: AUTH_RATE_LIMIT_WINDOW_MS,
  max: 3,
  keyPrefix: 'owner-resend',
  keyParts: (req) => [String((req.body || {}).challengeId || '').trim()],
});

app.use(corsGuard);
app.use(express.json({ limit: '8mb' }));


module.exports = {
  app,
  PORT,
  JWT_SECRET,
  POS_GRANT_TOKEN_SECRET,
  POS_GRANT_TOKEN_TTL_SECONDS,
  FCM_SERVER_KEY,
  PAYMENT_WEBHOOK_SECRET,
  GEMINI_API_KEY,
  GEMINI_MODEL,
  ACCESS_TOKEN_TTL,
  KUPUNA_OWNER_EMAIL,
  OWNER_ENFORCEMENT_ENABLED,
  DEV_OWNER_BYPASS,
  SMTP_HOST,
  SMTP_PORT,
  SMTP_USER,
  SMTP_PASSWORD,
  EMAIL_FROM,
  OWNER_MFA_CODE_TTL_MS,
  OWNER_MFA_MAX_ATTEMPTS,
  DEV_OWNER_CHALLENGE_TTL_MS,
  devOwnerChallenges,
  GEMINI_FALLBACK_MODELS,
  AI_ONLY_MODE,
  UPLOAD_DIR,
  INVOICES_UPLOAD_DIR,
  CORS_ALLOWED_ORIGINS,
  AUTH_RATE_LIMIT_WINDOW_MS,
  LOGIN_RATE_LIMIT_MAX,
  SIGNUP_RATE_LIMIT_MAX,
  UPLOAD_RATE_LIMIT_WINDOW_MS,
  UPLOAD_RATE_LIMIT_MAX,
  requiredEnv,
  parseList,
  corsGuard,
  createRateLimiter,
  loginRateLimit,
  signupRateLimit,
  uploadRateLimit,
  ownerLoginRateLimit,
  ownerVerifyRateLimit,
  ownerResendRateLimit,
};
