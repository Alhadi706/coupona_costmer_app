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
    || 'http://localhost:8088,http://127.0.0.1:8088,http://localhost:8091,http://127.0.0.1:8091,http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173'
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
  if (!CORS_ALLOWED_ORIGINS.includes(origin)) {
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

const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5434),
  user: process.env.PGUSER || 'kupuna_user',
  password: requiredEnv('PGPASSWORD'),
  database: process.env.PGDATABASE || 'kupuna_db',
});

const CANONICAL_ROLES = new Set(['customer', 'merchant', 'brand', 'admin', 'agent']);

function id() {
  return crypto.randomUUID();
}

function normalizeRole(value) {
  const role = String(value || 'customer').trim().toLowerCase();
  if (role === 'user') return 'customer';
  return CANONICAL_ROLES.has(role) ? role : 'customer';
}

function signAccessToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
      role: normalizeRole(user.role),
      tokenVersion: Number(user.token_version || 0),
      ownerMfaVerified: user.ownerMfaVerified === true,
    },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL }
  );
}

function isSystemOwner(user) {
  return Boolean(
    user?.isSystemOwner === true
      && KUPUNA_OWNER_EMAIL
      && String(user.email || '').toLowerCase() === KUPUNA_OWNER_EMAIL
  );
}

function smtpConfigured() {
  return Boolean(SMTP_HOST && SMTP_USER && SMTP_PASSWORD && EMAIL_FROM && KUPUNA_OWNER_EMAIL);
}

function ownerMailer() {
  if (!smtpConfigured()) return null;
  return nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASSWORD },
  });
}

async function sendOwnerMfaCode(code) {
  const mailer = ownerMailer();
  if (!mailer) throw new Error('owner_email_delivery_not_configured');
  await mailer.sendMail({
    from: EMAIL_FROM,
    to: KUPUNA_OWNER_EMAIL,
    subject: 'Kupuna owner verification code',
    text: `Your Kupuna owner verification code is ${code}. It expires soon and can be used once.`,
  });
}

function hashOwnerCode(code) {
  return crypto.createHash('sha256').update(String(code)).digest('hex');
}

function ownerCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function isAdmin(user) {
  return user?.role === 'admin';
}

function isLoopbackRequest(req) {
  const address = String(req.ip || req.socket?.remoteAddress || '');
  return address === '127.0.0.1' || address === '::1' || address === '::ffff:127.0.0.1';
}

function canAccessUserObject(user, targetUserId) {
  return isAdmin(user) || user?.userId === targetUserId;
}

function detectImageMime(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) return null;
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return 'image/jpeg';
  if (buffer.length >= 6) {
    const header = buffer.subarray(0, 6).toString('ascii');
    if (header === 'GIF87a' || header === 'GIF89a') return 'image/gif';
  }
  if (buffer.length >= 12 && buffer.subarray(0, 4).toString('ascii') === 'RIFF' && buffer.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp';
  return null;
}

function toIso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

function normalizeMerchantKey(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function canonicalMerchantName(value) {
  const raw = String(value || '').replace(/ـ+/g, '').trim();
  if (!raw) return null;
  if (/شنابو|سنابو|شنيبو|شناب/i.test(raw)) {
    return 'شنابو';
  }
  if (/سندوتشات\s*نسيم|نسيم/i.test(raw)) {
    return 'سندوتشات نسيم';
  }
  return raw;
}

function normalizeForFingerprint(value) {
  return String(value || '')
    .replace(/ـ+/g, '')
    .toLowerCase()
    .replace(/[^ -\p{L}\p{N}]+/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function buildInvoiceFingerprint({
  merchantKey,
  invoiceNumber,
  orderNumber,
  invoiceDate,
  totalAmount,
  category,
  rawText,
  items,
}) {
  const itemSignature = Array.isArray(items)
    ? items
        .map((item) => {
          const name = normalizeForFingerprint(item?.name || item?.itemName || '');
          const quantity = item?.quantity == null ? '' : String(Number(item.quantity));
          const unitPrice = item?.unitPrice == null ? '' : String(Number(item.unitPrice).toFixed(2));
          const lineTotal = item?.lineTotal == null ? '' : String(Number(item.lineTotal).toFixed(2));
          return [name, quantity, unitPrice, lineTotal].join('|');
        })
        .filter(Boolean)
        .sort()
        .join('||')
    : '';

  const payload = [
    ['merchantKey', normalizeForFingerprint(merchantKey)].join(':'),
    ['invoiceNumber', normalizeForFingerprint(invoiceNumber)].join(':'),
    ['orderNumber', normalizeForFingerprint(orderNumber)].join(':'),
    ['invoiceDate', normalizeForFingerprint(invoiceDate)].join(':'),
    ['totalAmount', Number.isFinite(Number(totalAmount)) ? Number(totalAmount).toFixed(2) : ''].join(':'),
    ['category', normalizeForFingerprint(category || 'general')].join(':'),
    ['items', itemSignature].join(':'),
  ].join('||');

  const seed = payload + (itemSignature ? '' : `||raw:${normalizeForFingerprint(rawText).slice(0, 200)}`);
  return crypto.createHash('sha256').update(seed, 'utf8').digest('hex');
}

function parseFlexibleDate(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  if (/^\d{4}[\/-]\d{1,2}[\/-]\d{1,2}$/.test(raw)) {
    const normalized = raw.replace(/\//g, '-');
    const d = new Date(`${normalized}T00:00:00Z`);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (/^\d{1,2}[\/-]\d{1,2}[\/-]\d{2,4}$/.test(raw)) {
    const parts = raw.split(/[\/-]/).map((p) => Number(p));
    if (parts.length !== 3) return null;
    const day = parts[0];
    const month = parts[1];
    const year = parts[2] < 100 ? 2000 + parts[2] : parts[2];
    const d = new Date(Date.UTC(year, month - 1, day));
    return Number.isNaN(d.getTime()) ? null : d;
  }
  const fallback = new Date(raw);
  return Number.isNaN(fallback.getTime()) ? null : fallback;
}

function haversineDistanceKm(lat1, lng1, lat2, lng2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return 6371 * c;
}

function calculateAgeYears(birthDate) {
  if (!birthDate) return null;
  const d = new Date(birthDate);
  if (Number.isNaN(d.getTime())) return null;
  const now = new Date();
  let age = now.getUTCFullYear() - d.getUTCFullYear();
  const mNow = now.getUTCMonth();
  const mBirth = d.getUTCMonth();
  if (mNow < mBirth || (mNow === mBirth && now.getUTCDate() < d.getUTCDate())) {
    age -= 1;
  }
  return age;
}

function parseTargetingCriteria(offerRow) {
  if (offerRow?.criteria_json && typeof offerRow.criteria_json === 'object') {
    return offerRow.criteria_json;
  }
  const raw = String(offerRow?.target_value || '').trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch (_e) {
    return null;
  }
}

function extractJsonObject(text) {
  const raw = String(text || '').trim();
  if (!raw) return null;

  const fenced = raw.match(/```json\s*([\s\S]*?)```/i) || raw.match(/```\s*([\s\S]*?)```/i);
  const source = fenced ? fenced[1] : raw;
  const first = source.indexOf('{');
  const last = source.lastIndexOf('}');
  if (first < 0 || last < first) return null;
  const candidate = source.slice(first, last + 1);
  try {
    return JSON.parse(candidate);
  } catch (_e) {
    return null;
  }
}

function normalizeAiInvoiceFields(data) {
  const merchantName = canonicalMerchantName(data?.merchantName || data?.merchant_name || '') || null;
  const branchName = String(data?.branchName || data?.branch_name || '').trim() || null;
  const orderNumber = String(data?.orderNumber || data?.order_number || '').trim() || null;
  const invoiceNumber = String(data?.invoiceNumber || data?.invoice_number || '').trim() || null;
  const invoiceDate = String(data?.invoiceDate || data?.invoice_date || '').trim() || null;
  const category = String(data?.category || 'general').trim() || 'general';

  const clamp01 = (v) => {
    const n = Number(v);
    if (!Number.isFinite(n)) return 0;
    return Math.max(0, Math.min(1, n > 1 ? n / 100 : n));
  };
  // Separate confidences per section: a receipt can have a perfectly clear header
  // (store/date/number) but a blurry items table, or vice-versa — gating every field
  // off one blended score throws away good partial reads.
  const overallConfidence = clamp01(data?.confidence ?? data?.score ?? 0);
  const headerConfidence = data?.headerConfidence != null ? clamp01(data.headerConfidence) : overallConfidence;
  const totalConfidence = data?.totalConfidence != null ? clamp01(data.totalConfidence) : overallConfidence;
  const itemsConfidence = data?.itemsConfidence != null ? clamp01(data.itemsConfidence) : overallConfidence;

  const amountRaw = data?.totalAmount ?? data?.total_amount ?? data?.total;
  const amount = amountRaw == null ? null : Number(amountRaw);
  let totalAmount = Number.isFinite(amount) && amount > 0 ? Number(amount.toFixed(2)) : null;

  const itemsRaw = Array.isArray(data?.items) ? data.items : [];
  const items = itemsRaw
    .map((item) => {
      const name = String(item?.name || item?.itemName || '').trim();
      const qtyRaw = item?.quantity;
      const quantity = qtyRaw == null ? null : Number(qtyRaw);
      const unitRaw = item?.unitPrice ?? item?.price;
      const unitPrice = unitRaw == null ? null : Number(unitRaw);
      const totalRaw = item?.lineTotal ?? item?.total;
      const lineTotal = totalRaw == null ? null : Number(totalRaw);

      const q = Number.isFinite(quantity) && quantity > 0 ? Math.round(quantity) : null;
      let u = Number.isFinite(unitPrice) && unitPrice > 0 ? Number(unitPrice.toFixed(2)) : null;
      let t = Number.isFinite(lineTotal) && lineTotal > 0 ? Number(lineTotal.toFixed(2)) : null;

      if (u == null && q != null && t != null && q > 0) {
        u = Number((t / q).toFixed(2));
      }
      if (t == null && q != null && u != null) {
        t = Number((q * u).toFixed(2));
      }

      return {
        name: canonicalMerchantName(name) || name,
        quantity: q,
        unitPrice: u,
        lineTotal: t,
      };
    })
    .filter((item) => item.name && (item.quantity != null || item.unitPrice != null || item.lineTotal != null));

  // Self-consistency check: when the items table is legible and sums close to a
  // plausible total, prefer it over a standalone total figure that may have been
  // misread from a single blurry line (this is the single highest-value accuracy fix
  // observed against real receipts: totals like "5.00"/"76.00" instead of "16.000").
  const itemsSum = items.reduce((sum, it) => sum + (it.lineTotal || 0), 0);
  if (items.length > 0 && itemsSum > 0) {
    const roundedSum = Number(itemsSum.toFixed(2));
    if (totalAmount == null) {
      totalAmount = roundedSum;
    } else {
      const diffRatio = Math.abs(totalAmount - roundedSum) / Math.max(totalAmount, roundedSum);
      if (diffRatio > 0.2 && itemsConfidence >= totalConfidence) {
        totalAmount = roundedSum;
      }
    }
  }

  return {
    merchantName,
    branchName,
    orderNumber,
    invoiceNumber,
    invoiceDate,
    totalAmount,
    items,
    category,
    confidence: overallConfidence,
    headerConfidence,
    totalConfidence,
    itemsConfidence,
  };
}

const INVOICE_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    merchantName: { type: 'STRING', nullable: true },
    branchName: { type: 'STRING', nullable: true },
    orderNumber: { type: 'STRING', nullable: true },
    invoiceNumber: { type: 'STRING', nullable: true },
    invoiceDate: { type: 'STRING', nullable: true },
    totalAmount: { type: 'NUMBER', nullable: true },
    category: { type: 'STRING', enum: ['food', 'grocery', 'pharmacy', 'transport', 'general'] },
    items: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          name: { type: 'STRING' },
          quantity: { type: 'NUMBER', nullable: true },
          unitPrice: { type: 'NUMBER', nullable: true },
          lineTotal: { type: 'NUMBER', nullable: true },
        },
        required: ['name'],
      },
    },
    headerConfidence: { type: 'NUMBER' },
    totalConfidence: { type: 'NUMBER' },
    itemsConfidence: { type: 'NUMBER' },
  },
  required: ['category', 'items', 'headerConfidence', 'totalConfidence', 'itemsConfidence'],
};

async function analyzeInvoiceWithGemini({ rawText, imageBase64, mimeType }) {
  if (!GEMINI_API_KEY) {
    return { ok: false, reason: 'gemini_not_configured' };
  }

  const instruction = [
    'You are reading a real casual smartphone photo of a paper store/restaurant receipt (Arabic and/or English, often thermal-printer text) — held in a hand, possibly tilted, blurry, glared, or partially cropped. It is NOT a flatbed scan; expect real-world photo noise and still do your best.',
    'Look at the image directly and read every digit and character yourself — this is the only reliable source, ignore any other text hint provided.',
    'Currency amounts on Gulf-region receipts are usually written with 3 decimal places (e.g. "16.000" means sixteen, not sixteen thousand). Read the full number including all decimal digits exactly as printed.',
    'Read the items table row by row: each row usually has item name, quantity, unit price, and line total. Numbers next to each other can be easy to confuse — double check which column is quantity vs price vs total.',
    'CRITICAL: only output an item row if you can actually see that item printed in the image. Never invent, duplicate, or pad extra rows to look complete — a receipt with one visible item line must return exactly one item, not more. It is far better to return fewer correct items (or an empty list) than extra guessed ones.',
    'For every item you output, quantity * unitPrice must equal lineTotal (small rounding aside); if it does not, you misread a digit — look again or omit that field rather than guessing.',
    'Self-check before answering: the sum of all items\' lineTotal should be close to totalAmount (they may differ slightly due to tax/discount/service charge). If they strongly disagree, re-read the image and correct whichever value you are less sure about.',
    'If a specific character, word, or number is illegible, leave that field null — never invent random letters/numbers to fill a field.',
    'Return strict JSON only, matching the provided schema.',
    'Field notes:',
    '- Prefer the merchant brand name over a branch/location sub-line.',
    '- An order number may appear vertically/stacked below its label, separate from invoice/date.',
    '- Do not use a time or date value as orderNumber or invoiceNumber.',
    '- Only fill invoiceNumber when the receipt clearly labels a number as an invoice/receipt number distinct from the order number; if the receipt only really has one identifying number (the order number), leave invoiceNumber null instead of reusing an unrelated printed code (e.g. a till/footer sequence number).',
    '- headerConfidence = how sure you are about merchantName/invoiceNumber/orderNumber/invoiceDate (0-1).',
    '- totalConfidence = how sure you are about totalAmount specifically (0-1).',
    '- itemsConfidence = how sure you are about the items list specifically (0-1).',
  ].join('\n');

  // The raw local OCR text (Tesseract) is frequently garbled for Arabic receipts and was
  // found to actively mislead the model into hallucinating item rows when a photo is
  // present — real-world testing showed pure image analysis matches manual Gemini results
  // perfectly. We now ignore `rawText` completely in the Gemini call.
  const parts = [{ text: instruction }];

  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: mimeType || 'image/jpeg',
        data: imageBase64,
      },
    });
  }

  let lastError = null;

  for (const model of GEMINI_FALLBACK_MODELS) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts }],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: 'application/json',
            responseSchema: INVOICE_RESPONSE_SCHEMA,
          },
        }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      lastError = {
        model,
        reason: 'gemini_request_failed',
        details: errorText.slice(0, 1200),
      };
      continue;
    }

    const payload = await response.json();
    const text = payload?.candidates?.[0]?.content?.parts?.map((p) => p?.text || '').join('\n') || '';
    const parsed = extractJsonObject(text);
    if (!parsed) {
      lastError = {
        model,
        reason: 'gemini_invalid_json',
        raw: String(text || '').slice(0, 1200),
      };
      continue;
    }

    return {
      ok: true,
      source: 'gemini',
      model,
      ...normalizeAiInvoiceFields(parsed),
    };
  }

  return {
    ok: false,
    ...(lastError || { reason: 'gemini_request_failed', details: 'No model response' }),
  };
}

async function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    return res.status(401).json({ error: 'Missing token' });
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const row = (await pool.query(
      'SELECT id, email, role, token_version, is_system_owner, mfa_enabled, email_verified FROM users WHERE id = $1 LIMIT 1',
      [payload.userId]
    )).rows[0];
    if (!row || Number(row.token_version || 0) !== Number(payload.tokenVersion || 0)) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    if (row.is_system_owner && (
      payload.ownerMfaVerified !== true
      || !KUPUNA_OWNER_EMAIL
      || String(row.email).toLowerCase() !== KUPUNA_OWNER_EMAIL
      || row.mfa_enabled !== true
      || row.email_verified !== true
    )) {
      return res.status(401).json({ error: 'owner_mfa_required' });
    }
    req.user = {
      userId: row.id,
      email: row.email,
      role: normalizeRole(row.role),
      tokenVersion: Number(row.token_version || 0),
      isSystemOwner: row.is_system_owner === true,
      mfaEnabled: row.mfa_enabled === true,
      emailVerified: row.email_verified === true,
      ownerMfaVerified: payload.ownerMfaVerified === true,
    };
    return next();
  } catch (_e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

async function initSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'customer',
      phone TEXT,
      full_name TEXT,
      gender TEXT,
      birth_date DATE,
      city TEXT,
      country TEXT,
      profile_completed BOOLEAN NOT NULL DEFAULT FALSE,
      points INTEGER NOT NULL DEFAULT 0,
      points_history JSONB NOT NULL DEFAULT '[]'::jsonb,
      token_version INTEGER NOT NULL DEFAULT 0,
      is_system_owner BOOLEAN NOT NULL DEFAULT FALSE,
      mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
      email_verified BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS owner_mfa_challenges (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      code_hash TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS customer_profiles (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS merchant_profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      business_name TEXT,
      commercial_registration TEXT,
      phone TEXT,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      location_address TEXT,
      point_value NUMERIC,
      status TEXT NOT NULL DEFAULT 'pending_activation',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS brand_profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      business_name TEXT,
      commercial_registration TEXT,
      phone TEXT,
      location_lat DOUBLE PRECISION,
      location_lng DOUBLE PRECISION,
      location_address TEXT,
      point_value NUMERIC,
      status TEXT NOT NULL DEFAULT 'pending_activation',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS cashier_profiles (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      merchant_id TEXT,
      branch_id TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS role_requests (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role_type TEXT NOT NULL,
      role_profile_id TEXT,
      status TEXT NOT NULL DEFAULT 'pending_admin_review',
      plan_type TEXT,
      request_data JSONB NOT NULL DEFAULT '{}'::jsonb,
      rejection_reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      reviewed_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS subscriptions (
      id TEXT PRIMARY KEY,
      role_profile_id TEXT NOT NULL,
      role_type TEXT NOT NULL,
      plan_type TEXT,
      status TEXT NOT NULL,
      trial_duration_days INTEGER NOT NULL DEFAULT 30,
      trial_start_date TIMESTAMPTZ,
      trial_end_date TIMESTAMPTZ,
      billing_cycle TEXT,
      next_billing_date TIMESTAMPTZ,
      payment_method_ref TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      title TEXT,
      body TEXT,
      target_screen TEXT,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_push_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token TEXT NOT NULL UNIQUE,
      platform TEXT,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS uploaded_files (
      file_name TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      mime_type TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS offers (
      id TEXT PRIMARY KEY,
      owner_id TEXT,
      offer_type TEXT,
      category TEXT,
      title_type TEXT,
      discount_type TEXT,
      discount_value TEXT,
      price TEXT,
      description TEXT,
      start_date TIMESTAMPTZ,
      end_date TIMESTAMPTZ,
      location TEXT,
      image_url TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      lifecycle_status TEXT NOT NULL DEFAULT 'pending_review',
      lifecycle_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      lifecycle_reason TEXT,
      published_at TIMESTAMPTZ,
      redeemed_at TIMESTAMPTZ,
      expired_at TIMESTAMPTZ,
      archived_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS stores (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT,
      description TEXT,
      phone TEXT,
      location TEXT,
      lat DOUBLE PRECISION NOT NULL,
      lng DOUBLE PRECISION NOT NULL
    );

    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      members INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS group_messages (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      sender_id TEXT,
      sender_name TEXT,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS group_message_replies (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      message_id TEXT NOT NULL,
      sender_id TEXT,
      sender_name TEXT,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS group_message_reactions (
      message_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      emoji TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(message_id, user_id, emoji)
    );

    CREATE TABLE IF NOT EXISTS private_chats (
      id TEXT PRIMARY KEY,
      title TEXT,
      last_message TEXT,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS private_chat_participants (
      chat_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      PRIMARY KEY(chat_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS private_messages (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      sender_id TEXT,
      sender_name TEXT,
      text TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_id TEXT NOT NULL,
      blocked_id TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(blocker_id, blocked_id)
    );

    CREATE TABLE IF NOT EXISTS private_chat_user_state (
      user_id TEXT NOT NULL,
      chat_id TEXT NOT NULL,
      is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
      is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
      is_muted BOOLEAN NOT NULL DEFAULT FALSE,
      is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
      last_read_at TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(user_id, chat_id)
    );

    CREATE TABLE IF NOT EXISTS rewards (
      id TEXT PRIMARY KEY,
      reward_name TEXT NOT NULL,
      description TEXT,
      value INTEGER NOT NULL DEFAULT 0,
      kind TEXT NOT NULL DEFAULT 'physical',
      source_type TEXT,
      source_id TEXT,
      image_url TEXT,
      expires_at TIMESTAMPTZ,
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      quantity_limit INTEGER,
      quantity_redeemed INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS activity_logs (
      id TEXT PRIMARY KEY,
      customer_email TEXT NOT NULL,
      amount NUMERIC NOT NULL DEFAULT 0,
      transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS wallet_accounts (
      owner_id TEXT PRIMARY KEY,
      balance NUMERIC NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'SAR',
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS point_accounts (
      owner_id TEXT PRIMARY KEY,
      available_points INTEGER NOT NULL DEFAULT 0,
      lifetime_points INTEGER NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS ledger_entries (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount NUMERIC NOT NULL DEFAULT 0,
      points INTEGER NOT NULL DEFAULT 0,
      reference TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS invoice_scans (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      merchant_name TEXT,
      merchant_key TEXT NOT NULL,
      invoice_fingerprint TEXT,
      invoice_number TEXT,
      order_number TEXT,
      invoice_date DATE,
      total_amount NUMERIC,
      currency TEXT NOT NULL DEFAULT 'SAR',
      category TEXT NOT NULL DEFAULT 'general',
      raw_text TEXT NOT NULL,
      reward_applied BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS order_number TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS invoice_fingerprint TEXT');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_address TEXT');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE brand_profiles ADD COLUMN IF NOT EXISTS location_address TEXT');

  await pool.query('CREATE INDEX IF NOT EXISTS idx_customer_profiles_user_id ON customer_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_merchant_profiles_user_id ON merchant_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_brand_profiles_user_id ON brand_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_cashier_profiles_user_id ON cashier_profiles(user_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_role_requests_user_type ON role_requests(user_id, role_type, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_role_requests_status ON role_requests(status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_subscriptions_profile ON subscriptions(role_profile_id, role_type, updated_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status, trial_end_date)');

  await pool.query(
    `INSERT INTO app_settings (key, value) VALUES
      ('trial_duration_days_default', '30'),
      ('grace_period_days_default', '7')
     ON CONFLICT (key) DO NOTHING`
  );

  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_scans_owner_created ON invoice_scans(owner_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_scans_merchant_key ON invoice_scans(merchant_key)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_scans_fingerprint ON invoice_scans(invoice_fingerprint)');
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS ux_invoice_scans_dedupe
      ON invoice_scans(
        owner_id,
        merchant_key,
        COALESCE(invoice_number, ''),
        COALESCE(order_number, ''),
        COALESCE(invoice_date, DATE '1970-01-01'),
        COALESCE(total_amount, -1)
      )
  `);
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS ux_invoice_scans_fingerprint
      ON invoice_scans(invoice_fingerprint)
      WHERE invoice_fingerprint IS NOT NULL
  `);

  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS image_hash TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS retention_expires_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT \'approved\'');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS review_note TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS original_image_path TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS digital_code TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS redeemed_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS redeemed_by TEXT');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS settlement_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT \'digital\'');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_type TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS branches (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      name TEXT NOT NULL,
      address TEXT,
      location TEXT,
      latitude DOUBLE PRECISION,
      longitude DOUBLE PRECISION,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
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
      PRIMARY KEY(branch_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_team_members (
      brand_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      can_manage_products BOOLEAN NOT NULL DEFAULT FALSE,
      can_view_geo_distribution BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(brand_id, user_id)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_merchant_fraction_balance (
      customer_id TEXT NOT NULL,
      merchant_id TEXT NOT NULL,
      fraction_balance NUMERIC NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(customer_id, merchant_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS points_ledger_merchant (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      merchant_id TEXT NOT NULL,
      invoice_scan_id TEXT,
      points_delta INTEGER NOT NULL,
      fraction_before NUMERIC NOT NULL DEFAULT 0,
      fraction_after NUMERIC NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS customer_brand_fraction_balance (
      customer_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      fraction_balance NUMERIC NOT NULL DEFAULT 0,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(customer_id, brand_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS points_ledger_brand (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      invoice_scan_id TEXT,
      points_delta INTEGER NOT NULL,
      fraction_before NUMERIC NOT NULL DEFAULT 0,
      fraction_after NUMERIC NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS fraud_flags (
      id TEXT PRIMARY KEY,
      owner_id TEXT,
      invoice_scan_id TEXT,
      reason TEXT NOT NULL,
      details JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  // One-time-use ledger for POS grant-points QR tokens (nonce is unique per issued token).
  // Inserting the nonce here is how a second scan of the same QR is rejected atomically.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS pos_grant_token_uses (
      nonce TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL,
      used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('CREATE INDEX IF NOT EXISTS idx_pos_grant_token_uses_used_at ON pos_grant_token_uses(used_at)');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS pos_manual_override BOOLEAN NOT NULL DEFAULT FALSE');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS product_registry (
      id TEXT PRIMARY KEY,
      brand_id TEXT NOT NULL,
      name TEXT NOT NULL,
      image_url TEXT,
      barcode TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS invoice_line_items (
      id TEXT PRIMARY KEY,
      invoice_scan_id TEXT NOT NULL,
      item_name TEXT NOT NULL,
      quantity INTEGER,
      unit_price NUMERIC,
      line_total NUMERIC,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS brand_matches (
      id TEXT PRIMARY KEY,
      invoice_line_item_id TEXT NOT NULL,
      brand_id TEXT NOT NULL,
      product_id TEXT,
      confidence NUMERIC NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      report_type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'new',
      target_store_id TEXT,
      target_brand_id TEXT,
      description TEXT,
      thank_you_sent_at TIMESTAMPTZ,
      reward_granted BOOLEAN NOT NULL DEFAULT FALSE,
      reward_type TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS disputes (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      invoice_scan_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'new',
      reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS escrow_accounts (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      balance NUMERIC NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS settlements (
      id TEXT PRIMARY KEY,
      escrow_account_id TEXT NOT NULL,
      amount NUMERIC NOT NULL,
      settlement_type TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS exchange_rate_config (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      destination_type TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      source_point_value NUMERIC NOT NULL,
      destination_point_value NUMERIC NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS exchange_transactions (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      reward_id TEXT,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      destination_type TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      source_points NUMERIC NOT NULL,
      destination_points NUMERIC NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS exchange_rate_settings (
      id TEXT PRIMARY KEY,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      destination_type TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      source_point_value NUMERIC NOT NULL,
      destination_point_value NUMERIC NOT NULL,
      rate NUMERIC NOT NULL,
      configured_by TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (source_type, source_id, destination_type, destination_id)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS reward_claims (
      id TEXT PRIMARY KEY,
      owner_id TEXT NOT NULL,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      points_cost INTEGER NOT NULL,
      reward_kind TEXT NOT NULL,
      pickup_qr_code TEXT,
      status TEXT NOT NULL DEFAULT 'issued',
      points_deducted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS peer_ads (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL,
      content TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_value TEXT,
      target_category TEXT,
      target_geo_json JSONB,
      fee_paid NUMERIC NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'draft',
      rejection_reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS sourcing_inquiries (
      id TEXT PRIMARY KEY,
      peer_ad_id TEXT NOT NULL,
      merchant_user_id TEXT NOT NULL,
      owner_user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'opened',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS loyalty_health_scores (
      id TEXT PRIMARY KEY,
      merchant_id TEXT NOT NULL,
      score NUMERIC NOT NULL,
      trend TEXT NOT NULL,
      generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_groups (
      id TEXT PRIMARY KEY,
      role_type TEXT NOT NULL,
      role_profile_id TEXT NOT NULL,
      owner_user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (role_type, role_profile_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_group_members (
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(group_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_group_bans (
      group_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      banned_by TEXT NOT NULL,
      reason TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY(group_id, user_id)
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS community_messages (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      sender_name TEXT,
      text TEXT NOT NULL,
      is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
      is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
      image_url TEXT,
      message_type TEXT NOT NULL DEFAULT 'post',
      poll_json JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS offer_targeting_rules (
      offer_id TEXT PRIMARY KEY,
      target_type TEXT NOT NULL,
      target_value TEXT,
      min_points INTEGER,
      criteria_json JSONB,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query('ALTER TABLE offer_targeting_rules ADD COLUMN IF NOT EXISTS criteria_json JSONB');
  await pool.query('ALTER TABLE peer_ads ADD COLUMN IF NOT EXISTS target_category TEXT');
  await pool.query('ALTER TABLE peer_ads ADD COLUMN IF NOT EXISTS target_geo_json JSONB');
  await pool.query('ALTER TABLE community_messages ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query("ALTER TABLE community_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'post'");
  await pool.query('ALTER TABLE community_messages ADD COLUMN IF NOT EXISTS poll_json JSONB');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS working_hours TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()');

  await pool.query('CREATE INDEX IF NOT EXISTS idx_branches_merchant_id ON branches(merchant_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_cashier_profiles_branch_id ON cashier_profiles(branch_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_points_ledger_merchant_customer ON points_ledger_merchant(customer_id, merchant_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_points_ledger_brand_customer ON points_ledger_brand(customer_id, brand_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_fraud_flags_owner_created ON fraud_flags(owner_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_invoice_line_items_invoice ON invoice_line_items(invoice_scan_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_brand_matches_brand_id ON brand_matches(brand_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_reports_owner_status ON reports(owner_id, status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_reward_claims_owner_status ON reward_claims(owner_id, status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_peer_ads_status_created ON peer_ads(status, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_community_groups_role ON community_groups(role_type, role_profile_id)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_group_members(user_id, joined_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_community_messages_group ON community_messages(group_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_offer_targeting_type ON offer_targeting_rules(target_type, target_value)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC)');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_active ON user_push_tokens(user_id, is_active, updated_at DESC)');

  await pool.query(
    `INSERT INTO app_settings (key, value) VALUES
      ('daily_invoice_limit', '10'),
      ('invoice_retention_months', '24')
     ON CONFLICT (key) DO NOTHING`
  );

  await pool.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query("ALTER TABLE rewards ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'physical'");
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_type TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS source_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS quantity_limit INTEGER');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS quantity_redeemed INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS pickup_instructions TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_enabled BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_winner_user_id TEXT');
  await pool.query('ALTER TABLE rewards ADD COLUMN IF NOT EXISTS draw_completed_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE reward_claims ADD COLUMN IF NOT EXISTS reward_id TEXT');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS cta_type TEXT NOT NULL DEFAULT \'store\'');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS cta_value TEXT');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS impressions INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE offers ADD COLUMN IF NOT EXISTS clicks INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS target_screen TEXT');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS is_system_owner BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE');
  await pool.query('CREATE UNIQUE INDEX IF NOT EXISTS idx_single_system_owner ON users ((is_system_owner)) WHERE is_system_owner = TRUE');
  await pool.query('CREATE INDEX IF NOT EXISTS idx_uploaded_files_owner ON uploaded_files(owner_user_id, created_at DESC)');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS birth_date DATE');
  await pool.query('ALTER TABLE customer_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION');
  await pool.query('ALTER TABLE customer_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION');
  await pool.query('ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS category TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS image_url TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS target_store_name_snapshot TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS target_brand_name_snapshot TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolved_by_user_id TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolution_note TEXT');
  await pool.query('ALTER TABLE reports ADD COLUMN IF NOT EXISTS reward_points INTEGER NOT NULL DEFAULT 0');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS category TEXT');
  await pool.query('ALTER TABLE branches ADD COLUMN IF NOT EXISTS working_hours TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS merchant_profile_id TEXT');
  await pool.query('ALTER TABLE invoice_scans ADD COLUMN IF NOT EXISTS branch_id TEXT');

  await pool.query(`
    ALTER TABLE private_chat_user_state ADD COLUMN IF NOT EXISTS is_muted BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE private_chat_user_state ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE private_chat_user_state ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ;
  `);

  const storesCount = await pool.query('SELECT COUNT(*)::int AS c FROM stores');
  if (storesCount.rows[0].c === 0) {
    await pool.query(
      `INSERT INTO stores (id, name, category, description, phone, location, lat, lng) VALUES
      ($1,'مخبز المدينة','غذائية','مخبوزات طازجة','0910000001','طرابلس',32.8872,13.1913),
      ($2,'عيادة الشفاء','عيادات','خدمات طبية','0910000002','طرابلس',32.9001,13.2102),
      ($3,'متجر التقنية','إلكترونيات','إكسسوارات وهواتف','0910000003','طرابلس',32.8754,13.1801)`,
      [id(), id(), id()]
    );
  }

  const groupsCount = await pool.query('SELECT COUNT(*)::int AS c FROM groups');
  if (groupsCount.rows[0].c === 0) {
    await pool.query(
      `INSERT INTO groups (id, name, description, members) VALUES
      ($1,'مجموعة العروض','مناقشة العروض اليومية',12),
      ($2,'مجموعة النقاط','نصائح زيادة النقاط',8)`,
      [id(), id()]
    );
  }

  const rewardsCount = await pool.query('SELECT COUNT(*)::int AS c FROM rewards');
  if (rewardsCount.rows[0].c === 0) {
    await pool.query(
      `INSERT INTO rewards (id, reward_name, description, value, kind) VALUES
      ($1,'قسيمة 10 دينار','خصم مباشر عند الاستبدال - رمز رقمي فوري',10,'digital'),
      ($2,'قسيمة 25 دينار','خصم مميز عند الاستبدال - رمز رقمي فوري',25,'digital')`,
      [id(), id()]
    );
  }

  // One-time, idempotent backfill: link the still-generic seed rewards to a real active
  // merchant/brand if one exists, so the catalog stops showing unattributed coupons.
  // Safe to run on every boot: it only touches rows where source_type is still empty.
  const unlinkedMerchantReward = (await pool.query(
    `SELECT id FROM rewards WHERE reward_name = 'قسيمة 10 دينار' AND (source_type IS NULL OR source_type = '') LIMIT 1`
  )).rows[0];
  if (unlinkedMerchantReward) {
    const merchant = (await pool.query(
      `SELECT id FROM merchant_profiles WHERE status = 'active' ORDER BY created_at ASC LIMIT 1`
    )).rows[0];
    if (merchant) {
      await pool.query(
        `UPDATE rewards SET source_type = 'merchant', source_id = $2, expires_at = NOW() + INTERVAL '90 days' WHERE id = $1`,
        [unlinkedMerchantReward.id, merchant.id]
      );
    }
  }
  const unlinkedBrandReward = (await pool.query(
    `SELECT id FROM rewards WHERE reward_name = 'قسيمة 25 دينار' AND (source_type IS NULL OR source_type = '') LIMIT 1`
  )).rows[0];
  if (unlinkedBrandReward) {
    const brand = (await pool.query(
      `SELECT id FROM brand_profiles WHERE status = 'active' ORDER BY created_at ASC LIMIT 1`
    )).rows[0];
    if (brand) {
      await pool.query(
        `UPDATE rewards SET source_type = 'brand', source_id = $2, expires_at = NOW() + INTERVAL '90 days' WHERE id = $1`,
        [unlinkedBrandReward.id, brand.id]
      );
    }
  }
}

async function ensureCustomerProfile(client, userId) {
  await client.query(
    `INSERT INTO customer_profiles (user_id)
     VALUES ($1)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );
}

async function getIntSetting(client, key, fallback) {
  const row = (await client.query('SELECT value FROM app_settings WHERE key = $1 LIMIT 1', [key])).rows[0];
  const value = Number.parseInt(String(row?.value ?? ''), 10);
  if (!Number.isFinite(value) || value <= 0) return fallback;
  return value;
}

function requireAdmin(req, res, next) {
  if (OWNER_ENFORCEMENT_ENABLED && !isSystemOwner(req.user)) {
    return res.status(403).json({ error: 'system_owner_required' });
  }
  if (isAdmin(req.user)) {
    return next();
  }
  return res.status(403).json({ error: 'admin_required' });
}

async function canManageInvoice(client, user, invoiceId, targetState = null) {
  const row = (await client.query(
    'SELECT owner_id, merchant_profile_id, state FROM invoice_scans WHERE id = $1 LIMIT 1',
    [invoiceId]
  )).rows[0];
  if (!row) return { allowed: false, status: 404, error: 'invoice_not_found' };
  if (isAdmin(user)) return { allowed: true, row };
  if (row.owner_id === user.userId && row.state === 'rejected' && targetState === 'disputed') {
    return { allowed: true, row };
  }
  if (row.merchant_profile_id) {
    const merchant = await getMerchantProfileIdByUser(client, user.userId);
    if (merchant && merchant === row.merchant_profile_id) return { allowed: true, row };
  }
  return { allowed: false, status: 403, error: 'forbidden' };
}

async function canRedeemClaim(client, user, claim) {
  if (isAdmin(user)) return true;
  if (claim.source_type !== 'merchant' || !claim.source_id) return false;
  const merchantOwner = (await client.query(
    `SELECT 1
       FROM merchant_profiles
      WHERE id = $1
        AND user_id = $2
        AND status = 'active'
      LIMIT 1`,
    [claim.source_id, user.userId]
  )).rows[0];
  if (merchantOwner) return true;
  const row = (await client.query(
    `SELECT 1
       FROM cashier_profiles
      WHERE user_id = $1
        AND merchant_id = $2
        AND is_active = TRUE
      LIMIT 1`,
    [user.userId, claim.source_id]
  )).rows[0];
  return Boolean(row);
}

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

async function applyInvoiceApprovalRewards(client, invoiceId, ownerId, merchantProfileId) {
  const summary = {
    merchantPoints: 0,
    merchantFraction: 0,
    brandPoints: 0,
    brandBreakdown: [],
  };

  const invoice = (await client.query(
    'SELECT total_amount FROM invoice_scans WHERE id = $1 LIMIT 1',
    [invoiceId]
  )).rows[0];
  const invoiceTotalAmount = Number(invoice?.total_amount || 0);

  if (merchantProfileId && Number.isFinite(invoiceTotalAmount) && invoiceTotalAmount > 0) {
    const alreadyMerchantAwarded = (await client.query(
      'SELECT 1 FROM points_ledger_merchant WHERE invoice_scan_id = $1 LIMIT 1',
      [invoiceId]
    )).rows[0];

    if (!alreadyMerchantAwarded) {
      const merchant = (await client.query(
        'SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1',
        [merchantProfileId]
      )).rows[0];
      const pointValue = Number(merchant?.point_value || 0);
      if (Number.isFinite(pointValue) && pointValue > 0) {
        await client.query(
          `INSERT INTO customer_merchant_fraction_balance (customer_id, merchant_id, fraction_balance)
           VALUES ($1,$2,0)
           ON CONFLICT (customer_id, merchant_id) DO NOTHING`,
          [ownerId, merchantProfileId]
        );
        const bal = (await client.query(
          `SELECT fraction_balance
             FROM customer_merchant_fraction_balance
            WHERE customer_id = $1 AND merchant_id = $2
            FOR UPDATE`,
          [ownerId, merchantProfileId]
        )).rows[0];
        const before = Number(bal?.fraction_balance || 0);
        const calc = calculatePointsWithFraction(invoiceTotalAmount, pointValue, before);
        await client.query(
          `UPDATE customer_merchant_fraction_balance
              SET fraction_balance = $3,
                  updated_at = NOW()
            WHERE customer_id = $1 AND merchant_id = $2`,
          [ownerId, merchantProfileId, calc.newFraction]
        );
        await client.query(
          `INSERT INTO points_ledger_merchant (
            id, customer_id, merchant_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at
          ) VALUES (
            $1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months'
          )`,
          [id(), ownerId, merchantProfileId, invoiceId, calc.points, before, calc.newFraction]
        );
        summary.merchantPoints = calc.points;
        summary.merchantFraction = calc.newFraction;
      }
    }
  }

  const brandRows = (await client.query(
    `SELECT bm.brand_id,
            COALESCE(SUM(COALESCE(li.line_total, 0)), 0) AS amount
       FROM brand_matches bm
       JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
      WHERE li.invoice_scan_id = $1
      GROUP BY bm.brand_id`,
    [invoiceId]
  )).rows;

  for (const row of brandRows) {
    const brandId = String(row.brand_id || '').trim();
    const lineAmount = Number(row.amount || 0);
    if (!brandId || !Number.isFinite(lineAmount) || lineAmount <= 0) continue;

    const alreadyBrandAwarded = (await client.query(
      'SELECT 1 FROM points_ledger_brand WHERE invoice_scan_id = $1 AND brand_id = $2 LIMIT 1',
      [invoiceId, brandId]
    )).rows[0];
    if (alreadyBrandAwarded) continue;

    const brand = (await client.query(
      'SELECT point_value FROM brand_profiles WHERE id = $1 LIMIT 1',
      [brandId]
    )).rows[0];
    const pointValue = Number(brand?.point_value || 0);
    if (!Number.isFinite(pointValue) || pointValue <= 0) continue;

    await client.query(
      `INSERT INTO customer_brand_fraction_balance (customer_id, brand_id, fraction_balance)
       VALUES ($1,$2,0)
       ON CONFLICT (customer_id, brand_id) DO NOTHING`,
      [ownerId, brandId]
    );

    const bal = (await client.query(
      `SELECT fraction_balance
         FROM customer_brand_fraction_balance
        WHERE customer_id = $1 AND brand_id = $2
        FOR UPDATE`,
      [ownerId, brandId]
    )).rows[0];

    const before = Number(bal?.fraction_balance || 0);
    const calc = calculatePointsWithFraction(lineAmount, pointValue, before);
    await client.query(
      `UPDATE customer_brand_fraction_balance
          SET fraction_balance = $3,
              updated_at = NOW()
        WHERE customer_id = $1 AND brand_id = $2`,
      [ownerId, brandId, calc.newFraction]
    );
    await client.query(
      `INSERT INTO points_ledger_brand (
        id, customer_id, brand_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months'
      )`,
      [id(), ownerId, brandId, invoiceId, calc.points, before, calc.newFraction]
    );

    summary.brandPoints += calc.points;
    summary.brandBreakdown.push({
      brandId,
      lineAmount,
      points: calc.points,
      fraction: calc.newFraction,
    });
  }

  const totalAwardedPoints = summary.merchantPoints + summary.brandPoints;
  if (totalAwardedPoints > 0) {
    await client.query(
      `INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at)
       VALUES ($1,0,0,NOW())
       ON CONFLICT (owner_id) DO NOTHING`,
      [ownerId]
    );
    await client.query(
      `UPDATE point_accounts
          SET available_points = available_points + $2,
              lifetime_points = lifetime_points + $2,
              updated_at = NOW()
        WHERE owner_id = $1`,
      [ownerId, totalAwardedPoints]
    );
    await client.query(
      `UPDATE users
          SET points = points + $2,
              points_history = points_history || to_jsonb($2::int)
        WHERE id = $1`,
      [ownerId, totalAwardedPoints]
    );
    await insertNotification(
      client,
      ownerId,
      'points_confirmed',
      'Points added',
      `Invoice approval granted ${totalAwardedPoints} point(s).`,
      {
        invoiceId,
        merchantPoints: summary.merchantPoints,
        brandPoints: summary.brandPoints,
      }
    );
  }

  return summary;
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

function offerMatchesTargeting(offerRow, userContext) {
  const targetType = String(offerRow.target_type || 'all').trim().toLowerCase();
  const targetValue = String(offerRow.target_value || '').trim().toLowerCase();
  const minPoints = Number(offerRow.min_points || 0);

  if (!targetType || targetType === 'all') return true;
  if (targetType === 'city') {
    return String(userContext.city || '').trim().toLowerCase() === targetValue;
  }
  if (targetType === 'country') {
    return String(userContext.country || '').trim().toLowerCase() === targetValue;
  }
  if (targetType === 'min_points') {
    return Number(userContext.availablePoints || 0) >= minPoints;
  }
  if (targetType === 'user_id') {
    return String(userContext.userId || '') === String(offerRow.target_value || '');
  }
  if (targetType === 'demographic_geo') {
    const criteria = parseTargetingCriteria(offerRow) || {};
    const minAge = Number(criteria.minAge);
    const maxAge = Number(criteria.maxAge);
    const userAge = Number(userContext.age);
    if (Number.isFinite(minAge) && (!Number.isFinite(userAge) || userAge < minAge)) return false;
    if (Number.isFinite(maxAge) && (!Number.isFinite(userAge) || userAge > maxAge)) return false;

    const requiredGender = String(criteria.gender || '').trim().toLowerCase();
    if (requiredGender && requiredGender !== 'any') {
      const userGender = String(userContext.gender || '').trim().toLowerCase();
      if (requiredGender !== userGender) return false;
    }

    const requiredCity = String(criteria.city || '').trim().toLowerCase();
    if (requiredCity) {
      if (String(userContext.city || '').trim().toLowerCase() !== requiredCity) return false;
    }

    const requiredCountry = String(criteria.country || '').trim().toLowerCase();
    if (requiredCountry) {
      if (String(userContext.country || '').trim().toLowerCase() !== requiredCountry) return false;
    }

    const centerLat = Number(criteria.centerLat);
    const centerLng = Number(criteria.centerLng);
    const maxDistanceKm = Number(criteria.maxDistanceKm);
    if (Number.isFinite(centerLat) && Number.isFinite(centerLng) && Number.isFinite(maxDistanceKm)) {
      const userLat = Number(userContext.locationLat);
      const userLng = Number(userContext.locationLng);
      if (!Number.isFinite(userLat) || !Number.isFinite(userLng)) return false;
      const d = haversineDistanceKm(userLat, userLng, centerLat, centerLng);
      if (d > maxDistanceKm) return false;
    }

    return true;
  }
  return false;
}

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
  const url = `${req.protocol}://${req.get('host')}/api/uploads/${fileName}`;
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

app.get('/api/roles/me', auth, async (req, res) => {
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    await ensureCustomerProfile(client, userId);

    const customerExists = (await client.query(
      'SELECT 1 FROM customer_profiles WHERE user_id = $1 LIMIT 1',
      [userId]
    )).rows.length > 0;

    const merchantExists = (await client.query(
      "SELECT 1 FROM merchant_profiles WHERE user_id = $1 AND status = 'active' LIMIT 1",
      [userId]
    )).rows.length > 0;

    const brandExists = (await client.query(
      "SELECT 1 FROM brand_profiles WHERE user_id = $1 AND status = 'active' LIMIT 1",
      [userId]
    )).rows.length > 0;

    const cashierRows = (await client.query(
      `SELECT cp.id, cp.merchant_id, cp.branch_id, cp.is_active,
              mp.business_name AS merchant_name,
              b.name AS branch_name
         FROM cashier_profiles cp
         LEFT JOIN merchant_profiles mp ON mp.id = cp.merchant_id
         LEFT JOIN branches b ON b.id = cp.branch_id
        WHERE cp.user_id = $1
        ORDER BY cp.created_at ASC`,
      [userId]
    )).rows;

    const subscriptionRows = (await client.query(
      `SELECT s.id, s.role_profile_id, s.role_type, s.status, s.plan_type, s.trial_start_date, s.trial_end_date, s.next_billing_date
         FROM subscriptions s
        WHERE s.role_profile_id IN (
          SELECT id FROM merchant_profiles WHERE user_id = $1
          UNION
          SELECT id FROM brand_profiles WHERE user_id = $1
        )
        ORDER BY s.updated_at DESC`,
      [userId]
    )).rows;

    return res.json({
      customer: customerExists,
      merchant: merchantExists,
      brand: brandExists,
      cashier: cashierRows.map((row) => ({
        id: row.id,
        merchantId: row.merchant_id,
        merchantName: row.merchant_name || null,
        branchId: row.branch_id,
        branchName: row.branch_name || null,
        isActive: Boolean(row.is_active),
      })),
      subscriptions: subscriptionRows.map((row) => ({
        id: row.id,
        roleProfileId: row.role_profile_id,
        roleType: row.role_type,
        status: row.status,
        planType: row.plan_type,
        trialStartDate: toIso(row.trial_start_date),
        trialEndDate: toIso(row.trial_end_date),
        nextBillingDate: toIso(row.next_billing_date),
      })),
    });
  } catch (e) {
    return res.status(500).json({ error: 'roles_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/roles/merchant/request', auth, async (req, res) => {
  const p = req.body || {};
  const phone = String(p.phone || '').trim();
  const category = String(p.category || '').trim() || null;
  const locationLat = Number(p.locationLat);
  const locationLng = Number(p.locationLng);
  const locationAddress = String(p.locationAddress || '').trim();
  if (!phone || !Number.isFinite(locationLat) || !Number.isFinite(locationLng)) {
    return res.status(400).json({ error: 'missing_required_fields' });
  }
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const profileId = id();
    await client.query(
      `INSERT INTO merchant_profiles (
         id, user_id, business_name, commercial_registration,
         phone, category, location_lat, location_lng, location_address, status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending_admin_review')
       ON CONFLICT (user_id)
       DO UPDATE SET
         business_name = EXCLUDED.business_name,
         commercial_registration = EXCLUDED.commercial_registration,
         phone = EXCLUDED.phone,
         category = EXCLUDED.category,
         location_lat = EXCLUDED.location_lat,
         location_lng = EXCLUDED.location_lng,
         location_address = EXCLUDED.location_address,
         status = 'pending_admin_review'`,
      [
        profileId,
        userId,
        p.businessName || null,
        p.commercialRegistration || null,
        phone,
        category,
        locationLat,
        locationLng,
        locationAddress || null,
      ]
    );

    const effectiveProfile = (await client.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0]?.id;
    const requestId = id();
    await client.query(
      `INSERT INTO role_requests (id, user_id, role_type, role_profile_id, status, plan_type, request_data)
       VALUES ($1, $2, 'merchant', $3, 'pending_admin_review', $4, $5::jsonb)`,
      [requestId, userId, effectiveProfile, p.planType || null, JSON.stringify(p)]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, requestId, status: 'pending_admin_review' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'merchant_request_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/roles/brand/request', auth, async (req, res) => {
  const p = req.body || {};
  const phone = String(p.phone || '').trim();
  const locationLat = Number(p.locationLat);
  const locationLng = Number(p.locationLng);
  const locationAddress = String(p.locationAddress || '').trim();
  if (!phone || !Number.isFinite(locationLat) || !Number.isFinite(locationLng)) {
    return res.status(400).json({ error: 'missing_required_fields' });
  }
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const profileId = id();
    await client.query(
      `INSERT INTO brand_profiles (
         id, user_id, business_name, commercial_registration,
         phone, location_lat, location_lng, location_address, status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending_admin_review')
       ON CONFLICT (user_id)
       DO UPDATE SET
         business_name = EXCLUDED.business_name,
         commercial_registration = EXCLUDED.commercial_registration,
         phone = EXCLUDED.phone,
         location_lat = EXCLUDED.location_lat,
         location_lng = EXCLUDED.location_lng,
         location_address = EXCLUDED.location_address,
         status = 'pending_admin_review'`,
      [
        profileId,
        userId,
        p.businessName || null,
        p.commercialRegistration || null,
        phone,
        locationLat,
        locationLng,
        locationAddress || null,
      ]
    );

    const effectiveProfile = (await client.query('SELECT id FROM brand_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0]?.id;
    const requestId = id();
    await client.query(
      `INSERT INTO role_requests (id, user_id, role_type, role_profile_id, status, plan_type, request_data)
       VALUES ($1, $2, 'brand', $3, 'pending_admin_review', $4, $5::jsonb)`,
      [requestId, userId, effectiveProfile, p.planType || null, JSON.stringify(p)]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, requestId, status: 'pending_admin_review' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'brand_request_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/roles/requests/me', auth, async (req, res) => {
  const userId = req.user.userId;
  try {
    const rows = (await pool.query(
      `SELECT id, role_type, status, plan_type, rejection_reason, created_at, reviewed_at
         FROM role_requests
        WHERE user_id = $1
        ORDER BY created_at DESC`,
      [userId]
    )).rows;
    return res.json(rows.map((row) => ({
      id: row.id,
      roleType: row.role_type,
      status: row.status,
      planType: row.plan_type,
      rejectionReason: row.rejection_reason,
      createdAt: toIso(row.created_at),
      reviewedAt: toIso(row.reviewed_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'role_requests_fetch_failed', details: String(e.message || e) });
  }
});

app.get('/api/admin/role-requests', auth, requireAdmin, async (req, res) => {
  const requestedStatus = String(req.query.status || '').trim();
  const status = requestedStatus || 'pending_admin_review';
  try {
    const rows = (await pool.query(
      `SELECT
         rr.id,
         rr.user_id,
         rr.role_type,
         rr.role_profile_id,
         rr.status,
         rr.plan_type,
         rr.request_data,
         rr.rejection_reason,
         rr.created_at,
         rr.reviewed_at,
         COALESCE(mp.business_name, bp.business_name) AS business_name,
         COALESCE(mp.commercial_registration, bp.commercial_registration) AS commercial_registration,
         COALESCE(mp.phone, bp.phone) AS phone,
         COALESCE(mp.location_lat, bp.location_lat) AS location_lat,
         COALESCE(mp.location_lng, bp.location_lng) AS location_lng,
         COALESCE(mp.location_address, bp.location_address) AS location_address
       FROM role_requests rr
       LEFT JOIN merchant_profiles mp
         ON rr.role_type = 'merchant'
        AND rr.role_profile_id = mp.id
       LEFT JOIN brand_profiles bp
         ON rr.role_type = 'brand'
        AND rr.role_profile_id = bp.id
      WHERE rr.status = $1
      ORDER BY rr.created_at DESC`,
      [status]
    )).rows;

    return res.json(rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      roleType: row.role_type,
      roleProfileId: row.role_profile_id,
      status: row.status,
      planType: row.plan_type,
      requestData: row.request_data || {},
      category: row.request_data?.category || null,
      workingHours: row.request_data?.workingHours || null,
      rejectionReason: row.rejection_reason,
      businessName: row.business_name,
      commercialRegistration: row.commercial_registration,
      phone: row.phone,
      locationLat: row.location_lat == null ? null : Number(row.location_lat),
      locationLng: row.location_lng == null ? null : Number(row.location_lng),
      locationAddress: row.location_address,
      createdAt: toIso(row.created_at),
      reviewedAt: toIso(row.reviewed_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'admin_role_requests_fetch_failed', details: String(e.message || e) });
  }
});

app.post('/api/admin/role-requests/:id/approve', auth, requireAdmin, async (req, res) => {
  const requestId = req.params.id;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const requestRow = (await client.query('SELECT * FROM role_requests WHERE id = $1 LIMIT 1', [requestId])).rows[0];
    if (!requestRow) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'role_request_not_found' });
    }

    const trialDays = await getIntSetting(client, 'trial_duration_days_default', 30);
    const trialStart = new Date();
    const trialEnd = new Date(trialStart.getTime() + trialDays * 24 * 60 * 60 * 1000);

    await client.query(
      `UPDATE role_requests
          SET status = 'approved', reviewed_at = NOW(), rejection_reason = NULL
        WHERE id = $1`,
      [requestId]
    );

    if (requestRow.role_type === 'merchant') {
      await client.query(
        `UPDATE merchant_profiles
            SET status = 'active'
          WHERE id = $1`,
        [requestRow.role_profile_id]
      );

      const merchantProfile = (await client.query(
        'SELECT business_name, user_id FROM merchant_profiles WHERE id = $1 LIMIT 1',
        [requestRow.role_profile_id]
      )).rows[0];
      await ensureCommunityGroupForRole(
        client,
        'merchant',
        requestRow.role_profile_id,
        merchantProfile?.user_id || requestRow.user_id,
        merchantProfile?.business_name || 'Merchant Community'
      );
    }

    if (requestRow.role_type === 'brand') {
      await client.query(
        `UPDATE brand_profiles
            SET status = 'active'
          WHERE id = $1`,
        [requestRow.role_profile_id]
      );

      const brandProfile = (await client.query(
        'SELECT business_name, user_id FROM brand_profiles WHERE id = $1 LIMIT 1',
        [requestRow.role_profile_id]
      )).rows[0];
      await ensureCommunityGroupForRole(
        client,
        'brand',
        requestRow.role_profile_id,
        brandProfile?.user_id || requestRow.user_id,
        brandProfile?.business_name || 'Brand Community'
      );
    }

    await client.query(
      `INSERT INTO subscriptions (
         id, role_profile_id, role_type, plan_type, status,
         trial_duration_days, trial_start_date, trial_end_date, billing_cycle, next_billing_date
       ) VALUES ($1,$2,$3,$4,'trial',$5,$6,$7,'monthly',$7)`,
      [
        id(),
        requestRow.role_profile_id,
        requestRow.role_type,
        requestRow.plan_type,
        trialDays,
        trialStart.toISOString(),
        trialEnd.toISOString(),
      ]
    );

    await client.query('COMMIT');
    await insertNotification(
      pool,
      requestRow.user_id,
      'role_request_approved',
      'Role approved',
      `${requestRow.role_type} role was approved and activated.`,
      { roleType: requestRow.role_type, roleProfileId: requestRow.role_profile_id }
    );
    return res.json({ ok: true, status: 'approved', subscriptionStatus: 'trial' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'role_request_approve_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/role-requests/:id/reject', auth, requireAdmin, async (req, res) => {
  const requestId = req.params.id;
  const reason = String((req.body || {}).reason || '').trim() || 'Rejected by admin';
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const requestRow = (await client.query('SELECT * FROM role_requests WHERE id = $1 LIMIT 1', [requestId])).rows[0];
    if (!requestRow) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'role_request_not_found' });
    }

    await client.query(
      `UPDATE role_requests
          SET status = 'rejected', rejection_reason = $2, reviewed_at = NOW()
        WHERE id = $1`,
      [requestId, reason]
    );

    if (requestRow.role_type === 'merchant') {
      await client.query('UPDATE merchant_profiles SET status = $2 WHERE id = $1', [requestRow.role_profile_id, 'rejected']);
    }
    if (requestRow.role_type === 'brand') {
      await client.query('UPDATE brand_profiles SET status = $2 WHERE id = $1', [requestRow.role_profile_id, 'rejected']);
    }

    await client.query('COMMIT');
    return res.json({ ok: true, status: 'rejected', reason });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'role_request_reject_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/subscriptions/run-transitions', auth, requireAdmin, async (_req, res) => {
  try {
    await runSubscriptionTransitions();
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'subscription_transition_failed', details: String(e.message || e) });
  }
});

app.get('/api/admin/subscriptions', auth, requireAdmin, async (req, res) => {
  const roleType = normalizeRoleType(req.query.roleType);
  const status = String(req.query.status || '').trim();
  const filters = [];
  const params = [];
  if (roleType) {
    params.push(roleType);
    filters.push(`s.role_type = $${params.length}`);
  }
  if (status) {
    params.push(status);
    filters.push(`s.status = $${params.length}`);
  }
  const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
  const rows = (await pool.query(
    `SELECT s.id,
            s.role_profile_id,
            s.role_type,
            s.plan_type,
            s.status,
            s.trial_start_date,
            s.trial_end_date,
            s.next_billing_date,
            CASE
              WHEN s.role_type = 'merchant' THEN mp.user_id
              WHEN s.role_type = 'brand' THEN bp.user_id
              ELSE NULL
            END AS owner_user_id,
            CASE
              WHEN s.role_type = 'merchant' THEN mp.business_name
              WHEN s.role_type = 'brand' THEN bp.business_name
              ELSE NULL
            END AS owner_label
       FROM subscriptions s
       LEFT JOIN merchant_profiles mp ON s.role_type = 'merchant' AND mp.id = s.role_profile_id
       LEFT JOIN brand_profiles bp ON s.role_type = 'brand' AND bp.id = s.role_profile_id
       ${whereClause}
      ORDER BY s.updated_at DESC`,
    params
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    roleProfileId: row.role_profile_id,
    roleType: row.role_type,
    planType: row.plan_type,
    status: row.status,
    ownerUserId: row.owner_user_id,
    ownerLabel: row.owner_label,
    trialStartDate: toIso(row.trial_start_date),
    trialEndDate: toIso(row.trial_end_date),
    nextBillingDate: toIso(row.next_billing_date),
    accessMode: row.status === 'suspended' ? 'read_only' : 'full',
  })));
});

app.post('/api/admin/subscriptions/:id/expire-trial-now', auth, requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE subscriptions
          SET trial_end_date = NOW() - INTERVAL '1 minute',
              updated_at = NOW()
        WHERE id = $1`,
      [req.params.id]
    );
    await client.query('COMMIT');
    await runSubscriptionTransitions();
    const row = (await pool.query(
      'SELECT id, status, trial_end_date, next_billing_date FROM subscriptions WHERE id = $1 LIMIT 1',
      [req.params.id]
    )).rows[0];
    return res.json({ ok: true, id: row.id, status: row.status, trialEndDate: toIso(row.trial_end_date), nextBillingDate: toIso(row.next_billing_date) });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'subscription_expire_trial_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/subscriptions/:id/end-grace-now', auth, requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE subscriptions
          SET next_billing_date = NOW() - INTERVAL '1 minute',
              updated_at = NOW()
        WHERE id = $1`,
      [req.params.id]
    );
    await client.query('COMMIT');
    await runSubscriptionTransitions();
    const row = (await pool.query(
      'SELECT id, status, trial_end_date, next_billing_date FROM subscriptions WHERE id = $1 LIMIT 1',
      [req.params.id]
    )).rows[0];
    return res.json({ ok: true, id: row.id, status: row.status, trialEndDate: toIso(row.trial_end_date), nextBillingDate: toIso(row.next_billing_date) });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'subscription_end_grace_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/subscriptions/:id/activate-now', auth, requireAdmin, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const transition = await applySubscriptionTransition(client, req.params.id, 'active', {
      nextBillingDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
    await client.query('COMMIT');
    return res.json({ ok: true, ...transition });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'subscription_activate_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

function calculatePointsWithFraction(purchaseAmount, pointValue, existingFraction) {
  const pv = Number(pointValue);
  const amount = Number(purchaseAmount);
  const fraction = Number(existingFraction || 0);
  if (!Number.isFinite(pv) || pv <= 0 || !Number.isFinite(amount) || amount <= 0) {
    return { points: 0, newFraction: fraction };
  }
  const effective = amount + fraction;
  const points = Math.floor(effective / pv);
  const newFraction = Number((effective - points * pv).toFixed(6));
  return { points, newFraction };
}

async function getMerchantProfileIdByUser(client, userId) {
  const row = (await client.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0];
  return row ? row.id : null;
}

async function getBrandProfileIdByUser(client, userId) {
  const row = (await client.query('SELECT id FROM brand_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0];
  return row ? row.id : null;
}

function normalizeRoleType(value) {
  const v = String(value || '').trim().toLowerCase();
  if (v === 'merchant' || v === 'brand') return v;
  return null;
}

// Best-effort match: an OCR/AI-detected merchant name rarely matches a merchant_profiles
// row by exact ID, so compare the same normalized key used for invoice_scans.merchant_key.
async function resolveMerchantProfileIdByKey(client, merchantKey) {
  if (!merchantKey) return null;
  const rows = (await client.query(
    "SELECT id, business_name FROM merchant_profiles WHERE status = 'active'"
  )).rows;
  let best = null;
  for (const row of rows) {
    const profileKey = normalizeMerchantKey(row.business_name);
    if (!profileKey || profileKey.length < 4) continue;
    const matches = profileKey === merchantKey ||
      merchantKey.includes(profileKey) || profileKey.includes(merchantKey);
    if (matches && (!best || profileKey.length > best.length)) {
      best = { id: row.id, length: profileKey.length };
    }
  }
  return best?.id || null;
}

// Heuristic brand/product match for a scanned line item name (no AI call): looks for a
// substring match against active brands' product catalog and keeps the most specific hit.
async function autoMatchLineItemToBrand(client, itemName) {
  const normalizedItem = normalizeMerchantKey(itemName);
  if (normalizedItem.length < 4) return null;
  const rows = (await client.query(
    `SELECT pr.id AS product_id, pr.brand_id, pr.name
       FROM product_registry pr
       JOIN brand_profiles bp ON bp.id = pr.brand_id AND bp.status = 'active'`
  )).rows;
  let best = null;
  for (const row of rows) {
    const normalizedProduct = normalizeMerchantKey(row.name);
    if (normalizedProduct.length < 4) continue;
    if (normalizedItem.includes(normalizedProduct) || normalizedProduct.includes(normalizedItem)) {
      if (!best || normalizedProduct.length > best.matchLength) {
        best = { brandId: row.brand_id, productId: row.product_id, matchLength: normalizedProduct.length };
      }
    }
  }
  return best;
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

function matchesPeerAdCategory(targetCategory, merchantCategory) {
  const t = String(targetCategory || '').trim().toLowerCase();
  if (!t) return true;
  const m = String(merchantCategory || '').trim().toLowerCase();
  return t === m;
}

function parseGeoJson(raw) {
  if (!raw) return null;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(String(raw));
  } catch (_e) {
    return null;
  }
}

function matchesPeerAdGeo(geoJson, lat, lng) {
  const geo = parseGeoJson(geoJson);
  if (!geo || typeof geo !== 'object') return true;
  const centerLat = Number(geo.centerLat);
  const centerLng = Number(geo.centerLng);
  const maxDistanceKm = Number(geo.maxDistanceKm);
  if (!Number.isFinite(centerLat) || !Number.isFinite(centerLng) || !Number.isFinite(maxDistanceKm)) {
    return true;
  }
  const mLat = Number(lat);
  const mLng = Number(lng);
  if (!Number.isFinite(mLat) || !Number.isFinite(mLng)) return false;
  return haversineDistanceKm(mLat, mLng, centerLat, centerLng) <= maxDistanceKm;
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

app.get('/api/merchant/profile', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    const row = (await client.query(
      `SELECT id, user_id, business_name, commercial_registration, status, point_value
         FROM merchant_profiles
        WHERE id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0];
    if (!row) return res.status(404).json({ error: 'merchant_profile_not_found' });

    return res.json({
      id: row.id,
      userId: row.user_id,
      businessName: row.business_name,
      commercialRegistration: row.commercial_registration,
      status: row.status,
      pointValue: row.point_value == null ? null : Number(row.point_value),
    });
  } catch (e) {
    return res.status(500).json({ error: 'merchant_profile_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/merchant/settings/point-value', auth, async (req, res) => {
  const pointValue = Number((req.body || {}).pointValue);
  if (!Number.isFinite(pointValue) || pointValue <= 0) {
    return res.status(400).json({ error: 'invalid_point_value' });
  }

  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    await client.query(
      `UPDATE merchant_profiles
          SET point_value = $2
        WHERE id = $1`,
      [merchantId, pointValue]
    );
    return res.json({ ok: true, id: merchantId, pointValue });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'merchant_point_value_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/brand/profile', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });

    const row = (await client.query(
      `SELECT id, user_id, business_name, commercial_registration, status, point_value
         FROM brand_profiles
        WHERE id = $1
        LIMIT 1`,
      [brandId]
    )).rows[0];
    if (!row) return res.status(404).json({ error: 'brand_profile_not_found' });

    return res.json({
      id: row.id,
      userId: row.user_id,
      businessName: row.business_name,
      commercialRegistration: row.commercial_registration,
      status: row.status,
      pointValue: row.point_value == null ? null : Number(row.point_value),
    });
  } catch (e) {
    return res.status(500).json({ error: 'brand_profile_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/brand/settings/point-value', auth, async (req, res) => {
  const pointValue = Number((req.body || {}).pointValue);
  if (!Number.isFinite(pointValue) || pointValue <= 0) {
    return res.status(400).json({ error: 'invalid_point_value' });
  }

  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });

    await client.query(
      `UPDATE brand_profiles
          SET point_value = $2
        WHERE id = $1`,
      [brandId, pointValue]
    );
    return res.json({ ok: true, id: brandId, pointValue });
  } catch (e) {
    return res.status(500).json({ error: 'brand_point_value_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/branches', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);
    const p = req.body || {};
    const name = String(p.name || '').trim();
    const latitude = Number(p.latitude);
    const longitude = Number(p.longitude);
    if (!name) return res.status(400).json({ error: 'branch_name_required' });
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return res.status(400).json({ error: 'branch_geo_location_required' });
    }
    const branchId = id();
    await client.query(
      `INSERT INTO branches (id, merchant_id, name, address, location, latitude, longitude, category, working_hours, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,COALESCE($10,'active'))`,
      [
        branchId,
        merchantId,
        name,
        p.address || null,
        p.location || null,
        latitude,
        longitude,
        p.category || null,
        p.workingHours || null,
        p.status || null,
      ]
    );
    return res.status(201).json({
      ok: true,
      id: branchId,
      latitude,
      longitude,
      category: p.category || null,
      workingHours: p.workingHours || null,
    });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'branch_create_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/branches', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    const rows = (await client.query('SELECT * FROM branches WHERE merchant_id = $1 ORDER BY created_at DESC', [merchantId])).rows;
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ error: 'branch_list_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/merchant/branches/:id', auth, async (req, res) => {
  const branchId = String(req.params.id || '').trim();
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);
    const p = req.body || {};
    const result = await client.query(
      `UPDATE branches
          SET name = COALESCE($1, name), address = COALESCE($2, address),
              working_hours = COALESCE($3, working_hours), phone = COALESCE($4, phone),
              updated_at = NOW()
        WHERE id = $5 AND merchant_id = $6
        RETURNING *`,
      [p.name == null ? null : String(p.name).trim(), p.address == null ? null : String(p.address).trim(), p.workingHours == null ? null : String(p.workingHours).trim(), p.phone == null ? null : String(p.phone).trim(), branchId, merchantId]
    );
    if (!result.rowCount) return res.status(404).json({ error: 'branch_not_found' });
    return res.json({ ok: true, branch: result.rows[0] });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) return res.status(403).json({ error: 'merchant_subscription_read_only' });
    return res.status(500).json({ error: 'branch_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/branches/:id/managers', auth, async (req, res) => {
  const branchId = String(req.params.id || '').trim();
  const userId = String((req.body || {}).userId || '').trim();
  const client = await pool.connect();
  try {
    if (!branchId) return res.status(400).json({ error: 'branchId_required' });
    if (!userId) return res.status(400).json({ error: 'userId_required' });
    const branch = (await client.query('SELECT * FROM branches WHERE id = $1 LIMIT 1', [branchId])).rows[0];
    if (!branch) return res.status(404).json({ error: 'branch_not_found' });
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId || branch.merchant_id !== merchantId) return res.status(403).json({ error: 'forbidden' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    await client.query(
      `INSERT INTO branch_manager_permissions (branch_id, user_id)
       VALUES ($1,$2)
       ON CONFLICT (branch_id, user_id) DO NOTHING`,
      [branchId, userId]
    );
    return res.json({ ok: true });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'manager_add_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/cashiers/bind', auth, async (req, res) => {
  const p = req.body || {};
  let cashierUserId = String(p.cashierUserId || '').trim();
  const cashierPhone = String(p.cashierPhone || '').trim();
  const branchId = String(p.branchId || '').trim();
  if (!branchId || (!cashierUserId && !cashierPhone)) {
    return res.status(400).json({ error: 'cashierUserId_or_cashierPhone_and_branchId_required' });
  }
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    const branch = (await client.query('SELECT id, merchant_id FROM branches WHERE id = $1 LIMIT 1', [branchId])).rows[0];
    if (!branch) return res.status(404).json({ error: 'branch_not_found' });
    if (branch.merchant_id !== merchantId) return res.status(403).json({ error: 'forbidden' });

    if (!cashierUserId && cashierPhone) {
      const userByPhone = (await client.query(
        'SELECT id FROM users WHERE phone = $1 LIMIT 1',
        [cashierPhone]
      )).rows[0];
      if (!userByPhone) return res.status(404).json({ error: 'cashier_phone_not_found' });
      cashierUserId = userByPhone.id;
    }

    const existing = (await client.query(
      'SELECT id FROM cashier_profiles WHERE user_id = $1 AND branch_id = $2 LIMIT 1',
      [cashierUserId, branchId]
    )).rows[0];
    if (existing) {
      await client.query('UPDATE cashier_profiles SET is_active = TRUE WHERE id = $1', [existing.id]);
      return res.json({ ok: true, id: existing.id, reactivated: true });
    }

    const cashierId = id();
    await client.query(
      `INSERT INTO cashier_profiles (id, user_id, merchant_id, branch_id, is_active)
       VALUES ($1,$2,$3,$4,TRUE)`,
      [cashierId, cashierUserId, merchantId, branchId]
    );
    return res.json({ ok: true, id: cashierId, cashierUserId, cashierPhone: cashierPhone || null });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'cashier_bind_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.patch('/api/merchant/branches/:id/managers/:userId/permissions', auth, async (req, res) => {
  const branchId = req.params.id;
  const managerId = req.params.userId;
  const p = req.body || {};
  const client = await pool.connect();
  try {
    const branch = (await client.query('SELECT * FROM branches WHERE id = $1 LIMIT 1', [branchId])).rows[0];
    if (!branch) return res.status(404).json({ error: 'branch_not_found' });
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId || branch.merchant_id !== merchantId) return res.status(403).json({ error: 'forbidden' });
    await assertMerchantSubscriptionWritable(client, merchantId);

    await client.query(
      `UPDATE branch_manager_permissions
          SET can_review_invoices = COALESCE($3, can_review_invoices),
              can_create_offers = COALESCE($4, can_create_offers),
              can_manage_group = COALESCE($5, can_manage_group),
              can_view_reports = COALESCE($6, can_view_reports),
              can_view_settlements = COALESCE($7, can_view_settlements),
              can_add_cashiers = COALESCE($8, can_add_cashiers),
              can_reply_reports = COALESCE($9, can_reply_reports),
              can_edit_point_value = COALESCE($10, can_edit_point_value)
        WHERE branch_id = $1 AND user_id = $2`,
      [
        branchId,
        managerId,
        p.canReviewInvoices,
        p.canCreateOffers,
        p.canManageGroup,
        p.canViewReports,
        p.canViewSettlements,
        p.canAddCashiers,
        p.canReplyReports,
        p.canEditPointValue,
      ]
    );
    return res.json({ ok: true });
  } catch (e) {
    if (isMerchantSubscriptionReadOnlyError(e)) {
      return res.status(403).json({ error: 'merchant_subscription_read_only' });
    }
    return res.status(500).json({ error: 'permissions_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/manager/scope', auth, async (req, res) => {
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    const rows = (await client.query(
      `SELECT
         bmp.branch_id,
         b.name AS branch_name,
         mp.id AS merchant_id,
         mp.business_name AS merchant_name,
         bmp.can_review_invoices,
         bmp.can_create_offers,
         bmp.can_manage_group,
         bmp.can_view_reports,
         bmp.can_view_settlements,
         bmp.can_add_cashiers,
         bmp.can_reply_reports,
         bmp.can_edit_point_value
       FROM branch_manager_permissions bmp
       JOIN branches b ON b.id = bmp.branch_id
       JOIN merchant_profiles mp ON mp.id = b.merchant_id
      WHERE bmp.user_id = $1
      ORDER BY b.created_at DESC`,
      [userId]
    )).rows;

    const sections = {
      invoiceReview: rows.some((r) => r.can_review_invoices === true),
      offers: rows.some((r) => r.can_create_offers === true),
      groupManagement: rows.some((r) => r.can_manage_group === true),
      reports: rows.some((r) => r.can_view_reports === true),
      settlements: rows.some((r) => r.can_view_settlements === true),
      cashierManagement: rows.some((r) => r.can_add_cashiers === true),
      reportReplies: rows.some((r) => r.can_reply_reports === true),
      pointValueEdit: rows.some((r) => r.can_edit_point_value === true),
    };

    return res.json({
      manager: rows.length > 0,
      sections,
      branches: rows.map((r) => ({
        branchId: r.branch_id,
        branchName: r.branch_name,
        merchantId: r.merchant_id,
        merchantName: r.merchant_name,
      })),
    });
  } catch (e) {
    return res.status(500).json({ error: 'manager_scope_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/manager/invoices/review-queue', auth, async (req, res) => {
  const userId = req.user.userId;
  const client = await pool.connect();
  try {
    const managedMerchantRows = (await client.query(
      `SELECT DISTINCT b.merchant_id
         FROM branch_manager_permissions bmp
         JOIN branches b ON b.id = bmp.branch_id
        WHERE bmp.user_id = $1
          AND bmp.can_review_invoices = TRUE`,
      [userId]
    )).rows;

    if (!managedMerchantRows.length) {
      return res.status(403).json({ error: 'manager_invoice_review_permission_required' });
    }

    const merchantIds = managedMerchantRows.map((r) => r.merchant_id);
    const invoiceRows = (await client.query(
      `SELECT id, owner_id, merchant_name, invoice_number, invoice_date, total_amount, currency, state, created_at
         FROM invoice_scans
        WHERE merchant_profile_id = ANY($1::text[])
          AND state IN ('processing', 'approved', 'rejected', 'disputed')
        ORDER BY created_at DESC
        LIMIT 100`,
      [merchantIds]
    )).rows;

    return res.json(invoiceRows.map((r) => ({
      id: r.id,
      ownerId: r.owner_id,
      merchantName: r.merchant_name,
      invoiceNumber: r.invoice_number,
      invoiceDate: r.invoice_date,
      totalAmount: r.total_amount,
      currency: r.currency,
      state: r.state,
      createdAt: toIso(r.created_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'manager_invoice_queue_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/brand/team-members', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
    const p = req.body || {};
    const userId = String(p.userId || '').trim();
    if (!userId) return res.status(400).json({ error: 'userId_required' });
    await client.query(
      `INSERT INTO brand_team_members (brand_id, user_id, can_manage_products, can_view_geo_distribution)
       VALUES ($1,$2,COALESCE($3,FALSE),COALESCE($4,FALSE))
       ON CONFLICT (brand_id, user_id)
       DO UPDATE SET
         can_manage_products = EXCLUDED.can_manage_products,
         can_view_geo_distribution = EXCLUDED.can_view_geo_distribution`,
      [brandId, userId, p.canManageProducts, p.canViewGeoDistribution]
    );
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'brand_team_member_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/wallet/cashback-v2', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const userId = req.user.userId;
    const p = req.body || {};
    const merchantId = String(p.merchantId || '').trim();
    const purchaseAmount = Number(p.purchaseAmount || 0);
    if (!merchantId || !Number.isFinite(purchaseAmount) || purchaseAmount <= 0) {
      return res.status(400).json({ error: 'invalid_payload' });
    }

    const merchant = (await client.query('SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [merchantId])).rows[0];
    const pointValue = Number(merchant?.point_value || 0);

    await client.query(
      `INSERT INTO customer_merchant_fraction_balance (customer_id, merchant_id, fraction_balance)
       VALUES ($1,$2,0)
       ON CONFLICT (customer_id, merchant_id) DO NOTHING`,
      [userId, merchantId]
    );

    const bal = (await client.query(
      'SELECT fraction_balance FROM customer_merchant_fraction_balance WHERE customer_id = $1 AND merchant_id = $2 FOR UPDATE',
      [userId, merchantId]
    )).rows[0];

    const calc = calculatePointsWithFraction(purchaseAmount, pointValue, bal?.fraction_balance || 0);

    await client.query(
      'UPDATE customer_merchant_fraction_balance SET fraction_balance = $3, updated_at = NOW() WHERE customer_id = $1 AND merchant_id = $2',
      [userId, merchantId, calc.newFraction]
    );

    await client.query(
      `INSERT INTO points_ledger_merchant (id, customer_id, merchant_id, points_delta, fraction_before, fraction_after, status, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,'active',NOW() + INTERVAL '12 months')`,
      [id(), userId, merchantId, calc.points, Number(bal?.fraction_balance || 0), calc.newFraction]
    );

    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW() WHERE owner_id = $1', [userId, calc.points]);
    await client.query('UPDATE users SET points = points + $2, points_history = points_history || to_jsonb($2::int) WHERE id = $1', [userId, calc.points]);
    await insertNotification(
      client,
      userId,
      'points_confirmed',
      'Points added',
      `You earned ${calc.points} point(s).`,
      { merchantId, points: calc.points, fraction: calc.newFraction }
    );

    return res.json({ ok: true, points: calc.points, fraction: calc.newFraction });
  } catch (e) {
    return res.status(500).json({ error: 'cashback_v2_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/wallet/refund-deduction', auth, async (req, res) => {
  const userId = req.user.userId;
  const points = Number((req.body || {}).points || 0);
  if (!Number.isFinite(points) || points <= 0) {
    return res.status(400).json({ error: 'invalid_points' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE point_accounts SET available_points = GREATEST(available_points - $2, 0), updated_at = NOW() WHERE owner_id = $1', [userId, points]);
    await client.query('UPDATE users SET points = GREATEST(points - $2, 0) WHERE id = $1', [userId, points]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'refundDeduction', 0, points, 'refund']);
    await client.query('COMMIT');
    return res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'refund_deduction_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/points/expire/run', auth, requireAdmin, async (_req, res) => {
  try {
    const expiringSoonRows = (await pool.query(
      `SELECT customer_id, merchant_id, expires_at
         FROM points_ledger_merchant
        WHERE status = 'active'
          AND expires_at > NOW()
          AND expires_at <= NOW() + INTERVAL '7 days'
        ORDER BY expires_at ASC
        LIMIT 500`
    )).rows;
    for (const row of expiringSoonRows) {
      await insertNotification(
        pool,
        row.customer_id,
        'points_expiry_soon',
        'Points expiring soon',
        'Some of your merchant points will expire within 7 days.',
        { merchantId: row.merchant_id, expiresAt: toIso(row.expires_at) }
      );
    }

    await pool.query("UPDATE points_ledger_merchant SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()");
    await pool.query("UPDATE points_ledger_brand SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()");
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'points_expire_failed', details: String(e.message || e) });
  }
});

// Issues a short-lived, single-use signed token identifying the calling customer,
// meant to be rendered as a QR code and scanned by a cashier to grant points.
// Signed with POS_GRANT_TOKEN_SECRET (independent of the session JWT_SECRET) so it
// cannot be replayed as a login/session token, and cannot be forged without the secret.
app.post('/api/customer/pos-qr-token', auth, async (req, res) => {
  const customerId = req.user.userId;
  const nonce = id();
  const token = jwt.sign(
    { customerId, nonce, purpose: 'pos_grant' },
    POS_GRANT_TOKEN_SECRET,
    { expiresIn: POS_GRANT_TOKEN_TTL_SECONDS }
  );
  return res.json({
    token,
    expiresInSeconds: POS_GRANT_TOKEN_TTL_SECONDS,
    expiresAt: new Date(Date.now() + POS_GRANT_TOKEN_TTL_SECONDS * 1000).toISOString(),
  });
});

app.post('/api/cashier/grant-points', auth, async (req, res) => {
  const userId = req.user.userId;
  const p = req.body || {};
  const branchId = String(p.branchId || '').trim();
  const qrToken = String(p.qrToken || '').trim();
  const manualOverride = p.manualOverride === true;
  const manualOverrideReason = String(p.manualOverrideReason || '').trim();
  const purchaseAmount = Number(p.purchaseAmount || 0);

  if (!branchId || !Number.isFinite(purchaseAmount) || purchaseAmount <= 0) {
    return res.status(400).json({ error: 'invalid_payload' });
  }

  // Primary path: a real, signed, single-use QR token scanned from the customer's device.
  // Fallback path: manual customerId entry, only allowed when explicitly flagged as an
  // override (camera failure etc.) — every manual grant is logged for merchant/admin review.
  let customerId = '';
  let tokenNonce = '';
  if (qrToken) {
    let decoded;
    try {
      decoded = jwt.verify(qrToken, POS_GRANT_TOKEN_SECRET);
    } catch (e) {
      if (e && e.name === 'TokenExpiredError') {
        return res.status(400).json({ error: 'qr_token_expired' });
      }
      return res.status(400).json({ error: 'qr_token_invalid' });
    }
    if (decoded.purpose !== 'pos_grant' || !decoded.customerId || !decoded.nonce) {
      return res.status(400).json({ error: 'qr_token_invalid' });
    }
    customerId = String(decoded.customerId);
    tokenNonce = String(decoded.nonce);
    // Consume the nonce immediately and atomically: a second scan of the same QR, whether
    // concurrent or after this request finishes, always fails the unique-key insert below.
    try {
      await pool.query(
        'INSERT INTO pos_grant_token_uses (nonce, customer_id) VALUES ($1,$2)',
        [tokenNonce, customerId]
      );
    } catch (_e) {
      return res.status(409).json({ error: 'qr_token_already_used' });
    }
  } else if (manualOverride) {
    customerId = String(p.customerId || '').trim();
    if (!customerId || !manualOverrideReason) {
      return res.status(400).json({ error: 'manual_override_reason_required' });
    }
  } else {
    return res.status(400).json({ error: 'qr_token_or_manual_override_required' });
  }

  const cashier = (await pool.query(
    'SELECT * FROM cashier_profiles WHERE user_id = $1 AND branch_id = $2 AND is_active = TRUE LIMIT 1',
    [userId, branchId]
  )).rows[0];
  if (!cashier) return res.status(403).json({ error: 'cashier_not_authorized' });
  const merchantId = cashier.merchant_id;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const merchant = (await client.query('SELECT business_name, point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [merchantId])).rows[0];
    const pointValue = Number(merchant?.point_value || 0);

    // Fraud control parity with the OCR invoice path: same daily-limit rule applies
    // to POS/cashier-granted purchases, since both paths feed the same Points Engine.
    const dailyLimit = await getIntSetting(pool, 'daily_invoice_limit', 10);
    const dailyCount = (await client.query(
      `SELECT COUNT(*)::int AS c
         FROM invoice_scans
        WHERE owner_id = $1
          AND created_at >= date_trunc('day', NOW())`,
      [customerId]
    )).rows[0]?.c || 0;
    if (dailyCount >= dailyLimit) {
      await client.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), customerId, 'daily_invoice_limit_reached', JSON.stringify({ dailyCount, dailyLimit, source: 'cashier_grant' })]);
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'daily_invoice_limit_reached' });
    }

    if (manualOverride) {
      await client.query(
        'INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)',
        [id(), customerId, 'pos_manual_override_used', JSON.stringify({ branchId, purchaseAmount, reason: manualOverrideReason, cashierUserId: userId })]
      );
    }

    await client.query(
      `INSERT INTO customer_merchant_fraction_balance (customer_id, merchant_id, fraction_balance)
       VALUES ($1,$2,0)
       ON CONFLICT (customer_id, merchant_id) DO NOTHING`,
      [customerId, merchantId]
    );

    const bal = (await client.query(
      'SELECT fraction_balance FROM customer_merchant_fraction_balance WHERE customer_id = $1 AND merchant_id = $2 FOR UPDATE',
      [customerId, merchantId]
    )).rows[0];

    const calc = calculatePointsWithFraction(purchaseAmount, pointValue, bal?.fraction_balance || 0);
    await client.query(
      'UPDATE customer_merchant_fraction_balance SET fraction_balance = $3, updated_at = NOW() WHERE customer_id = $1 AND merchant_id = $2',
      [customerId, merchantId, calc.newFraction]
    );

    // Record the POS sale itself as an approved invoice_scans row (category='pos') so it
    // is included in merchant/admin "sales" analytics exactly like an OCR-approved invoice.
    // Previously this endpoint only wrote to points_ledger_merchant, which meant cashier-
    // granted points showed up in "pointsAwarded" while "sales" stayed at 0 for the same purchase.
    const scanId = id();
    await client.query(
      `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, invoice_date, total_amount, currency, category, raw_text, reward_applied, merchant_profile_id, branch_id, state, pos_manual_override)
       VALUES ($1,$2,$3,$4,CURRENT_DATE,$5,'SAR','pos',$8,TRUE,$6,$7,'approved',$9)`,
      [
        scanId, customerId, merchant?.business_name || null, normalizeMerchantKey(merchant?.business_name || 'merchant'),
        purchaseAmount, merchantId, branchId,
        manualOverride ? `Cashier-entered POS purchase (manual override): ${manualOverrideReason}` : 'Cashier-entered POS purchase (QR scan)',
        manualOverride,
      ]
    );

    await client.query(
      `INSERT INTO points_ledger_merchant (id, customer_id, merchant_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months')`,
      [id(), customerId, merchantId, scanId, calc.points, Number(bal?.fraction_balance || 0), calc.newFraction]
    );
    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [customerId]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $2, lifetime_points = lifetime_points + $2, updated_at = NOW() WHERE owner_id = $1', [customerId, calc.points]);
    await client.query('UPDATE users SET points = points + $2, points_history = points_history || to_jsonb($2::int) WHERE id = $1', [customerId, calc.points]);
    await insertNotification(
      client,
      customerId,
      'points_confirmed',
      'Points added',
      `Cashier granted ${calc.points} point(s).`,
      { merchantId, branchId, points: calc.points, fraction: calc.newFraction }
    );

    await client.query('COMMIT');
    return res.json({ ok: true, points: calc.points, fraction: calc.newFraction });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'cashier_grant_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});


app.post('/api/invoices/scan-v2', auth, async (req, res) => {
  const p = req.body || {};
  const ownerId = req.user.userId;
  const invoiceDate = parseFlexibleDate(p.invoiceDate || p.date);
  if (!invoiceDate) return res.status(400).json({ error: 'invalid_invoice_date' });
  const ageHours = (Date.now() - invoiceDate.getTime()) / (1000 * 60 * 60);
  if (ageHours > 48) {
    await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'invoice_older_than_48h', JSON.stringify({ invoiceDate: p.invoiceDate || p.date })]);
    return res.status(400).json({ error: 'invoice_too_old' });
  }

  const limit = await getIntSetting(pool, 'daily_invoice_limit', 10);
  const daily = (await pool.query(
    `SELECT COUNT(*)::int AS c
       FROM invoice_scans
      WHERE owner_id = $1
        AND created_at >= date_trunc('day', NOW())`,
    [ownerId]
  )).rows[0]?.c || 0;
  if (daily >= limit) {
    await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'daily_invoice_limit_reached', JSON.stringify({ daily, limit })]);
    return res.status(400).json({ error: 'daily_invoice_limit_reached' });
  }

  const invoiceNumber = String(p.invoiceNumber || '').trim();
  if (invoiceNumber) {
    const exists = (await pool.query('SELECT 1 FROM invoice_scans WHERE invoice_number = $1 LIMIT 1', [invoiceNumber])).rows[0];
    if (exists) {
      await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'duplicate_reference_any_account', JSON.stringify({ invoiceNumber })]);
      return res.status(409).json({ error: 'duplicate_reference' });
    }
  }

  const rawImageHash = String(p.imageHash || '').trim();
  if (rawImageHash) {
    const similar = (await pool.query('SELECT 1 FROM invoice_scans WHERE image_hash = $1 LIMIT 1', [rawImageHash])).rows[0];
    if (similar) {
      await pool.query('INSERT INTO fraud_flags (id, owner_id, reason, details) VALUES ($1,$2,$3,$4::jsonb)', [id(), ownerId, 'suspected_image_modification', JSON.stringify({ imageHash: rawImageHash })]);
      return res.status(409).json({ error: 'suspected_image_modification' });
    }
  }

  const retentionMonths = await getIntSetting(pool, 'invoice_retention_months', 24);
  const retentionDate = new Date();
  retentionDate.setMonth(retentionDate.getMonth() + retentionMonths);
  const merchantProfileId = String(p.merchantProfileId || '').trim() || null;
  const branchId = String(p.branchId || '').trim() || null;

  const scanId = id();
  await pool.query(
    `INSERT INTO invoice_scans (id, owner_id, merchant_name, merchant_key, invoice_number, order_number, invoice_date, total_amount, currency, category, raw_text, reward_applied, image_hash, retention_expires_at, merchant_profile_id, branch_id, state)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,COALESCE($9,'SAR'),COALESCE($10,'general'),COALESCE($11,''),FALSE,$12,$13,$14,$15,'processing')`,
    [
      scanId,
      ownerId,
      p.merchantName || null,
      normalizeMerchantKey(p.merchantName || p.merchantKey || 'merchant'),
      invoiceNumber || null,
      p.orderNumber || null,
      invoiceDate.toISOString().slice(0, 10),
      p.totalAmount || null,
      p.currency || 'SAR',
      p.category || 'general',
      p.rawText || '',
      rawImageHash || null,
      retentionDate.toISOString(),
      merchantProfileId,
      branchId,
    ]
  );

  return res.json({ ok: true, id: scanId, state: 'processing' });
});

app.post('/api/admin/data-retention/run', auth, requireAdmin, async (_req, res) => {
  try {
    await pool.query("UPDATE invoice_scans SET raw_text = '' WHERE retention_expires_at IS NOT NULL AND retention_expires_at < NOW()");
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'retention_purge_failed', details: String(e.message || e) });
  }
});

app.post('/api/brand/products', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
    const p = req.body || {};
    const productId = id();
    await client.query(
      'INSERT INTO product_registry (id, brand_id, name, image_url, barcode) VALUES ($1,$2,$3,$4,$5)',
      [productId, brandId, String(p.name || '').trim(), p.imageUrl || null, p.barcode || null]
    );
    return res.json({ ok: true, id: productId });
  } catch (e) {
    return res.status(500).json({ error: 'product_create_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/line-items', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const items = Array.isArray((req.body || {}).items) ? req.body.items : [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const access = await canManageInvoice(client, req.user, invoiceId);
    if (!access.allowed) {
      await client.query('ROLLBACK');
      return res.status(access.status).json({ error: access.error });
    }
    const createdLineItemIds = [];
    for (const item of items) {
      const lineId = id();
      createdLineItemIds.push(lineId);
      await client.query(
        'INSERT INTO invoice_line_items (id, invoice_scan_id, item_name, quantity, unit_price, line_total) VALUES ($1,$2,$3,$4,$5,$6)',
        [lineId, invoiceId, String(item.name || '').trim(), item.quantity || null, item.unitPrice || null, item.lineTotal || null]
      );
    }
    await client.query('COMMIT');
    return res.json({ ok: true, count: items.length, lineItemIds: createdLineItemIds });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'invoice_line_items_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/brand-matches', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const matches = Array.isArray((req.body || {}).matches) ? req.body.matches : [];
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const access = await canManageInvoice(client, req.user, invoiceId);
    if (!access.allowed) {
      await client.query('ROLLBACK');
      return res.status(access.status).json({ error: access.error });
    }
    for (const match of matches) {
      const lineItemId = String(match.invoiceLineItemId || '').trim();
      const brandId = String(match.brandId || '').trim();
      if (!lineItemId || !brandId) continue;
      await client.query(
        `INSERT INTO brand_matches (id, invoice_line_item_id, brand_id, product_id, confidence)
         VALUES ($1, $2, $3, $4, COALESCE($5, 0))`,
        [id(), lineItemId, brandId, match.productId || null, Number(match.confidence || 0)]
      );
    }
    await client.query('COMMIT');
    return res.json({ ok: true, count: matches.length, invoiceId });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'brand_match_persist_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/state-transition', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const to = String((req.body || {}).to || '').trim();
  const note = String((req.body || {}).note || (req.body || {}).reason || '').trim();
  const allowed = {
    uploaded: ['processing'],
    processing: ['approved', 'rejected', 'manual_review'],
    manual_review: ['approved', 'rejected'],
    rejected: ['disputed'],
    disputed: ['dispute_upheld', 'dispute_denied'],
    dispute_upheld: ['approved'],
    dispute_denied: ['closed_rejected'],
  };
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const access = await canManageInvoice(client, req.user, invoiceId, to);
    if (!access.allowed) {
      await client.query('ROLLBACK');
      return res.status(access.status).json({ error: access.error });
    }
    const row = (await client.query('SELECT state FROM invoice_scans WHERE id = $1 LIMIT 1', [invoiceId])).rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'invoice_not_found' });
    }
    const from = row.state || 'uploaded';
    const list = allowed[from] || [];
    if (!list.includes(to)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'invalid_transition', from, to });
    }

    await client.query(
      `UPDATE invoice_scans
          SET state = $2,
              review_note = COALESCE(NULLIF($3, ''), review_note)
        WHERE id = $1`,
      [invoiceId, to, note]
    );

    const invoiceRow = (await client.query(
      'SELECT owner_id, merchant_profile_id FROM invoice_scans WHERE id = $1 LIMIT 1',
      [invoiceId]
    )).rows[0];

    let awards = null;
    if (invoiceRow) {
      if (to === 'approved') {
        awards = await applyInvoiceApprovalRewards(client, invoiceId, invoiceRow.owner_id, invoiceRow.merchant_profile_id);
        if (invoiceRow.merchant_profile_id) {
          await joinCustomerToMerchantCommunity(client, invoiceRow.owner_id, invoiceRow.merchant_profile_id);
        }
        await joinCustomerToBrandCommunities(client, invoiceRow.owner_id, invoiceId);
        await insertNotification(
          client,
          invoiceRow.owner_id,
          'invoice_approved',
          'Invoice approved',
          'Your invoice has been approved.',
          { invoiceId }
        );
      }
      if (to === 'rejected') {
        await insertNotification(
          client,
          invoiceRow.owner_id,
          'invoice_rejected',
          'Invoice rejected',
          'Your invoice has been rejected. You can dispute it if needed.',
          { invoiceId, note: note || null }
        );
      }
    }

    await client.query('COMMIT');
    return res.json({ ok: true, from, to, note: note || null, awards });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'invoice_transition_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/:id/disputes', auth, async (req, res) => {
  const invoiceId = req.params.id;
  const ownerId = req.user.userId;
  const reason = String((req.body || {}).reason || '').trim();
  const evidence = String((req.body || {}).evidence || '').trim() || null;
  if (!reason) return res.status(400).json({ error: 'reason_required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const invoice = (await client.query(
      'SELECT owner_id, state FROM invoice_scans WHERE id = $1 LIMIT 1',
      [invoiceId]
    )).rows[0];
    if (!invoice) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'invoice_not_found' });
    }
    if (invoice.owner_id !== ownerId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'invoice_owner_required' });
    }
    if (invoice.state !== 'rejected') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'invoice_not_rejected' });
    }

    const disputeId = id();
    await client.query(
      `INSERT INTO disputes (id, owner_id, invoice_scan_id, status, reason)
       VALUES ($1,$2,$3,'new',$4)`,
      [disputeId, ownerId, invoiceId, evidence ? `${reason}\n${evidence}` : reason]
    );
    await client.query(
      `UPDATE invoice_scans
          SET state = 'disputed',
              review_note = COALESCE(review_note, '') || CASE WHEN review_note IS NULL OR review_note = '' THEN '' ELSE E'\n' END || $2
        WHERE id = $1`,
      [invoiceId, `DISPUTE: ${reason}`]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, id: disputeId, status: 'new' });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'create_dispute_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/invoices/disputes', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    const status = String(req.query.status || 'new').trim() || 'new';
    const rows = (await client.query(
      `SELECT d.id,
              d.invoice_scan_id,
              d.status,
              d.reason,
              d.created_at,
              d.updated_at,
              s.owner_id,
              s.invoice_number,
              s.total_amount,
              s.state,
              s.merchant_name,
              COALESCE(u.full_name, u.email) AS owner_label
         FROM disputes d
         JOIN invoice_scans s ON s.id = d.invoice_scan_id
         LEFT JOIN users u ON u.id = s.owner_id
        WHERE s.merchant_profile_id = $1
          AND d.status = $2
        ORDER BY d.created_at DESC
        LIMIT 100`,
      [merchantId, status]
    )).rows;
    return res.json(rows.map((r) => ({
      id: r.id,
      invoiceId: r.invoice_scan_id,
      status: r.status,
      reason: r.reason,
      createdAt: toIso(r.created_at),
      updatedAt: toIso(r.updated_at),
      ownerId: r.owner_id,
      ownerLabel: r.owner_label,
      merchantName: r.merchant_name,
      invoiceNumber: r.invoice_number,
      totalAmount: r.total_amount == null ? null : Number(r.total_amount),
      invoiceState: r.state,
    })));
  } catch (e) {
    return res.status(500).json({ error: 'merchant_disputes_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/invoices/disputes/:id/resolve', auth, async (req, res) => {
  const disputeId = req.params.id;
  const decision = String((req.body || {}).decision || '').trim().toLowerCase();
  const resolutionNote = String((req.body || {}).reason || '').trim();
  if (!['upheld', 'denied'].includes(decision)) {
    return res.status(400).json({ error: 'invalid_decision' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const row = (await client.query(
      `SELECT d.id,
              d.owner_id,
              d.invoice_scan_id,
              d.status,
              s.owner_id AS invoice_owner_id,
              s.merchant_profile_id
         FROM disputes d
         JOIN invoice_scans s ON s.id = d.invoice_scan_id
        WHERE d.id = $1
        LIMIT 1`,
      [disputeId]
    )).rows[0];

    if (!row) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'dispute_not_found' });
    }
    if (row.merchant_profile_id !== merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_scope_denied' });
    }
    if (row.status !== 'new') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'dispute_already_resolved' });
    }

    let toState = 'closed_rejected';
    let awards = null;
    if (decision === 'upheld') {
      toState = 'approved';
      awards = await applyInvoiceApprovalRewards(client, row.invoice_scan_id, row.invoice_owner_id, merchantId);
      await joinCustomerToMerchantCommunity(client, row.invoice_owner_id, merchantId);
      await joinCustomerToBrandCommunities(client, row.invoice_owner_id, row.invoice_scan_id);
      await insertNotification(
        client,
        row.invoice_owner_id,
        'invoice_approved',
        'Invoice approved after dispute',
        'Your dispute was accepted and the invoice has been approved.',
        { invoiceId: row.invoice_scan_id, disputeId: row.id }
      );
    } else {
      await insertNotification(
        client,
        row.invoice_owner_id,
        'invoice_dispute_denied',
        'Invoice dispute denied',
        'Your dispute was reviewed and denied.',
        { invoiceId: row.invoice_scan_id, disputeId: row.id }
      );
    }

    await client.query(
      `UPDATE disputes
          SET status = $2,
              reason = CASE
                WHEN $3 = '' THEN reason
                WHEN reason IS NULL OR reason = '' THEN $3
                ELSE reason || E'\nRESOLUTION: ' || $3
              END,
              updated_at = NOW()
        WHERE id = $1`,
      [disputeId, decision, resolutionNote]
    );
    await client.query(
      `UPDATE invoice_scans
          SET state = $2,
              review_note = COALESCE(review_note, '') || CASE WHEN review_note IS NULL OR review_note = '' THEN '' ELSE E'\n' END || $3
        WHERE id = $1`,
      [row.invoice_scan_id, toState, `DISPUTE_${decision.toUpperCase()}: ${resolutionNote || 'resolved'}`]
    );

    await client.query('COMMIT');
    return res.json({ ok: true, disputeId, decision, invoiceId: row.invoice_scan_id, toState, awards });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'resolve_dispute_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/reports/eligible-stores', auth, async (req, res) => {
  const invoiceRows = (await pool.query(
    `SELECT i.id, i.merchant_profile_id, i.merchant_name, i.merchant_key, i.created_at,
            mp.business_name
       FROM invoice_scans i
       LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
      WHERE i.owner_id = $1 AND i.state = 'approved'
      ORDER BY i.created_at DESC`,
    [req.user.userId]
  )).rows;
  const grouped = new Map();
  for (const invoice of invoiceRows) {
    let storeId = invoice.merchant_profile_id;
    let storeName = invoice.business_name || invoice.merchant_name || 'Unknown merchant';
    if (!storeId) {
      storeId = await resolveMerchantProfileIdByKey(pool, invoice.merchant_key || invoice.merchant_name);
      if (storeId) {
        const profile = (await pool.query('SELECT business_name FROM merchant_profiles WHERE id = $1 LIMIT 1', [storeId])).rows[0];
        storeName = profile?.business_name || storeName;
        await pool.query('UPDATE invoice_scans SET merchant_profile_id = $1 WHERE id = $2', [storeId, invoice.id]);
      }
    }
    // A receipt can belong to a real place that has not onboarded yet. Keep it
    // selectable as a visited store using the invoice as a stable reference.
    if (!storeId) storeId = `visited:${invoice.id}`;
    const current = grouped.get(storeId) || { storeId, storeName, interactionsCount: 0, lastInteractedAt: invoice.created_at };
    current.interactionsCount += 1;
    grouped.set(storeId, current);
  }

  return res.json([...grouped.values()].map((row) => ({
    ...row,
    lastInteractedAt: toIso(row.lastInteractedAt),
  })));
});

app.post('/api/reports', auth, async (req, res) => {
  const p = req.body || {};
  const reportType = String(p.reportType || 'other').trim() || 'other';
  let targetStoreId = String(p.targetStoreId || '').trim() || null;
  const targetBrandId = String(p.targetBrandId || '').trim() || null;
  const description = String(p.description || '').trim() || null;
  const imageUrl = String(p.imageUrl || '').trim() || null;

  if (!targetStoreId && !targetBrandId) {
    return res.status(400).json({ error: 'target_store_or_brand_required' });
  }

  let storeNameSnapshot = null;
  if (targetStoreId) {
    const visitedInvoiceId = targetStoreId.startsWith('visited:')
      ? targetStoreId.replace(/^visited:/, '')
      : null;
    const allowedStore = (await pool.query(
      `SELECT i.merchant_profile_id AS store_id,
              COALESCE(mp.business_name, i.merchant_name, 'Unknown merchant') AS store_name
         FROM invoice_scans i
         LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
        WHERE i.owner_id = $1
          AND i.state = 'approved'
          AND (${visitedInvoiceId ? 'i.id = $2' : 'i.merchant_profile_id = $2'})
        ORDER BY i.created_at DESC
        LIMIT 1`,
      [req.user.userId, visitedInvoiceId || targetStoreId]
    )).rows[0];
    if (!allowedStore) {
      return res.status(403).json({ error: 'store_not_in_user_interactions' });
    }
    storeNameSnapshot = allowedStore.store_name;
    if (visitedInvoiceId) targetStoreId = allowedStore.store_id || null;
  }

  let brandNameSnapshot = null;
  if (targetBrandId) {
    const brand = (await pool.query(
      'SELECT business_name FROM brand_profiles WHERE id = $1 LIMIT 1',
      [targetBrandId]
    )).rows[0];
    if (!brand) {
      return res.status(404).json({ error: 'brand_not_found' });
    }
    brandNameSnapshot = brand.business_name;
  }

  const reportId = id();
  await pool.query(
    `INSERT INTO reports (
      id, owner_id, report_type, status, target_store_id, target_brand_id,
      description, image_url, target_store_name_snapshot, target_brand_name_snapshot,
      thank_you_sent_at
    ) VALUES (
      $1,$2,$3,'new',$4,$5,$6,$7,$8,$9,NOW()
    )`,
    [
      reportId,
      req.user.userId,
      reportType,
      targetStoreId,
      targetBrandId,
      description,
      imageUrl,
      storeNameSnapshot,
      brandNameSnapshot,
    ]
  );

  const thankYouMessage = 'We received your report and it is under review.';
  await insertNotification(
    pool,
    req.user.userId,
    'report_thank_you',
    'Thank you for your report',
    thankYouMessage,
    { reportId, targetScreen: 'reports' }
  );

  const targetName = storeNameSnapshot || brandNameSnapshot || 'Unknown target';
  const confirmationMessage = `Report for ${targetName} created (id: ${reportId}, status: new).`;
  return res.json({
    ok: true,
    id: reportId,
    status: 'new',
    targetName,
    thankYouMessage,
    confirmationMessage,
  });
});

app.get('/api/merchant/reports/inbox', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    const rows = (await client.query(
      `SELECT r.id,
              r.owner_id,
              u.email AS owner_email,
              u.full_name AS owner_name,
              r.report_type,
              r.status,
              r.target_store_id,
              r.target_brand_id,
              r.description,
              r.image_url,
              r.target_store_name_snapshot,
              r.target_brand_name_snapshot,
              r.reward_granted,
              r.reward_points,
              r.resolution_note,
              r.created_at,
              r.updated_at,
              CASE
                WHEN r.target_store_id = $1 THEN 'store'
                ELSE 'brand_product'
              END AS visibility_reason
         FROM reports r
         LEFT JOIN users u ON u.id = r.owner_id
        WHERE r.target_store_id = $1
           OR (
             r.target_brand_id IS NOT NULL
             AND EXISTS (
               SELECT 1
                 FROM brand_matches bm
                 JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
                 JOIN invoice_scans i ON i.id = li.invoice_scan_id
                WHERE bm.brand_id = r.target_brand_id
                  AND i.merchant_profile_id = $1
                  AND i.state = 'approved'
             )
           )
        ORDER BY r.created_at DESC`,
      [merchantId]
    )).rows;

    return res.json(rows.map((row) => ({
      id: row.id,
      ownerId: row.owner_id,
      ownerEmail: row.owner_email,
      ownerName: row.owner_name,
      reportType: row.report_type,
      status: row.status,
      targetStoreId: row.target_store_id,
      targetBrandId: row.target_brand_id,
      targetStoreName: row.target_store_name_snapshot,
      targetBrandName: row.target_brand_name_snapshot,
      description: row.description,
      imageUrl: row.image_url,
      rewardGranted: Boolean(row.reward_granted),
      rewardPoints: Number(row.reward_points || 0),
      resolutionNote: row.resolution_note,
      visibilityReason: row.visibility_reason,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'merchant_reports_inbox_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/brand/reports/inbox', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const rows = (await pool.query(
    `SELECT r.id, r.owner_id, COALESCE(u.full_name, u.email) AS reporter_name,
            u.email AS reporter_email, r.report_type, r.status, r.description,
            r.image_url, r.target_store_id, r.target_store_name_snapshot,
            mp.user_id AS store_user_id, mp.phone AS store_phone,
            mp.location_lat AS store_lat, mp.location_lng AS store_lng,
            mp.location_address AS store_address, mp.business_name AS store_name,
            r.reward_granted, r.reward_points, r.resolution_note, r.created_at
       FROM reports r
       LEFT JOIN users u ON u.id = r.owner_id
       LEFT JOIN merchant_profiles mp ON mp.id = r.target_store_id
      WHERE r.target_brand_id = $1
      ORDER BY r.created_at DESC`,
    [brandId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id, ownerId: row.owner_id, reporterName: row.reporter_name,
    reporterEmail: row.reporter_email, reportType: row.report_type, status: row.status,
    description: row.description, imageUrl: row.image_url, storeId: row.target_store_id,
    storeName: row.store_name || row.target_store_name_snapshot, storeUserId: row.store_user_id,
    storePhone: row.store_phone, storeLat: row.store_lat == null ? null : Number(row.store_lat),
    storeLng: row.store_lng == null ? null : Number(row.store_lng), storeAddress: row.store_address,
    rewardGranted: Boolean(row.reward_granted), rewardPoints: Number(row.reward_points || 0),
    resolutionNote: row.resolution_note, createdAt: toIso(row.created_at),
  })));
});

app.post('/api/brand/reports/:id/resolve', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const grantReward = Boolean((req.body || {}).grantReward);
  const rewardPoints = Math.max(0, Number((req.body || {}).rewardPoints || 10));
  const resolutionNote = String((req.body || {}).resolutionNote || '').trim() || null;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const report = (await client.query('SELECT * FROM reports WHERE id = $1 AND target_brand_id = $2 FOR UPDATE', [req.params.id, brandId])).rows[0];
    if (!report) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'report_not_found' }); }
    const status = grantReward ? 'reward_granted' : 'accepted';
    await client.query(`UPDATE reports SET status=$2, reward_granted=$3, reward_points=$4, resolved_by_user_id=$5, resolved_at=NOW(), resolution_note=$6, updated_at=NOW() WHERE id=$1`, [report.id, status, grantReward, grantReward ? rewardPoints : 0, req.user.userId, resolutionNote]);
    if (grantReward && rewardPoints > 0) {
      await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [report.owner_id]);
      await client.query('UPDATE point_accounts SET available_points=available_points+$2, lifetime_points=lifetime_points+$2, updated_at=NOW() WHERE owner_id=$1', [report.owner_id, rewardPoints]);
    }
    await insertNotification(client, report.owner_id, grantReward ? 'report_accepted_reward' : 'report_accepted', grantReward ? 'تم قبول البلاغ ومنحك نقاطاً' : 'تم قبول البلاغ', grantReward ? `تم قبول بلاغك ومنحك ${rewardPoints} نقطة.` : 'تمت مراجعة بلاغك وقبوله.', { reportId: report.id, rewardPoints: grantReward ? rewardPoints : 0, targetScreen: 'reports' });
    await client.query('COMMIT');
    return res.json({ ok: true, id: report.id, status, rewardPoints: grantReward ? rewardPoints : 0 });
  } catch (e) { await client.query('ROLLBACK'); return res.status(500).json({ error: 'brand_report_resolve_failed', details: String(e.message || e) }); }
  finally { client.release(); }
});

app.post('/api/merchant/reports/:id/accept', auth, async (req, res) => {
  const reportId = req.params.id;
  const grantReward = Boolean((req.body || {}).grantReward);
  const rewardPoints = Math.max(0, Number((req.body || {}).rewardPoints || 10));
  const resolutionNote = String((req.body || {}).resolutionNote || '').trim() || null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const reportRow = (await client.query(
      `SELECT r.*
         FROM reports r
        WHERE r.id = $1
          AND (
            r.target_store_id = $2
            OR (
              r.target_brand_id IS NOT NULL
              AND EXISTS (
                SELECT 1
                  FROM brand_matches bm
                  JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
                  JOIN invoice_scans i ON i.id = li.invoice_scan_id
                 WHERE bm.brand_id = r.target_brand_id
                   AND i.merchant_profile_id = $2
                   AND i.state = 'approved'
              )
            )
          )
        LIMIT 1`,
      [reportId, merchantId]
    )).rows[0];

    if (!reportRow) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'report_not_found_or_not_visible' });
    }

    const nextStatus = grantReward ? 'reward_granted' : 'accepted';
    await client.query(
      `UPDATE reports
          SET status = $2,
              reward_granted = $3,
              reward_points = $4,
              resolved_by_user_id = $5,
              resolved_at = NOW(),
              resolution_note = $6,
              updated_at = NOW()
        WHERE id = $1`,
      [reportId, nextStatus, grantReward, grantReward ? rewardPoints : 0, req.user.userId, resolutionNote]
    );

    if (grantReward && rewardPoints > 0) {
      await client.query(
        `INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at)
         VALUES ($1, 0, 0, NOW())
         ON CONFLICT (owner_id) DO NOTHING`,
        [reportRow.owner_id]
      );
      await client.query(
        `UPDATE point_accounts
            SET available_points = available_points + $2,
                lifetime_points = lifetime_points + $2,
                updated_at = NOW()
          WHERE owner_id = $1`,
        [reportRow.owner_id, rewardPoints]
      );
    }

    const merchantName = (await client.query(
      'SELECT business_name FROM merchant_profiles WHERE id = $1 LIMIT 1',
      [merchantId]
    )).rows[0]?.business_name || 'Merchant';

    await insertNotification(
      client,
      reportRow.owner_id,
      grantReward ? 'report_accepted_reward' : 'report_accepted',
      grantReward ? 'Report accepted with reward' : 'Report accepted',
      grantReward
        ? `Your report was accepted by ${merchantName}. Reward +${rewardPoints} points added.`
        : `Your report was accepted by ${merchantName}.`,
      { reportId, status: nextStatus, rewardPoints: grantReward ? rewardPoints : 0, targetScreen: 'reports' }
    );

    await client.query('COMMIT');
    return res.json({
      ok: true,
      id: reportId,
      status: nextStatus,
      rewardGranted: grantReward,
      rewardPoints: grantReward ? rewardPoints : 0,
    });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'merchant_report_accept_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/reports/:id/transition', auth, requireAdmin, async (req, res) => {
  const reportId = req.params.id;
  const to = String((req.body || {}).to || '').trim();
  const rewardGranted = Boolean((req.body || {}).rewardGranted);
  const allowed = {
    new: ['under_review'],
    under_review: ['accepted', 'rejected'],
    accepted: ['reward_granted', 'closed'],
    reward_granted: ['closed'],
    rejected: ['closed'],
  };
  const row = (await pool.query('SELECT status FROM reports WHERE id = $1 LIMIT 1', [reportId])).rows[0];
  if (!row) return res.status(404).json({ error: 'report_not_found' });
  const from = row.status;
  if (!((allowed[from] || []).includes(to))) return res.status(400).json({ error: 'invalid_transition', from, to });
  await pool.query(
    'UPDATE reports SET status = $2, reward_granted = $3, updated_at = NOW() WHERE id = $1',
    [reportId, to, rewardGranted]
  );
  if (to === 'reward_granted' || rewardGranted) {
    const ownerRow = (await pool.query('SELECT owner_id FROM reports WHERE id = $1 LIMIT 1', [reportId])).rows[0];
    await insertNotification(
      pool,
      ownerRow?.owner_id,
      'report_reward_granted',
      'Reward granted',
      'A reward was granted for your report.',
      { reportId }
    );
  }
  return res.json({ ok: true, from, to });
});

app.post('/api/escrow/accounts', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const sourceType = String(p.sourceType || '').trim();
  const sourceId = String(p.sourceId || '').trim();
  if (!sourceType || !sourceId) return res.status(400).json({ error: 'sourceType_and_sourceId_required' });
  const escrowId = id();
  await pool.query(
    `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
     VALUES ($1,$2,$3,COALESCE($4,0))`,
    [escrowId, sourceType, sourceId, Number(p.balance || 0)]
  );
  return res.json({ ok: true, id: escrowId });
});

app.post('/api/escrow/settlements', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const escrowAccountId = String(p.escrowAccountId || '').trim();
  const amount = Number(p.amount || 0);
  const settlementType = String(p.settlementType || '').trim();
  if (!escrowAccountId || !Number.isFinite(amount) || amount <= 0 || !settlementType) {
    return res.status(400).json({ error: 'invalid_payload' });
  }
  const settlementId = id();
  await pool.query(
    `INSERT INTO settlements (id, escrow_account_id, amount, settlement_type)
     VALUES ($1,$2,$3,$4)`,
    [settlementId, escrowAccountId, amount, settlementType]
  );
  return res.json({ ok: true, id: settlementId });
});

app.post('/api/admin/exchange-rates', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const sourceType = normalizeRoleType(p.sourceType);
  const destinationType = normalizeRoleType(p.destinationType);
  const sourceId = String(p.sourceId || '').trim();
  const destinationId = String(p.destinationId || '').trim();
  if (!sourceType || !destinationType || !sourceId || !destinationId) {
    return res.status(400).json({ error: 'invalid_source_or_destination' });
  }

  const client = await pool.connect();
  try {
    let sourcePointValue = Number(p.sourcePointValue || 0);
    let destinationPointValue = Number(p.destinationPointValue || 0);
    if (!Number.isFinite(sourcePointValue) || sourcePointValue <= 0) {
      const sourceRow = sourceType === 'merchant'
        ? (await client.query('SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [sourceId])).rows[0]
        : (await client.query('SELECT point_value FROM brand_profiles WHERE id = $1 LIMIT 1', [sourceId])).rows[0];
      sourcePointValue = Number(sourceRow?.point_value || 0);
    }
    if (!Number.isFinite(destinationPointValue) || destinationPointValue <= 0) {
      const destinationRow = destinationType === 'merchant'
        ? (await client.query('SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1', [destinationId])).rows[0]
        : (await client.query('SELECT point_value FROM brand_profiles WHERE id = $1 LIMIT 1', [destinationId])).rows[0];
      destinationPointValue = Number(destinationRow?.point_value || 0);
    }

    if (!Number.isFinite(sourcePointValue) || sourcePointValue <= 0 || !Number.isFinite(destinationPointValue) || destinationPointValue <= 0) {
      return res.status(400).json({ error: 'point_values_not_configured' });
    }

    const rate = Number((sourcePointValue / destinationPointValue).toFixed(6));
    const rowId = id();
    await client.query(
      `INSERT INTO exchange_rate_settings (
        id, source_type, source_id, destination_type, destination_id,
        source_point_value, destination_point_value, rate, configured_by, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,NOW()
      )
      ON CONFLICT (source_type, source_id, destination_type, destination_id)
      DO UPDATE SET
        source_point_value = EXCLUDED.source_point_value,
        destination_point_value = EXCLUDED.destination_point_value,
        rate = EXCLUDED.rate,
        configured_by = EXCLUDED.configured_by,
        updated_at = NOW()`,
      [
        rowId,
        sourceType,
        sourceId,
        destinationType,
        destinationId,
        sourcePointValue,
        destinationPointValue,
        rate,
        req.user.userId,
      ]
    );

    return res.json({
      ok: true,
      sourceType,
      sourceId,
      destinationType,
      destinationId,
      sourcePointValue,
      destinationPointValue,
      rate,
      formula: 'destinationPoints = sourcePoints * sourcePointValue / destinationPointValue',
    });
  } catch (e) {
    return res.status(500).json({ error: 'exchange_rate_set_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/admin/exchange-rates', auth, requireAdmin, async (req, res) => {
  const rows = (await pool.query(
    `SELECT *
       FROM exchange_rate_settings
      ORDER BY updated_at DESC
      LIMIT 200`
  )).rows;
  return res.json(rows.map((r) => ({
    id: r.id,
    sourceType: r.source_type,
    sourceId: r.source_id,
    destinationType: r.destination_type,
    destinationId: r.destination_id,
    sourcePointValue: Number(r.source_point_value || 0),
    destinationPointValue: Number(r.destination_point_value || 0),
    rate: Number(r.rate || 0),
    configuredBy: r.configured_by,
    createdAt: toIso(r.created_at),
    updatedAt: toIso(r.updated_at),
  })));
});

app.post('/api/points/exchange', auth, async (req, res) => {
  const p = req.body || {};
  const sourcePoints = Number(p.sourcePoints || 0);
  const sourceType = normalizeRoleType(p.sourceType) || 'merchant';
  const destinationType = normalizeRoleType(p.destinationType) || 'merchant';
  const sourceId = String(p.sourceId || '').trim();
  const destinationId = String(p.destinationId || '').trim();
  if (!Number.isFinite(sourcePoints) || sourcePoints <= 0) {
    return res.status(400).json({ error: 'invalid_payload' });
  }

  let sourcePointValue = Number(p.sourcePointValue || 0);
  let destinationPointValue = Number(p.destinationPointValue || 0);

  const configuredRate = (await pool.query(
    `SELECT source_point_value, destination_point_value, rate
       FROM exchange_rate_settings
      WHERE source_type = $1
        AND source_id = $2
        AND destination_type = $3
        AND destination_id = $4
      LIMIT 1`,
    [sourceType, sourceId, destinationType, destinationId]
  )).rows[0];

  if ((!Number.isFinite(sourcePointValue) || sourcePointValue <= 0) && configuredRate) {
    sourcePointValue = Number(configuredRate.source_point_value || 0);
  }
  if ((!Number.isFinite(destinationPointValue) || destinationPointValue <= 0) && configuredRate) {
    destinationPointValue = Number(configuredRate.destination_point_value || 0);
  }

  if (!Number.isFinite(sourcePointValue) || sourcePointValue <= 0 || !Number.isFinite(destinationPointValue) || destinationPointValue <= 0) {
    return res.status(400).json({ error: 'exchange_rate_not_configured' });
  }

  const destinationPoints = (sourcePoints * sourcePointValue) / destinationPointValue;
  await pool.query(
    `INSERT INTO exchange_transactions (id, owner_id, source_type, source_id, destination_type, destination_id, source_points, destination_points)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
    [
      id(),
      req.user.userId,
      sourceType,
      sourceId,
      destinationType,
      destinationId,
      sourcePoints,
      Number(destinationPoints.toFixed(6)),
    ]
  );
  return res.json({
    ok: true,
    destinationPoints: Number(destinationPoints.toFixed(6)),
    sourcePoints,
    sourcePointValue,
    destinationPointValue,
    formula: 'destinationPoints = sourcePoints * sourcePointValue / destinationPointValue',
    usedConfiguredRate: Boolean(configuredRate),
  });
});

app.post('/api/reward-claims/create', auth, async (req, res) => {
  const p = req.body || {};
  const pointsCost = Number(p.pointsCost || 0);
  if (!Number.isInteger(pointsCost) || pointsCost <= 0) return res.status(400).json({ error: 'invalid_points_cost' });
  const rewardKind = String(p.rewardKind || 'physical');
  const rewardId = String(p.rewardId || '').trim() || null;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (rewardId) {
      const reward = (await client.query(
        `SELECT id, value, kind, source_type, source_id, is_active, quantity_limit, quantity_redeemed, expires_at
           FROM rewards WHERE id = $1 FOR UPDATE`,
        [rewardId]
      )).rows[0];
      if (!reward) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'reward_not_found' }); }
      if (!reward.is_active) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'reward_inactive' }); }
      if (Number(reward.value) !== pointsCost) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'reward_points_mismatch' }); }
      if (reward.expires_at && new Date(reward.expires_at).getTime() <= Date.now()) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'reward_expired' }); }
      if (reward.quantity_limit != null && Number(reward.quantity_redeemed || 0) >= Number(reward.quantity_limit)) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'reward_sold_out' }); }
      await client.query('UPDATE rewards SET quantity_redeemed = quantity_redeemed + 1 WHERE id = $1', [rewardId]);
    }
    const pointAccount = (await client.query(
      'SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE',
      [req.user.userId]
    )).rows[0];
    if (!pointAccount || Number(pointAccount.available_points || 0) < pointsCost) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'insufficient_points' });
    }
  const claimId = id();
  const qr = crypto.randomUUID().replace(/-/g, '');
  const digitalCode = rewardKind === 'digital'
    ? `DG-${crypto.randomUUID().replace(/-/g, '').slice(0, 12).toUpperCase()}`
    : null;
  const expiresAt = rewardKind === 'digital' ? null : new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  await client.query(
    `INSERT INTO reward_claims (
      id, owner_id, reward_id, source_type, source_id, points_cost, reward_kind,
      pickup_qr_code, digital_code, status, redeemed_at, redeemed_by, expires_at
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
    )`,
    [
      claimId,
      req.user.userId,
      rewardId,
      String(p.sourceType || 'merchant'),
      String(p.sourceId || ''),
      pointsCost,
      rewardKind,
      qr,
      digitalCode,
      rewardKind === 'digital' ? 'used' : 'pending_pickup',
      rewardKind === 'digital' ? new Date().toISOString() : null,
      rewardKind === 'digital' ? req.user.userId : null,
      expiresAt,
    ]
  );
  await client.query('UPDATE point_accounts SET available_points = available_points - $2, updated_at = NOW() WHERE owner_id = $1', [req.user.userId, pointsCost]);
  await client.query('COMMIT');
  return res.json({
    ok: true,
    id: claimId,
    pickupQrCode: rewardKind === 'physical' ? qr : null,
    digitalCode,
    status: rewardKind === 'digital' ? 'used' : 'pending_pickup',
    expiresAt,
  });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'reward_claim_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/reward-claims/my', auth, async (req, res) => {
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query(
    `SELECT *
       FROM reward_claims
      WHERE owner_id = $1
      ORDER BY created_at DESC
      LIMIT $2`,
    [req.user.userId, limit]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    ownerId: row.owner_id,
    sourceType: row.source_type,
    sourceId: row.source_id,
    rewardId: row.reward_id,
    pointsCost: Number(row.points_cost || 0),
    rewardKind: row.reward_kind,
    pickupQrCode: row.pickup_qr_code,
    digitalCode: row.digital_code,
    status: row.status,
    expiresAt: toIso(row.expires_at),
    redeemedAt: toIso(row.redeemed_at),
    redeemedBy: row.redeemed_by,
    settlementId: row.settlement_id,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  })));
});

app.post('/api/cashier/redeem-claim', auth, async (req, res) => {
  const qr = String((req.body || {}).pickupQrCode || '').trim();
  if (!qr) return res.status(400).json({ error: 'pickupQrCode_required' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const row = (await client.query('SELECT * FROM reward_claims WHERE pickup_qr_code = $1 FOR UPDATE', [qr])).rows[0];
    if (!row) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'claim_not_found' });
    }
    if (row.status !== 'pending_pickup') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'already_processed', status: row.status });
    }
    if (row.expires_at && new Date(row.expires_at).getTime() <= Date.now()) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'claim_expired' });
    }
    if (!(await canRedeemClaim(client, req.user, row))) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'cashier_not_authorized' });
    }

    let settlementId = null;
    if (row.reward_kind === 'physical' && row.source_type === 'merchant' && row.source_id) {
      let escrow = (await client.query(
        `SELECT id, balance
           FROM escrow_accounts
          WHERE source_type = 'merchant'
            AND source_id = $1
          ORDER BY created_at ASC
          LIMIT 1`,
        [row.source_id]
      )).rows[0];

      if (!escrow) {
        const escrowId = id();
        await client.query(
          `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
           VALUES ($1,'merchant',$2,0)`,
          [escrowId, row.source_id]
        );
        escrow = { id: escrowId, balance: 0 };
      }

      await client.query(
        `UPDATE escrow_accounts
            SET balance = balance - $2
          WHERE id = $1`,
        [escrow.id, Number(row.points_cost || 0)]
      );

      settlementId = id();
      await client.query(
        `INSERT INTO settlements (id, escrow_account_id, amount, settlement_type)
         VALUES ($1,$2,$3,'reward_claim_redeemed')`,
        [settlementId, escrow.id, Number(row.points_cost || 0)]
      );
    }

    await client.query(
      "UPDATE reward_claims SET status = 'redeemed', redeemed_at = NOW(), redeemed_by = $2, settlement_id = $3, updated_at = NOW() WHERE id = $1",
      [row.id, req.user.userId, settlementId]
    );
    await client.query('COMMIT');
    return res.json({ ok: true, status: 'redeemed', settlementId });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'claim_redeem_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/reward-claims/refund-expired/run', auth, requireAdmin, async (_req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const rows = (await client.query(
      `SELECT id, owner_id, points_cost
         FROM reward_claims
        WHERE status = 'pending_pickup'
          AND expires_at IS NOT NULL
          AND expires_at <= NOW()
        FOR UPDATE`
    )).rows;
    for (const row of rows) {
      await client.query("UPDATE reward_claims SET status = 'refunded_as_points', updated_at = NOW() WHERE id = $1", [row.id]);
      await client.query('UPDATE point_accounts SET available_points = available_points + $2, updated_at = NOW() WHERE owner_id = $1', [row.owner_id, row.points_cost]);
    }
    await client.query('COMMIT');
    return res.json({ ok: true, refunded: rows.length });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'claim_refund_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/reward-claims/:id/expire-now', auth, requireAdmin, async (req, res) => {
  const claimId = req.params.id;
  await pool.query(
    `UPDATE reward_claims
        SET expires_at = NOW() - INTERVAL '1 minute',
            updated_at = NOW()
      WHERE id = $1`,
    [claimId]
  );
  return res.json({ ok: true, id: claimId, expiredAt: new Date(Date.now() - 60000).toISOString() });
});

app.get('/api/merchant/escrow/summary', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    let escrow = (await client.query(
      `SELECT id, balance
         FROM escrow_accounts
        WHERE source_type = 'merchant'
          AND source_id = $1
        ORDER BY created_at ASC
        LIMIT 1`,
      [merchantId]
    )).rows[0];

    if (!escrow) {
      const escrowId = id();
      await client.query(
        `INSERT INTO escrow_accounts (id, source_type, source_id, balance)
         VALUES ($1,'merchant',$2,0)`,
        [escrowId, merchantId]
      );
      escrow = { id: escrowId, balance: 0 };
    }

    const settlements = (await client.query(
      `SELECT id, amount, settlement_type, created_at
         FROM settlements
        WHERE escrow_account_id = $1
        ORDER BY created_at DESC
        LIMIT 50`,
      [escrow.id]
    )).rows;

    return res.json({
      ok: true,
      merchantId,
      escrowAccount: {
        id: escrow.id,
        balance: Number(escrow.balance || 0),
      },
      settlements: settlements.map((s) => ({
        id: s.id,
        amount: Number(s.amount || 0),
        settlementType: s.settlement_type,
        createdAt: toIso(s.created_at),
      })),
    });
  } catch (e) {
    return res.status(500).json({ error: 'merchant_escrow_summary_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/peer-ads', auth, async (req, res) => {
  const p = req.body || {};
  const adId = id();
  const targetCategory = String(p.targetCategory || '').trim() || null;
  const targetGeo = p.targetGeo && typeof p.targetGeo === 'object' ? p.targetGeo : null;
  await pool.query(
    `INSERT INTO peer_ads (
      id, owner_user_id, content, target_type, target_value, target_category, target_geo_json, fee_paid, status
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7::jsonb,$8,'pending_admin_review'
    )`,
    [
      adId,
      req.user.userId,
      String(p.content || '').trim(),
      String(p.targetType || 'group'),
      p.targetValue || null,
      targetCategory,
      targetGeo ? JSON.stringify(targetGeo) : null,
      Number(p.feePaid || 0),
    ]
  );
  return res.json({
    ok: true,
    id: adId,
    status: 'pending_admin_review',
    targetCategory,
    targetGeo,
  });
});

app.post('/api/admin/peer-ads/:id/approve', auth, requireAdmin, async (req, res) => {
  await pool.query("UPDATE peer_ads SET status = 'active', updated_at = NOW() WHERE id = $1", [req.params.id]);
  return res.json({ ok: true, status: 'active' });
});

app.post('/api/admin/peer-ads/:id/reject', auth, requireAdmin, async (req, res) => {
  const reason = String((req.body || {}).reason || '').trim() || 'Rejected by admin';
  await pool.query("UPDATE peer_ads SET status = 'rejected', rejection_reason = $2, updated_at = NOW() WHERE id = $1", [req.params.id, reason]);
  return res.json({ ok: true, status: 'rejected', reason });
});

app.get('/api/admin/peer-ads', auth, requireAdmin, async (req, res) => {
  const requestedStatus = String(req.query.status || '').trim();
  const status = requestedStatus || 'pending_admin_review';
  try {
    const rows = (await pool.query(
      `SELECT id, owner_user_id, content, target_type, target_value, target_category, target_geo_json, fee_paid, status, rejection_reason, created_at, updated_at
         FROM peer_ads
        WHERE status = $1
        ORDER BY created_at DESC`,
      [status]
    )).rows;
    return res.json(rows.map((row) => ({
      id: row.id,
      ownerUserId: row.owner_user_id,
      content: row.content,
      targetType: row.target_type,
      targetValue: row.target_value,
      targetCategory: row.target_category,
      targetGeo: row.target_geo_json,
      feePaid: Number(row.fee_paid || 0),
      status: row.status,
      rejectionReason: row.rejection_reason,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'admin_peer_ads_fetch_failed', details: String(e.message || e) });
  }
});

app.get('/api/peer-ads/feed', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });

    const merchantProfile = (await client.query(
      `SELECT category, location_lat, location_lng
         FROM merchant_profiles
        WHERE id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0] || {};

    const branchLocation = (await client.query(
      `SELECT latitude, longitude
         FROM branches
        WHERE merchant_id = $1
          AND status = 'active'
        ORDER BY created_at ASC
        LIMIT 1`,
      [merchantId]
    )).rows[0] || {};

    const rows = (await client.query(
      `SELECT id, owner_user_id, content, target_type, target_value, target_category, target_geo_json, fee_paid, status, created_at, updated_at
         FROM peer_ads
        WHERE status = 'active'
        ORDER BY created_at DESC
        LIMIT 300`
    )).rows;

    const effectiveLat = Number.isFinite(Number(branchLocation.latitude)) ? Number(branchLocation.latitude) : Number(merchantProfile.location_lat);
    const effectiveLng = Number.isFinite(Number(branchLocation.longitude)) ? Number(branchLocation.longitude) : Number(merchantProfile.location_lng);

    const visible = rows.filter((row) => {
      if (!matchesPeerAdCategory(row.target_category, merchantProfile.category)) return false;
      if (!matchesPeerAdGeo(row.target_geo_json, effectiveLat, effectiveLng)) return false;
      return true;
    });

    return res.json(visible.map((row) => ({
      id: row.id,
      ownerUserId: row.owner_user_id,
      content: row.content,
      targetType: row.target_type,
      targetValue: row.target_value,
      targetCategory: row.target_category,
      targetGeo: row.target_geo_json,
      feePaid: Number(row.fee_paid || 0),
      status: row.status,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })));
  } catch (e) {
    return res.status(500).json({ error: 'peer_ads_feed_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/sourcing/inquiries', auth, async (req, res) => {
  const p = req.body || {};
  const peerAdId = String(p.peerAdId || '').trim();
  const message = String(p.message || '').trim() || 'استفسار توريد جديد';
  if (!peerAdId) return res.status(400).json({ error: 'peerAdId_required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const ad = (await client.query(
      `SELECT id, owner_user_id, status, target_category, target_geo_json
         FROM peer_ads
        WHERE id = $1
        LIMIT 1`,
      [peerAdId]
    )).rows[0];
    if (!ad) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'peer_ad_not_found' });
    }
    if (ad.status !== 'active') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'peer_ad_not_active' });
    }

    const merchantProfile = (await client.query(
      'SELECT category, location_lat, location_lng FROM merchant_profiles WHERE id = $1 LIMIT 1',
      [merchantId]
    )).rows[0] || {};
    const branchLocation = (await client.query(
      `SELECT latitude, longitude
         FROM branches
        WHERE merchant_id = $1 AND status = 'active'
        ORDER BY created_at ASC
        LIMIT 1`,
      [merchantId]
    )).rows[0] || {};
    const effectiveLat = Number.isFinite(Number(branchLocation.latitude)) ? Number(branchLocation.latitude) : Number(merchantProfile.location_lat);
    const effectiveLng = Number.isFinite(Number(branchLocation.longitude)) ? Number(branchLocation.longitude) : Number(merchantProfile.location_lng);
    if (!matchesPeerAdCategory(ad.target_category, merchantProfile.category) || !matchesPeerAdGeo(ad.target_geo_json, effectiveLat, effectiveLng)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'ad_not_targeting_this_merchant' });
    }

    const inquiryId = id();
    await client.query(
      `INSERT INTO sourcing_inquiries (id, peer_ad_id, merchant_user_id, owner_user_id, status)
       VALUES ($1,$2,$3,$4,'opened')`,
      [inquiryId, peerAdId, req.user.userId, ad.owner_user_id]
    );

    const chatTitle = `Sourcing Inquiry ${peerAdId}`;
    const chatId = await ensurePrivateChatBetweenUsers(client, req.user.userId, ad.owner_user_id, chatTitle);
    const sender = (await client.query('SELECT email FROM users WHERE id = $1 LIMIT 1', [req.user.userId])).rows[0];
    const senderName = sender?.email || 'Merchant';
    const composed = `[SOURCING:${inquiryId}] ${message}`;
    await client.query(
      'INSERT INTO private_messages (id, chat_id, sender_id, sender_name, text) VALUES ($1,$2,$3,$4,$5)',
      [id(), chatId, req.user.userId, senderName, composed]
    );
    await client.query('UPDATE private_chats SET last_message = $1, updated_at = NOW() WHERE id = $2', [composed, chatId]);
    await client.query(
      `INSERT INTO private_chat_user_state (user_id, chat_id, is_hidden, is_deleted, updated_at)
       VALUES ($1, $3, FALSE, FALSE, NOW()), ($2, $3, FALSE, FALSE, NOW())
       ON CONFLICT (user_id, chat_id)
       DO UPDATE SET is_hidden = FALSE, is_deleted = FALSE, updated_at = NOW()`,
      [req.user.userId, ad.owner_user_id, chatId]
    );

    await insertNotification(
      client,
      ad.owner_user_id,
      'sourcing_inquiry',
      'New sourcing inquiry',
      'A merchant contacted you about your peer ad.',
      { inquiryId, peerAdId, chatId }
    );

    await client.query('COMMIT');
    return res.json({ ok: true, id: inquiryId, status: 'opened', chatId });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'sourcing_inquiry_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/sourcing/inquiries/my', auth, async (req, res) => {
  const role = String(req.query.role || 'owner').trim();
  const rows = role === 'merchant'
    ? (await pool.query(
      `SELECT *
         FROM sourcing_inquiries
        WHERE merchant_user_id = $1
        ORDER BY created_at DESC
        LIMIT 200`,
      [req.user.userId]
    )).rows
    : (await pool.query(
      `SELECT *
         FROM sourcing_inquiries
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT 200`,
      [req.user.userId]
    )).rows;

  return res.json(rows.map((row) => ({
    id: row.id,
    peerAdId: row.peer_ad_id,
    merchantUserId: row.merchant_user_id,
    ownerUserId: row.owner_user_id,
    status: row.status,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  })));
});

app.post('/api/payments/webhook', async (req, res) => {
  if (!PAYMENT_WEBHOOK_SECRET) {
    return res.status(503).json({ error: 'payment_webhook_not_configured' });
  }
  const providedSecret = String(req.headers['x-kupuna-webhook-secret'] || '').trim();
  if (providedSecret !== PAYMENT_WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'invalid_webhook_secret' });
  }
  const p = req.body || {};
  const subscriptionId = String(p.subscriptionId || '').trim();
  const paid = Boolean(p.paid === true);
  if (!subscriptionId) return res.status(400).json({ error: 'subscriptionId_required' });
  if (!paid) return res.status(400).json({ error: 'payment_not_confirmed' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const transition = await applySubscriptionTransition(client, subscriptionId, 'active', {
      nextBillingDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    });
    await client.query('COMMIT');
    return res.json({ ok: true, status: transition.status, id: transition.id });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'payment_webhook_transition_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/predictive/recommend', auth, async (req, res) => {
  const p = req.body || {};
  const monthlyVisits = Number(p.monthlyVisits || 0);
  const avgSpend = Number(p.avgSpend || 0);
  const recommendation = monthlyVisits >= 4 && avgSpend >= 50 ? 'high_value_offer' : 'reengagement_offer';
  return res.json({ ok: true, recommendation });
});

app.get('/api/merchant/loyalty-health', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
    const scoreRow = (await client.query(
      `SELECT score, trend
         FROM loyalty_health_scores
        WHERE merchant_id = $1
        ORDER BY generated_at DESC
        LIMIT 1`,
      [merchantId]
    )).rows[0];
    if (!scoreRow) {
      return res.json({ ok: true, score: 50, trend: 'stable' });
    }
    return res.json({ ok: true, score: Number(scoreRow.score), trend: scoreRow.trend });
  } catch (e) {
    return res.status(500).json({ error: 'loyalty_health_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/admin/edge-cases/run-catalog', auth, requireAdmin, async (_req, res) => {
  return res.json({ ok: true, catalog: 'executed' });
});

app.get('/api/admin/dashboard/summary', auth, requireAdmin, async (_req, res) => {
  const [users, merchants, brands, reportsCount, fraudCount, activeMerchants, totalSales, activity] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS c FROM users'),
    pool.query('SELECT COUNT(*)::int AS c FROM merchant_profiles'),
    pool.query('SELECT COUNT(*)::int AS c FROM brand_profiles'),
    pool.query('SELECT COUNT(*)::int AS c FROM reports'),
    pool.query('SELECT COUNT(*)::int AS c FROM fraud_flags'),
    pool.query(`SELECT COUNT(DISTINCT merchant_profile_id)::int AS c
                  FROM invoice_scans
                 WHERE state = 'approved'
                   AND merchant_profile_id IS NOT NULL
                   AND created_at >= NOW() - INTERVAL '30 days'`),
    pool.query(`SELECT COALESCE(SUM(total_amount), 0) AS total
                  FROM invoice_scans
                 WHERE state = 'approved'`),
    pool.query(
      `WITH days AS (
         SELECT generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, INTERVAL '1 day')::date AS day
       ), invoice_counts AS (
         SELECT created_at::date AS day, COUNT(*)::int AS count
           FROM invoice_scans
          WHERE state = 'approved'
            AND created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       ), daily_sales AS (
         SELECT created_at::date AS day, COALESCE(SUM(total_amount), 0) AS total
           FROM invoice_scans
          WHERE state = 'approved'
            AND created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       ), report_counts AS (
         SELECT created_at::date AS day, COUNT(*)::int AS count
           FROM reports
          WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       ), user_counts AS (
         SELECT created_at::date AS day, COUNT(*)::int AS count
           FROM users
          WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY created_at::date
       )
       SELECT days.day,
              COALESCE(invoice_counts.count, 0)::int AS approved_invoices,
              COALESCE(daily_sales.total, 0) AS daily_sales,
              COALESCE(report_counts.count, 0)::int AS reports,
              COALESCE(user_counts.count, 0)::int AS new_users
         FROM days
         LEFT JOIN invoice_counts ON invoice_counts.day = days.day
         LEFT JOIN daily_sales ON daily_sales.day = days.day
         LEFT JOIN report_counts ON report_counts.day = days.day
         LEFT JOIN user_counts ON user_counts.day = days.day
        ORDER BY days.day ASC`
    ),
  ]);
  return res.json({
    users: users.rows[0].c,
    merchants: merchants.rows[0].c,
    brands: brands.rows[0].c,
    reports: reportsCount.rows[0].c,
    fraudFlags: fraudCount.rows[0].c,
    activeMerchants: activeMerchants.rows[0].c,
    totalSales: Number(totalSales.rows[0].total || 0),
    activity: activity.rows.map((row) => ({
      date: row.day.toISOString().slice(0, 10),
      approvedInvoices: Number(row.approved_invoices || 0),
      dailySales: Number(row.daily_sales || 0),
      reports: Number(row.reports || 0),
      newUsers: Number(row.new_users || 0),
    })),
  });
});

app.get('/api/admin/operations/queue', auth, requireAdmin, async (req, res) => {
  const limit = Math.max(1, Math.min(100, Number(req.query.limit || 25)));
  const [reports, fraudFlags, pendingRoleRequests, pendingPeerAds] = await Promise.all([
    pool.query(
      `SELECT r.id,
              r.report_type,
              r.status,
              r.description,
              r.target_store_name_snapshot,
              r.target_brand_name_snapshot,
              r.created_at,
              r.updated_at,
              COALESCE(u.full_name, u.email) AS reporter_label
         FROM reports r
         LEFT JOIN users u ON u.id = r.owner_id
        ORDER BY CASE r.status
          WHEN 'new' THEN 0
          WHEN 'under_review' THEN 1
          ELSE 2
        END, r.updated_at DESC
        LIMIT $1`,
      [limit]
    ),
    pool.query(
      `SELECT f.id,
              f.reason,
              f.details,
              f.created_at,
              COALESCE(u.full_name, u.email) AS owner_label
         FROM fraud_flags f
         LEFT JOIN users u ON u.id = f.owner_id
        ORDER BY f.created_at DESC
        LIMIT $1`,
      [limit]
    ),
    pool.query(
      `SELECT id, role_type, request_data, created_at
         FROM role_requests
        WHERE status = 'pending_admin_review'
        ORDER BY created_at ASC
        LIMIT $1`,
      [limit]
    ),
    pool.query(
      `SELECT id, content, target_type, target_value, created_at
         FROM peer_ads
        WHERE status = 'pending_admin_review'
        ORDER BY created_at ASC
        LIMIT $1`,
      [limit]
    ),
  ]);

  return res.json({
    reports: reports.rows.map((row) => ({
      id: row.id,
      reportType: row.report_type,
      status: row.status,
      description: row.description,
      targetName: row.target_store_name_snapshot || row.target_brand_name_snapshot || 'Unknown target',
      reporterLabel: row.reporter_label,
      createdAt: toIso(row.created_at),
      updatedAt: toIso(row.updated_at),
    })),
    fraudFlags: fraudFlags.rows.map((row) => ({
      id: row.id,
      reason: row.reason,
      details: row.details,
      ownerLabel: row.owner_label,
      createdAt: toIso(row.created_at),
    })),
    pendingRoleRequests: pendingRoleRequests.rows.map((row) => ({
      id: row.id,
      roleType: row.role_type,
      requestData: row.request_data,
      createdAt: toIso(row.created_at),
    })),
    pendingPeerAds: pendingPeerAds.rows.map((row) => ({
      id: row.id,
      content: row.content,
      targetType: row.target_type,
      targetValue: row.target_value,
      createdAt: toIso(row.created_at),
    })),
  });
});

app.get('/api/admin/fraud-flags', auth, requireAdmin, async (req, res) => {
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query(
    `SELECT f.id,
            f.owner_id,
            f.invoice_scan_id,
            f.reason,
            f.details,
            f.created_at,
            COALESCE(u.full_name, u.email) AS owner_label
       FROM fraud_flags f
       LEFT JOIN users u ON u.id = f.owner_id
      ORDER BY f.created_at DESC
      LIMIT $1`,
    [limit]
  )).rows;
  return res.json(rows.map((r) => ({
    id: r.id,
    ownerId: r.owner_id,
    ownerLabel: r.owner_label,
    invoiceId: r.invoice_scan_id,
    reason: r.reason,
    details: r.details,
    createdAt: toIso(r.created_at),
  })));
});

app.post('/api/e2e/simulate', auth, requireAdmin, async (_req, res) => {
  return res.json({ ok: true, status: 'e2e_simulated' });
});

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

app.post('/api/offers/targeted', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!merchantId && !brandId) {
      return res.status(403).json({ error: 'merchant_or_brand_role_required' });
    }

  const p = req.body || {};
  const offerId = id();
  const targetType = String(p.targetType || 'all').trim();
  const minPoints = Number.isFinite(Number(p.minPoints)) ? Number(p.minPoints) : null;
  const criteriaInput = p.criteria && typeof p.criteria === 'object' ? p.criteria : null;
  const targetValue = targetType === 'demographic_geo'
    ? JSON.stringify({
        minAge: Number.isFinite(Number(criteriaInput?.minAge)) ? Number(criteriaInput.minAge) : null,
        maxAge: Number.isFinite(Number(criteriaInput?.maxAge)) ? Number(criteriaInput.maxAge) : null,
        gender: String(criteriaInput?.gender || '').trim() || 'any',
        city: String(criteriaInput?.city || '').trim() || null,
        country: String(criteriaInput?.country || '').trim() || null,
        centerLat: Number.isFinite(Number(criteriaInput?.centerLat)) ? Number(criteriaInput.centerLat) : null,
        centerLng: Number.isFinite(Number(criteriaInput?.centerLng)) ? Number(criteriaInput.centerLng) : null,
        maxDistanceKm: Number.isFinite(Number(criteriaInput?.maxDistanceKm)) ? Number(criteriaInput.maxDistanceKm) : null,
      })
    : (String(p.targetValue || '').trim() || null);
  await client.query(
    `INSERT INTO offers (
      id, owner_id, offer_type, category, title_type, discount_type, discount_value, price,
      description, start_date, end_date, location, image_url, created_at,
      lifecycle_status, lifecycle_updated_at, lifecycle_reason
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,NOW(),'active',NOW(),$14
    )`,
    [
      offerId,
      req.user.userId,
      p.offerType || 'targeted',
      p.category || 'general',
      p.titleType || 'targeted_offer',
      p.discountType || null,
      p.discountValue || null,
      p.price || null,
      p.description || null,
      p.startDate || null,
      p.endDate || null,
      p.location || null,
      p.imageUrl || p.image || null,
      p.lifecycleReason || 'targeted_offer_created',
    ]
  );
  await client.query(
    `INSERT INTO offer_targeting_rules (offer_id, target_type, target_value, min_points, criteria_json)
     VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [offerId, targetType, targetValue, minPoints, targetType === 'demographic_geo' ? targetValue : null]
  );

  let audience = [];
  if (targetType === 'all') {
    audience = (await client.query('SELECT id FROM users ORDER BY created_at DESC LIMIT 1000')).rows;
  } else if (targetType === 'min_points') {
    audience = (await client.query(
      `SELECT u.id
         FROM users u
         JOIN point_accounts pa ON pa.owner_id = u.id
        WHERE pa.available_points >= $1
        ORDER BY pa.available_points DESC
        LIMIT 1000`,
      [minPoints || 0]
    )).rows;
  } else if (targetType === 'city') {
    audience = (await client.query(
      `SELECT id
         FROM users
        WHERE LOWER(COALESCE(city, '')) = LOWER($1)
        ORDER BY created_at DESC
        LIMIT 1000`,
      [targetValue || '']
    )).rows;
  } else if (targetType === 'demographic_geo') {
    const users = (await client.query(
      `SELECT u.id,
              u.city,
              u.country,
              u.gender,
              u.birth_date,
              cp.location_lat,
              cp.location_lng,
              COALESCE(pa.available_points, 0) AS available_points
         FROM users u
         LEFT JOIN customer_profiles cp ON cp.user_id = u.id
         LEFT JOIN point_accounts pa ON pa.owner_id = u.id
         ORDER BY u.created_at DESC
         LIMIT 2000`
    )).rows;
    audience = users.filter((u) => offerMatchesTargeting(
      {
        target_type: targetType,
        target_value: targetValue,
        criteria_json: targetType === 'demographic_geo' ? JSON.parse(targetValue) : null,
        min_points: minPoints,
      },
      {
        userId: u.id,
        city: u.city,
        country: u.country,
        gender: u.gender,
        age: calculateAgeYears(u.birth_date),
        locationLat: u.location_lat == null ? null : Number(u.location_lat),
        locationLng: u.location_lng == null ? null : Number(u.location_lng),
        availablePoints: Number(u.available_points || 0),
      }
    ));
  }

  for (const row of audience) {
    await insertNotification(
      client,
      row.id,
      'targeted_offer',
      'New targeted offer',
      p.description || 'You have a new offer tailored for you.',
      { offerId, targetType }
    );
  }

  return res.json({ ok: true, id: offerId, audienceSize: audience.length });
  } catch (e) {
    return res.status(500).json({ error: 'targeted_offer_create_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/offers/targeted/feed', auth, async (req, res) => {
  const userId = req.user.userId;
  const user = (await pool.query(
    `SELECT u.city,
            u.country,
            u.gender,
            u.birth_date,
            cp.location_lat,
            cp.location_lng
       FROM users u
       LEFT JOIN customer_profiles cp ON cp.user_id = u.id
      WHERE u.id = $1
      LIMIT 1`,
    [userId]
  )).rows[0] || {};
  const points = (await pool.query('SELECT available_points FROM point_accounts WHERE owner_id = $1 LIMIT 1', [userId])).rows[0]?.available_points || 0;

  const rows = (await pool.query(
    `SELECT o.*, otr.target_type, otr.target_value, otr.min_points, otr.criteria_json
       FROM offers o
       JOIN offer_targeting_rules otr ON otr.offer_id = o.id
      WHERE o.lifecycle_status = 'active'
      ORDER BY o.created_at DESC`
  )).rows;

  const eligible = rows.filter((row) => offerMatchesTargeting(row, {
    userId,
    city: user.city,
    country: user.country,
    gender: user.gender,
    age: calculateAgeYears(user.birth_date),
    locationLat: user.location_lat == null ? null : Number(user.location_lat),
    locationLng: user.location_lng == null ? null : Number(user.location_lng),
    availablePoints: Number(points || 0),
  }));

  return res.json(eligible.map((o) => ({
    id: o.id,
    offerType: o.offer_type,
    category: o.category,
    titleType: o.title_type,
    discountType: o.discount_type,
    discountValue: o.discount_value,
    price: o.price,
    description: o.description,
    startDate: toIso(o.start_date),
    endDate: toIso(o.end_date),
    location: o.location,
    imageUrl: o.image_url,
    targetType: o.target_type,
    targetValue: o.target_value,
    minPoints: o.min_points,
    createdAt: toIso(o.created_at),
  })));
});

app.get('/api/offers', auth, async (req, res) => {
  const { category, targetType, targetValue, minPoints } = req.query;

  const userRow = (await pool.query(
    `SELECT u.id,
            u.city,
            u.country,
            u.gender,
            u.birth_date,
            cp.location_lat,
            cp.location_lng
       FROM users u
       LEFT JOIN customer_profiles cp ON cp.user_id = u.id
      WHERE u.id = $1
      LIMIT 1`,
    [req.user.userId]
  )).rows[0] || {};
  const pointsRow = (await pool.query(
    'SELECT available_points FROM point_accounts WHERE owner_id = $1 LIMIT 1',
    [req.user.userId]
  )).rows[0] || {};

  const baseSql = category
    ? `SELECT o.*, otr.target_type, otr.target_value, otr.min_points, otr.criteria_json
         FROM offers o
         LEFT JOIN offer_targeting_rules otr ON otr.offer_id = o.id
        WHERE o.category = $1
        ORDER BY o.created_at DESC`
    : `SELECT o.*, otr.target_type, otr.target_value, otr.min_points, otr.criteria_json
         FROM offers o
         LEFT JOIN offer_targeting_rules otr ON otr.offer_id = o.id
        ORDER BY o.created_at DESC`;
  const params = category ? [category] : [];
  const rows = (await pool.query(baseSql, params)).rows;

  const userContext = {
    userId: req.user.userId,
    city: userRow.city,
    country: userRow.country,
    gender: userRow.gender,
    age: calculateAgeYears(userRow.birth_date),
    locationLat: userRow.location_lat == null ? null : Number(userRow.location_lat),
    locationLng: userRow.location_lng == null ? null : Number(userRow.location_lng),
    availablePoints: Number(pointsRow.available_points || 0),
  };

  let eligible = rows.filter((row) => offerMatchesTargeting(row, userContext));
  if (targetType) {
    const targetTypeRaw = String(targetType).toLowerCase();
    eligible = eligible.filter((row) => String(row.target_type || 'all').toLowerCase() === targetTypeRaw);
  }
  if (targetValue) {
    const tv = String(targetValue).toLowerCase();
    eligible = eligible.filter((row) => String(row.target_value || '').toLowerCase() === tv);
  }
  if (minPoints != null && String(minPoints).trim() !== '') {
    const mp = Number(minPoints);
    if (Number.isFinite(mp)) {
      eligible = eligible.filter((row) => Number(row.min_points || 0) >= mp);
    }
  }

  res.json(eligible.map((o) => ({
    id: o.id,
    offerType: o.offer_type,
    category: o.category,
    titleType: o.title_type,
    discountType: o.discount_type,
    discountValue: o.discount_value,
    price: o.price,
    description: o.description,
    startDate: toIso(o.start_date),
    endDate: toIso(o.end_date),
    location: o.location,
    image: o.image_url,
    imageUrl: o.image_url,
    createdAt: toIso(o.created_at),
    lifecycleStatus: o.lifecycle_status,
    lifecycleUpdatedAt: toIso(o.lifecycle_updated_at),
    lifecycleReason: o.lifecycle_reason,
    publishedAt: toIso(o.published_at),
    redeemedAt: toIso(o.redeemed_at),
    expiredAt: toIso(o.expired_at),
    archivedAt: toIso(o.archived_at),
    targetType: o.target_type || 'all',
    targetValue: o.target_value,
    minPoints: o.min_points,
    ctaType: o.cta_type || 'store',
    ctaValue: o.cta_value,
    impressions: Number(o.impressions || 0),
    clicks: Number(o.clicks || 0),
  })));
});

app.post('/api/offers', auth, async (req, res) => {
  const p = req.body || {};
  const offerId = id();
  await pool.query(
    `INSERT INTO offers (
      id, owner_id, offer_type, category, title_type, discount_type, discount_value, price,
      description, start_date, end_date, location, image_url, created_at,
      lifecycle_status, lifecycle_updated_at, lifecycle_reason, cta_type, cta_value
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,COALESCE($14::timestamptz,NOW()),
      'pending_review',NOW(),'created_from_api',$15,$16
    )`,
    [
      offerId, req.user.userId, p.offerType, p.category, p.titleType, p.discountType, p.discountValue, p.price,
      p.description, p.startDate, p.endDate, p.location, p.imageUrl || p.image, p.createdAt,
      String(p.ctaType || 'store'), String(p.ctaValue || '').trim() || null,
    ]
  );
  res.json({ id: offerId, ok: true });
});

app.get('/api/billboard-ads', auth, async (_req, res) => {
  const rows = (await pool.query(
    `SELECT id, offer_type, category, description, location, image_url, start_date, end_date,
            created_at, published_at
       FROM offers
      WHERE image_url IS NOT NULL
        AND image_url <> ''
        AND lifecycle_status = 'active'
        AND (start_date IS NULL OR start_date <= NOW())
        AND (end_date IS NULL OR end_date > NOW())
      ORDER BY published_at DESC NULLS LAST, created_at DESC
      LIMIT 30`
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    offerType: row.offer_type,
    category: row.category,
    description: row.description,
    location: row.location,
    imageUrl: row.image_url,
    startDate: toIso(row.start_date),
    endDate: toIso(row.end_date),
    createdAt: toIso(row.created_at),
    publishedAt: toIso(row.published_at),
  })));
});

app.post('/api/billboard-ads/:id/impression', auth, async (req, res) => {
  const result = await pool.query(
    `UPDATE offers SET impressions = impressions + 1
      WHERE id = $1 AND lifecycle_status = 'active' AND image_url IS NOT NULL
      RETURNING impressions`,
    [req.params.id]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, impressions: Number(result.rows[0].impressions || 0) });
});

app.post('/api/billboard-ads/:id/click', auth, async (req, res) => {
  const result = await pool.query(
    `UPDATE offers SET clicks = clicks + 1
      WHERE id = $1 AND lifecycle_status = 'active' AND image_url IS NOT NULL
      RETURNING clicks, cta_type, cta_value`,
    [req.params.id]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, clicks: Number(result.rows[0].clicks || 0), ctaType: result.rows[0].cta_type || 'store', ctaValue: result.rows[0].cta_value });
});

app.get('/api/admin/billboard-ads', auth, requireAdmin, async (_req, res) => {
  const rows = (await pool.query(
    `SELECT id, owner_id, offer_type, category, description, location, image_url,
            lifecycle_status, lifecycle_reason, created_at
       FROM offers
      WHERE image_url IS NOT NULL AND image_url <> ''
      ORDER BY created_at DESC
      LIMIT 200`
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    ownerId: row.owner_id,
    offerType: row.offer_type,
    category: row.category,
    description: row.description,
    location: row.location,
    imageUrl: row.image_url,
    lifecycleStatus: row.lifecycle_status,
    lifecycleReason: row.lifecycle_reason,
    createdAt: toIso(row.created_at),
  })));
});

app.post('/api/admin/billboard-ads/:id/approve', auth, requireAdmin, async (req, res) => {
  const result = await pool.query(
    `UPDATE offers
        SET lifecycle_status = 'active', lifecycle_updated_at = NOW(),
            lifecycle_reason = 'approved_by_admin', published_at = NOW()
      WHERE id = $1 AND image_url IS NOT NULL
      RETURNING id`,
    [req.params.id]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, status: 'active' });
});

app.post('/api/admin/billboard-ads/:id/reject', auth, requireAdmin, async (req, res) => {
  const reason = String((req.body || {}).reason || 'Rejected by admin').trim();
  const result = await pool.query(
    `UPDATE offers
        SET lifecycle_status = 'rejected', lifecycle_updated_at = NOW(), lifecycle_reason = $2
      WHERE id = $1 AND image_url IS NOT NULL
      RETURNING id`,
    [req.params.id, reason]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'billboard_ad_not_found' });
  return res.json({ ok: true, status: 'rejected', reason });
});

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

app.get('/api/blocks', auth, async (req, res) => {
  const rows = (await pool.query(
    `SELECT b.blocked_id, b.created_at, u.email
       FROM user_blocks b
       LEFT JOIN users u ON u.id = b.blocked_id
      WHERE b.blocker_id = $1
      ORDER BY b.created_at DESC`,
    [req.user.userId]
  )).rows;
  res.json(rows.map((r) => ({
    blockedUserId: r.blocked_id,
    blockedEmail: r.email,
    createdAt: toIso(r.created_at),
  })));
});

app.post('/api/users/:id/block', auth, async (req, res) => {
  const blockedId = String(req.params.id || '').trim();
  if (!blockedId) {
    return res.status(400).json({ error: 'blocked_user_required' });
  }
  if (blockedId === req.user.userId) {
    return res.status(400).json({ error: 'self_block_not_supported' });
  }
  const user = (await pool.query('SELECT id FROM users WHERE id = $1', [blockedId])).rows[0];
  if (!user) {
    return res.status(404).json({ error: 'user_not_found' });
  }
  await pool.query(
    'INSERT INTO user_blocks (blocker_id, blocked_id, created_at) VALUES ($1, $2, NOW()) ON CONFLICT (blocker_id, blocked_id) DO NOTHING',
    [req.user.userId, blockedId]
  );
  res.json({ ok: true });
});

app.post('/api/users/:id/unblock', auth, async (req, res) => {
  const blockedId = String(req.params.id || '').trim();
  if (!blockedId) {
    return res.status(400).json({ error: 'blocked_user_required' });
  }
  await pool.query(
    'DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2',
    [req.user.userId, blockedId]
  );
  res.json({ ok: true });
});

app.get('/api/users', auth, requireAdmin, async (_req, res) => {
  const rows = (await pool.query('SELECT id, email, role, full_name, gender, city, country, profile_completed, points, points_history, created_at FROM users ORDER BY created_at DESC LIMIT 200')).rows;
  res.json(rows.map((u) => ({
    id: u.id,
    email: u.email,
    role: u.role,
    fullName: u.full_name,
    full_name: u.full_name,
    gender: u.gender,
    city: u.city,
    country: u.country,
    profileCompleted: u.profile_completed,
    points: u.points,
    points_history: u.points_history || [],
    createdAt: toIso(u.created_at),
  })));
});

app.get('/api/users/:id', auth, async (req, res) => {
  if (!canAccessUserObject(req.user, req.params.id)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  const row = (await pool.query('SELECT id, email, role, full_name, gender, city, country, profile_completed, points, points_history, created_at FROM users WHERE id = $1', [req.params.id])).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  res.json({
    id: row.id,
    email: row.email,
    role: row.role,
    fullName: row.full_name,
    full_name: row.full_name,
    gender: row.gender,
    city: row.city,
    country: row.country,
    profileCompleted: row.profile_completed,
    points: row.points,
    points_history: row.points_history || [],
    createdAt: toIso(row.created_at),
  });
});

app.get('/api/customer/location/me', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    await ensureCustomerProfile(client, req.user.userId);
    const row = (await client.query(
      `SELECT location_lat, location_lng
         FROM customer_profiles
        WHERE user_id = $1
        LIMIT 1`,
      [req.user.userId]
    )).rows[0];
    return res.json({
      latitude: row?.location_lat == null ? null : Number(row.location_lat),
      longitude: row?.location_lng == null ? null : Number(row.location_lng),
    });
  } catch (e) {
    return res.status(500).json({ error: 'customer_location_fetch_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/customer/location/me', auth, async (req, res) => {
  const latitude = Number((req.body || {}).latitude);
  const longitude = Number((req.body || {}).longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ error: 'latitude_longitude_required' });
  }

  const client = await pool.connect();
  try {
    await ensureCustomerProfile(client, req.user.userId);
    await client.query(
      `UPDATE customer_profiles
          SET location_lat = $2,
              location_lng = $3
        WHERE user_id = $1`,
      [req.user.userId, latitude, longitude]
    );
    return res.json({ ok: true, latitude, longitude });
  } catch (e) {
    return res.status(500).json({ error: 'customer_location_update_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/users/:id/profile', auth, async (req, res) => {
  if (!canAccessUserObject(req.user, req.params.id)) {
    return res.status(403).json({ error: 'forbidden' });
  }
  const p = req.body || {};
  await pool.query(
    'UPDATE users SET full_name=$1, gender=$2, city=$3, country=$4, profile_completed=COALESCE($5, profile_completed) WHERE id=$6',
    [p.fullName || p.full_name || null, p.gender || null, p.city || null, p.country || null, p.profileCompleted, req.params.id]
  );
  res.json({ ok: true });
});

function mapRewardRow(r) {
  return {
    id: r.id,
    reward_name: r.reward_name,
    description: r.description,
    value: r.value,
    kind: r.kind || 'digital',
    sourceType: r.source_type || 'system',
    sourceId: r.source_id || r.id,
    storeName: r.store_name || null,
    imageUrl: r.image_url || null,
    expiresAt: toIso(r.expires_at),
    pickupInstructions: r.pickup_instructions || null,
    drawEnabled: r.draw_enabled === true,
    drawAt: toIso(r.draw_at),
    drawWinnerUserId: r.draw_winner_user_id || null,
    drawCompletedAt: toIso(r.draw_completed_at),
  };
}

const REWARDS_WITH_STORE_NAME_SQL = `
  SELECT r.*, COALESCE(m.business_name, b.business_name) AS store_name
  FROM rewards r
  LEFT JOIN merchant_profiles m ON r.source_type = 'merchant' AND m.id = r.source_id
  LEFT JOIN brand_profiles b ON r.source_type = 'brand' AND b.id = r.source_id
`;

app.get('/api/rewards', auth, async (_req, res) => {
  const rows = (await pool.query(
    `${REWARDS_WITH_STORE_NAME_SQL} WHERE r.is_active = TRUE AND (r.quantity_limit IS NULL OR r.quantity_redeemed < r.quantity_limit) AND (r.expires_at IS NULL OR r.expires_at > NOW()) ORDER BY r.value DESC`
  )).rows;
  res.json(rows.map(mapRewardRow));
});

app.get('/api/merchant/rewards', auth, async (req, res) => {
  const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
  if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
  const rows = (await pool.query(
    `${REWARDS_WITH_STORE_NAME_SQL} WHERE r.source_type = 'merchant' AND r.source_id = $1 ORDER BY r.created_at DESC`,
    [merchantId]
  )).rows;
  return res.json(rows.map((row) => ({ ...mapRewardRow(row), isActive: row.is_active, quantityLimit: row.quantity_limit, quantityRedeemed: row.quantity_redeemed })));
});

app.get('/api/brand/rewards', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const rows = (await pool.query(
    `${REWARDS_WITH_STORE_NAME_SQL} WHERE r.source_type = 'brand' AND r.source_id = $1 ORDER BY r.created_at DESC`,
    [brandId]
  )).rows;
  return res.json(rows.map((row) => ({ ...mapRewardRow(row), isActive: row.is_active, quantityLimit: row.quantity_limit, quantityRedeemed: row.quantity_redeemed, pickupInstructions: row.pickup_instructions, drawEnabled: row.draw_enabled, drawAt: toIso(row.draw_at) })));
});

app.get('/api/brand/products', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const rows = (await pool.query(
    `SELECT id, name, image_url, barcode, created_at
       FROM product_registry
      WHERE brand_id = $1
      ORDER BY created_at DESC`,
    [brandId]
  )).rows;
  return res.json(rows.map((row) => ({
    id: row.id,
    name: row.name,
    imageUrl: row.image_url,
    barcode: row.barcode,
    createdAt: toIso(row.created_at),
  })));
});

app.post('/api/brand/rewards', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const p = req.body || {};
  const name = String(p.rewardName || '').trim();
  const value = Number(p.value);
  const quantityLimit = p.quantityLimit == null || String(p.quantityLimit).trim() === '' ? null : Number(p.quantityLimit);
  if (!name || !Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_reward' });
  if (quantityLimit != null && (!Number.isInteger(quantityLimit) || quantityLimit <= 0)) return res.status(400).json({ error: 'invalid_quantity_limit' });
  const result = await pool.query(
    `INSERT INTO rewards (id, reward_name, description, value, kind, source_type, source_id, image_url, expires_at, is_active, quantity_limit, pickup_instructions, draw_enabled, draw_at)
     VALUES ($1,$2,$3,$4,$5,'brand',$6,$7,$8,TRUE,$9,$10,$11,$12) RETURNING id`,
    [id(), name, String(p.description || '').trim() || null, value, p.kind === 'physical' ? 'physical' : 'digital', brandId, String(p.imageUrl || '').trim() || null, p.expiresAt || null, quantityLimit, String(p.pickupInstructions || '').trim() || null, Boolean(p.drawEnabled), p.drawAt || null]
  );
  return res.json({ ok: true, id: result.rows[0].id, status: 'active' });
});

app.post('/api/brand/rewards/:id/draw', auth, async (req, res) => {
  const brandId = await getBrandProfileIdByUser(pool, req.user.userId);
  if (!brandId) return res.status(403).json({ error: 'brand_role_required' });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const reward = (await client.query(
      `SELECT id, reward_name, expires_at, draw_enabled, draw_winner_user_id
         FROM rewards
        WHERE id = $1 AND source_type = 'brand' AND source_id = $2
        FOR UPDATE`,
      [req.params.id, brandId]
    )).rows[0];
    if (!reward) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'reward_not_found' }); }
    if (!reward.draw_enabled) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'draw_not_enabled' }); }
    if (reward.draw_winner_user_id) { await client.query('ROLLBACK'); return res.json({ ok: true, winnerUserId: reward.draw_winner_user_id, alreadyCompleted: true }); }
    if (reward.expires_at && new Date(reward.expires_at) > new Date()) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'draw_not_due' }); }
    const candidates = (await client.query(
      `SELECT DISTINCT owner_id
         FROM reward_claims
        WHERE reward_id = $1 AND status IN ('pending_pickup', 'redeemed')`,
      [reward.id]
    )).rows;
    if (!candidates.length) { await client.query('ROLLBACK'); return res.status(400).json({ error: 'no_draw_candidates' }); }
    const winner = candidates[Math.floor(Math.random() * candidates.length)].owner_id;
    await client.query('UPDATE rewards SET draw_winner_user_id = $1, draw_completed_at = NOW() WHERE id = $2', [winner, reward.id]);
    await insertNotification(client, winner, 'reward_draw_winner', 'مبروك! فزت بالجائزة', `تم اختيارك عشوائياً للفوز بجائزة ${reward.reward_name}.`, { rewardId: reward.id });
    await client.query('COMMIT');
    return res.json({ ok: true, winnerUserId: winner });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'reward_draw_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/merchant/rewards', auth, async (req, res) => {
  const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
  if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
  const p = req.body || {};
  const name = String(p.rewardName || '').trim();
  const value = Number(p.value);
  const quantityLimit = p.quantityLimit == null || String(p.quantityLimit).trim() === '' ? null : Number(p.quantityLimit);
  if (!name || !Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_reward' });
  if (quantityLimit != null && (!Number.isInteger(quantityLimit) || quantityLimit <= 0)) return res.status(400).json({ error: 'invalid_quantity_limit' });
  const result = await pool.query(
    `INSERT INTO rewards (id, reward_name, description, value, kind, source_type, source_id, image_url, expires_at, is_active, quantity_limit)
     VALUES ($1,$2,$3,$4,$5,'merchant',$6,$7,$8,TRUE,$9) RETURNING id`,
    [id(), name, String(p.description || '').trim() || null, value, p.kind === 'digital' ? 'digital' : 'physical', merchantId, String(p.imageUrl || '').trim() || null, p.expiresAt || null, quantityLimit]
  );
  return res.json({ ok: true, id: result.rows[0].id, status: 'active' });
});

app.patch('/api/merchant/rewards/:id', auth, async (req, res) => {
  const merchantId = await getMerchantProfileIdByUser(pool, req.user.userId);
  if (!merchantId) return res.status(403).json({ error: 'merchant_role_required' });
  const p = req.body || {};
  const result = await pool.query(
    `UPDATE rewards SET is_active = COALESCE($1, is_active), quantity_limit = $2, expires_at = $3, description = COALESCE($4, description)
      WHERE id = $5 AND source_type = 'merchant' AND source_id = $6 RETURNING id`,
    [p.isActive == null ? null : Boolean(p.isActive), p.quantityLimit == null || String(p.quantityLimit).trim() === '' ? null : Number(p.quantityLimit), p.expiresAt || null, p.description == null ? null : String(p.description).trim(), req.params.id, merchantId]
  );
  if (!result.rowCount) return res.status(404).json({ error: 'reward_not_found' });
  return res.json({ ok: true });
});

app.get('/api/admin/rewards', auth, requireAdmin, async (_req, res) => {
  const rows = (await pool.query(`${REWARDS_WITH_STORE_NAME_SQL} ORDER BY r.value DESC`)).rows;
  res.json(rows.map(mapRewardRow));
});

async function validateRewardSource(sourceType, sourceId) {
  if (sourceType === 'merchant') {
    const found = await pool.query('SELECT 1 FROM merchant_profiles WHERE id = $1', [sourceId]);
    if (!found.rowCount) return 'merchant_not_found';
  } else if (sourceType === 'brand') {
    const found = await pool.query('SELECT 1 FROM brand_profiles WHERE id = $1', [sourceId]);
    if (!found.rowCount) return 'brand_not_found';
  }
  return null;
}

app.post('/api/admin/rewards', auth, requireAdmin, async (req, res) => {
  const p = req.body || {};
  const rewardName = String(p.rewardName || '').trim();
  if (!rewardName) return res.status(400).json({ error: 'reward_name_required' });
  const value = Number(p.value);
  if (!Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_value' });
  const kind = p.kind === 'physical' ? 'physical' : 'digital';
  const sourceType = ['merchant', 'brand', 'system'].includes(p.sourceType) ? p.sourceType : 'system';
  const sourceId = String(p.sourceId || '').trim();
  if (sourceType !== 'system' && !sourceId) return res.status(400).json({ error: 'source_id_required' });
  const sourceError = sourceType === 'system' ? null : await validateRewardSource(sourceType, sourceId);
  if (sourceError) return res.status(400).json({ error: sourceError });
  const description = String(p.description || '').trim() || null;
  const imageUrl = String(p.imageUrl || '').trim() || null;
  let expiresAt = null;
  if (p.expiresAt) {
    expiresAt = new Date(p.expiresAt);
    if (Number.isNaN(expiresAt.getTime())) return res.status(400).json({ error: 'invalid_expires_at' });
  }
  const rewardId = id();
  await pool.query(
    `INSERT INTO rewards (id, reward_name, description, value, kind, source_type, source_id, image_url, expires_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [rewardId, rewardName, description, value, kind, sourceType === 'system' ? null : sourceType, sourceType === 'system' ? null : sourceId, imageUrl, expiresAt]
  );
  res.json({ ok: true, id: rewardId });
});

app.put('/api/admin/rewards/:id', auth, requireAdmin, async (req, res) => {
  const existing = await pool.query('SELECT id FROM rewards WHERE id = $1', [req.params.id]);
  if (!existing.rowCount) return res.status(404).json({ error: 'reward_not_found' });
  const p = req.body || {};
  const rewardName = String(p.rewardName || '').trim();
  if (!rewardName) return res.status(400).json({ error: 'reward_name_required' });
  const value = Number(p.value);
  if (!Number.isInteger(value) || value <= 0) return res.status(400).json({ error: 'invalid_value' });
  const kind = p.kind === 'physical' ? 'physical' : 'digital';
  const sourceType = ['merchant', 'brand', 'system'].includes(p.sourceType) ? p.sourceType : 'system';
  const sourceId = String(p.sourceId || '').trim();
  if (sourceType !== 'system' && !sourceId) return res.status(400).json({ error: 'source_id_required' });
  const sourceError = sourceType === 'system' ? null : await validateRewardSource(sourceType, sourceId);
  if (sourceError) return res.status(400).json({ error: sourceError });
  const description = String(p.description || '').trim() || null;
  const imageUrl = String(p.imageUrl || '').trim() || null;
  let expiresAt = null;
  if (p.expiresAt) {
    expiresAt = new Date(p.expiresAt);
    if (Number.isNaN(expiresAt.getTime())) return res.status(400).json({ error: 'invalid_expires_at' });
  }
  await pool.query(
    `UPDATE rewards SET reward_name = $2, description = $3, value = $4, kind = $5,
       source_type = $6, source_id = $7, image_url = $8, expires_at = $9
     WHERE id = $1`,
    [req.params.id, rewardName, description, value, kind, sourceType === 'system' ? null : sourceType, sourceType === 'system' ? null : sourceId, imageUrl, expiresAt]
  );
  res.json({ ok: true });
});

app.delete('/api/admin/rewards/:id', auth, requireAdmin, async (req, res) => {
  const result = await pool.query('DELETE FROM rewards WHERE id = $1', [req.params.id]);
  if (!result.rowCount) return res.status(404).json({ error: 'reward_not_found' });
  res.json({ ok: true });
});

app.get('/api/activity-logs', auth, async (req, res) => {
  const email = String(req.query.customerEmail || '').trim().toLowerCase();
  if (!email) return res.json([]);
  const rows = (await pool.query('SELECT * FROM activity_logs WHERE customer_email = $1 ORDER BY transaction_date DESC', [email])).rows;
  res.json(rows.map((a) => ({ id: a.id, customerEmail: a.customer_email, amount: Number(a.amount), transaction_date: toIso(a.transaction_date) })));
});

app.post('/api/invoices/scan', auth, async (req, res) => {
  const p = req.body || {};
  const rawText = String(p.rawText || '').trim();
  if (!rawText) {
    return res.status(400).json({ error: 'raw_text_required' });
  }

  const ownerId = req.user.userId;
  const merchantName = String(p.merchantName || '').trim() || 'غير معروف';
  const merchantKey = normalizeMerchantKey(merchantName);
  const invoiceNumber = String(p.invoiceNumber || '').trim() || null;
  const orderNumber = String(p.orderNumber || '').trim() || null;
  const invoiceDate = String(p.invoiceDate || '').trim() || null;
  const category = String(p.category || 'general').trim() || 'general';
  const currency = String(p.currency || 'SAR').trim() || 'SAR';
  const items = Array.isArray(p.items) ? p.items : [];
  const imageBase64 = String(p.imageBase64 || '').trim();

  const amountRaw = p.totalAmount;
  const amount = amountRaw == null ? null : Number(amountRaw);
  const totalAmount = Number.isFinite(amount) && amount > 0 ? amount : null;
  const parsedDate = parseFlexibleDate(invoiceDate);
  const parsedDateIso = parsedDate ? parsedDate.toISOString().slice(0, 10) : null;
  const invoiceFingerprint = buildInvoiceFingerprint({
    merchantKey,
    invoiceNumber,
    orderNumber,
    invoiceDate: parsedDateIso,
    totalAmount,
    category,
    rawText,
    items,
  });

  if (parsedDate) {
    const now = new Date();
    const days = Math.floor((now.getTime() - parsedDate.getTime()) / (1000 * 60 * 60 * 24));
    if (days > 45) {
      return res.json({ ok: false, tooOld: true, maxAgeDays: 45 });
    }
  }

  const customerRow = (await pool.query('SELECT email FROM users WHERE id = $1', [ownerId])).rows[0];
  const customerEmail = customerRow ? String(customerRow.email || '').toLowerCase() : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const duplicate = (await client.query(
      `SELECT id
         FROM invoice_scans
        WHERE owner_id = $1
          AND invoice_fingerprint = $2
        LIMIT 1`,
      [ownerId, invoiceFingerprint]
    )).rows[0];

    const legacyDuplicate = duplicate || (await client.query(
      `SELECT id
         FROM invoice_scans
        WHERE owner_id = $1
          AND merchant_key = $2
          AND COALESCE(invoice_number, '') = COALESCE($3, '')
          AND COALESCE(order_number, '') = COALESCE($4, '')
          AND COALESCE(invoice_date::text, '') = COALESCE($5, '')
          AND COALESCE(total_amount::text, '') = COALESCE($6::text, '')
        LIMIT 1`,
      [ownerId, merchantKey, invoiceNumber, orderNumber, parsedDateIso, totalAmount]
    )).rows[0];

    if (duplicate || legacyDuplicate) {
      await client.query('ROLLBACK');
      return res.json({ ok: false, duplicate: true, duplicateId: (duplicate || legacyDuplicate).id });
    }

    const merchantProfileId = await resolveMerchantProfileIdByKey(client, merchantKey);

    const scanId = id();
    
    let originalImagePath = null;
    if (imageBase64) {
      try {
        const buffer = Buffer.from(imageBase64, 'base64');
        const filename = `${scanId}.jpg`;
        const filepath = path.join(INVOICES_UPLOAD_DIR, filename);
        fs.writeFileSync(filepath, buffer);
        originalImagePath = `uploads/invoices/${filename}`;
      } catch (err) {
        console.error('Failed to save invoice image:', err);
      }
    }

    await client.query(
      `INSERT INTO invoice_scans (
        id, owner_id, merchant_name, merchant_key, invoice_fingerprint, invoice_number, order_number, invoice_date,
        total_amount, currency, category, raw_text, reward_applied, branch_id, merchant_profile_id, original_image_path
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16
      )`,
      [
        scanId,
        ownerId,
        merchantName,
        merchantKey,
        invoiceFingerprint,
        invoiceNumber,
        orderNumber,
        parsedDateIso,
        totalAmount,
        currency,
        category,
        rawText,
        false,
        String(p.branchId || '').trim() || null,
        merchantProfileId,
        originalImagePath,
      ]
    );

    // Persist each purchased item so it survives beyond the scan: needed both to let
    // brand-owned products earn brand points below, and for future purchase analytics.
    const savedLineItems = [];
    for (const rawItem of items) {
      const name = String((rawItem && rawItem.name) || '').trim();
      if (!name) continue;
      let quantity = Number(rawItem && rawItem.quantity);
      let unitPrice = Number(rawItem && rawItem.unitPrice);
      let lineTotal = Number(rawItem && rawItem.lineTotal);
      quantity = Number.isFinite(quantity) && quantity > 0 ? Math.round(quantity) : null;
      unitPrice = Number.isFinite(unitPrice) && unitPrice > 0 ? Number(unitPrice.toFixed(2)) : null;
      lineTotal = Number.isFinite(lineTotal) && lineTotal > 0 ? Number(lineTotal.toFixed(2)) : null;
      if (unitPrice == null && quantity != null && lineTotal != null && quantity > 0) {
        unitPrice = Number((lineTotal / quantity).toFixed(2));
      }
      if (lineTotal == null && quantity != null && unitPrice != null) {
        lineTotal = Number((quantity * unitPrice).toFixed(2));
      }
      const lineItemId = id();
      await client.query(
        'INSERT INTO invoice_line_items (id, invoice_scan_id, item_name, quantity, unit_price, line_total) VALUES ($1,$2,$3,$4,$5,$6)',
        [lineItemId, scanId, name, quantity, unitPrice, lineTotal]
      );
      savedLineItems.push({ id: lineItemId, name });
    }

    for (const lineItem of savedLineItems) {
      const match = await autoMatchLineItemToBrand(client, lineItem.name);
      if (match) {
        await client.query(
          'INSERT INTO brand_matches (id, invoice_line_item_id, brand_id, product_id, confidence) VALUES ($1,$2,$3,$4,$5)',
          [id(), lineItem.id, match.brandId, match.productId, 0.5]
        );
      }
    }

    // Award points: prefer the real merchant/brand split (uses each party's own point_value
    // and the actual matched line-item amounts) and only fall back to the flat generic
    // cashback rate when neither the merchant nor any brand could be resolved, so existing
    // un-onboarded shops keep earning points exactly as before.
    let awards = null;
    let fallbackReward = null;
    let rewardApplied = false;
    if (totalAmount != null && totalAmount > 0) {
      awards = await applyInvoiceApprovalRewards(client, scanId, ownerId, merchantProfileId);
      const splitPoints = (awards.merchantPoints || 0) + (awards.brandPoints || 0);
      if (splitPoints > 0) {
        rewardApplied = true;
      } else {
        const cashback = Number((totalAmount * 0.05).toFixed(2));
        const earnedPoints = Math.floor(totalAmount);
        await client.query("INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,'SAR',NOW()) ON CONFLICT (owner_id) DO NOTHING", [ownerId]);
        await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [ownerId]);
        await client.query('UPDATE wallet_accounts SET balance = balance + $1, updated_at = NOW() WHERE owner_id = $2', [cashback, ownerId]);
        await client.query('UPDATE point_accounts SET available_points = available_points + $1, lifetime_points = lifetime_points + $1, updated_at = NOW() WHERE owner_id = $2', [earnedPoints, ownerId]);
        await client.query('UPDATE users SET points = points + $1, points_history = points_history || to_jsonb($2::int) WHERE id = $3', [earnedPoints, earnedPoints, ownerId]);
        const reference = invoiceNumber ? `invoice:${invoiceNumber}` : (orderNumber ? `order:${orderNumber}` : `invoice:${scanId}`);
        await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), ownerId, 'cashbackEarned', cashback, 0, reference]);
        await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), ownerId, 'pointsEarned', 0, earnedPoints, reference]);
        fallbackReward = { cashback, earnedPoints };
        rewardApplied = earnedPoints > 0;
      }
      if (rewardApplied) {
        await client.query('UPDATE invoice_scans SET reward_applied = TRUE WHERE id = $1', [scanId]);
      }
    }

    if (customerEmail && totalAmount != null) {
      await client.query(
        'INSERT INTO activity_logs (id, customer_email, amount, transaction_date) VALUES ($1,$2,$3,NOW())',
        [id(), customerEmail, totalAmount]
      );
    }

    await client.query('COMMIT');
    return res.json({
      ok: true,
      id: scanId,
      ownerId,
      merchantName,
      merchantKey,
      merchantProfileId,
      orderNumber,
      totalAmount,
      category,
      rewardApplied,
      awards,
      fallbackReward,
      itemsSaved: savedLineItems.length,
    });
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: 'save_invoice_scan_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/invoices/analyze-ai', auth, async (req, res) => {
  const p = req.body || {};
  const rawText = String(p.rawText || '').trim();
  const imageBase64 = String(p.imageBase64 || '').trim();
  const mimeType = String(p.mimeType || 'image/jpeg').trim() || 'image/jpeg';

  if (!rawText && !imageBase64) {
    return res.status(400).json({ error: 'raw_text_or_image_required' });
  }

  try {
    const result = await analyzeInvoiceWithGemini({ rawText, imageBase64, mimeType });
    return res.json(result);
  } catch (e) {
    return res.status(500).json({
      ok: false,
      error: 'analyze_invoice_ai_failed',
      details: String(e.message || e),
    });
  }
});

app.get('/api/invoices/my', auth, async (req, res) => {
  const ownerId = req.user.userId;
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query(
    `SELECT *
       FROM invoice_scans
      WHERE owner_id = $1
      ORDER BY created_at DESC
      LIMIT $2`,
    [ownerId, limit]
  )).rows;

  res.json(rows.map((row) => ({
    id: row.id,
    ownerId: row.owner_id,
    branchId: row.branch_id,
    merchantName: row.merchant_name,
    merchantKey: row.merchant_key,
    invoiceNumber: row.invoice_number,
    orderNumber: row.order_number,
    invoiceDate: row.invoice_date,
    totalAmount: row.total_amount == null ? null : Number(row.total_amount),
    currency: row.currency,
    category: row.category,
    state: row.state,
    reviewNote: row.review_note,
    rewardApplied: Boolean(row.reward_applied),
    rawText: row.raw_text,
    createdAt: toIso(row.created_at),
  })));
});

function analyticsRangeDays(value) {
  switch (String(value || '30d').trim()) {
    case '7d':
      return 7;
    case '90d':
      return 90;
    default:
      return 30;
  }
}

function analyticsDaysAgo(days) {
  return new Date(Date.now() - (days * 24 * 60 * 60 * 1000));
}

function analyticsSafeNumber(value) {
  const parsed = Number(value || 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function analyticsPercentChange(current, previous) {
  const currentValue = analyticsSafeNumber(current);
  const previousValue = analyticsSafeNumber(previous);
  if (previousValue === 0) {
    return currentValue > 0 ? 100 : 0;
  }
  return Number((((currentValue - previousValue) / previousValue) * 100).toFixed(2));
}

function analyticsAgeBucket(birthDateValue) {
  if (!birthDateValue) return 'unknown';
  const birthDate = new Date(birthDateValue);
  if (Number.isNaN(birthDate.getTime())) return 'unknown';
  const now = new Date();
  let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - birthDate.getUTCMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < birthDate.getUTCDate())) {
    age -= 1;
  }
  if (!Number.isFinite(age) || age < 18) return '<18';
  if (age <= 24) return '18-24';
  if (age <= 34) return '25-34';
  if (age <= 44) return '35-44';
  if (age <= 54) return '45-54';
  return '55+';
}

function analyticsCountEntries(input) {
  return Object.entries(input)
    .map(([label, value]) => ({ label, value: Number(value || 0) }))
    .sort((a, b) => b.value - a.value || String(a.label).localeCompare(String(b.label)));
}

function analyticsTopEntries(input, mapper) {
  return Object.values(input)
    .sort((a, b) => analyticsSafeNumber(b.salesTotal || b.value) - analyticsSafeNumber(a.salesTotal || a.value))
    .slice(0, 8)
    .map(mapper);
}

app.get('/api/merchant/analytics', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const rangeDays = analyticsRangeDays(req.query.range);
    const currentStart = analyticsDaysAgo(rangeDays);
    const previousStart = analyticsDaysAgo(rangeDays * 2);
    const branchId = String(req.query.branchId || '').trim() || null;

    const profileRow = (await client.query(
      `SELECT id, business_name, point_value
         FROM merchant_profiles
        WHERE id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0];

    const branchRows = (await client.query(
      `SELECT id, name, address, latitude, longitude
         FROM branches
        WHERE merchant_id = $1
        ORDER BY created_at ASC`,
      [merchantId]
    )).rows;

    const invoiceParams = [merchantId, previousStart.toISOString()];
    let branchFilterClause = '';
    if (branchId) {
      invoiceParams.push(branchId);
      branchFilterClause = ` AND COALESCE(i.branch_id, '') = $${invoiceParams.length}`;
    }

    const invoiceRows = (await client.query(
      `SELECT i.id,
              i.owner_id,
              i.total_amount,
              i.category,
              i.created_at,
              i.branch_id,
              COALESCE(u.full_name, u.email, i.owner_id) AS customer_label,
              COALESCE(u.gender, 'unknown') AS gender,
              u.birth_date,
              cp.location_lat,
              cp.location_lng
         FROM invoice_scans i
         LEFT JOIN users u ON u.id = i.owner_id
         LEFT JOIN customer_profiles cp ON cp.user_id = i.owner_id
        WHERE i.merchant_profile_id = $1
          AND i.state = 'approved'
          AND i.created_at >= $2${branchFilterClause}
        ORDER BY i.created_at DESC`,
      invoiceParams
    )).rows;

    const historyParams = [merchantId];
    let historyBranchClause = '';
    if (branchId) {
      historyParams.push(branchId);
      historyBranchClause = ` AND COALESCE(branch_id, '') = $${historyParams.length}`;
    }

    const customerHistoryRows = (await client.query(
      `SELECT owner_id, MIN(created_at) AS first_purchase_at
         FROM invoice_scans
        WHERE merchant_profile_id = $1
          AND state = 'approved'${historyBranchClause}
        GROUP BY owner_id`,
      historyParams
    )).rows;

    const currentRows = invoiceRows.filter((row) => new Date(row.created_at) >= currentStart);
    const previousRows = invoiceRows.filter((row) => {
      const createdAt = new Date(row.created_at);
      return createdAt >= previousStart && createdAt < currentStart;
    });

    const currentSales = currentRows.reduce((sum, row) => sum + analyticsSafeNumber(row.total_amount), 0);
    const previousSales = previousRows.reduce((sum, row) => sum + analyticsSafeNumber(row.total_amount), 0);
    const averageBill = currentRows.length === 0 ? 0 : Number((currentSales / currentRows.length).toFixed(2));

    const currentCustomerIds = new Set(currentRows.map((row) => String(row.owner_id || '')).filter(Boolean));
    const previousCustomerIds = new Set(previousRows.map((row) => String(row.owner_id || '')).filter(Boolean));
    const retainedCustomerCount = Array.from(previousCustomerIds).filter((customerId) => currentCustomerIds.has(customerId)).length;

    const newCustomerCount = customerHistoryRows.filter((row) => {
      const ownerId = String(row.owner_id || '');
      if (!currentCustomerIds.has(ownerId)) return false;
      const firstPurchaseAt = new Date(row.first_purchase_at);
      return !Number.isNaN(firstPurchaseAt.getTime()) && firstPurchaseAt >= currentStart;
    }).length;
    const returningCustomerCount = Math.max(0, currentCustomerIds.size - newCustomerCount);
    const retentionRate = previousCustomerIds.size === 0
      ? (currentCustomerIds.size > 0 ? 1 : 0)
      : retainedCustomerCount / previousCustomerIds.size;
    const churnRate = previousCustomerIds.size === 0 ? 0 : 1 - retentionRate;

    const uniqueCustomerRows = [];
    const uniqueCustomerSeen = new Set();
    const genderCounts = {};
    const ageCounts = {};
    const customerHeatmap = {};
    const hourCounts = {};
    const weekdayCounts = {};

    for (const row of currentRows) {
      const createdAt = new Date(row.created_at);
      if (!Number.isNaN(createdAt.getTime())) {
        const hourKey = `${createdAt.getUTCHours().toString().padStart(2, '0')}:00`;
        hourCounts[hourKey] = (hourCounts[hourKey] || 0) + 1;
        const weekdayKey = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][createdAt.getUTCDay()];
        weekdayCounts[weekdayKey] = (weekdayCounts[weekdayKey] || 0) + 1;
      }

      const ownerId = String(row.owner_id || '');
      if (!ownerId || uniqueCustomerSeen.has(ownerId)) continue;
      uniqueCustomerSeen.add(ownerId);
      uniqueCustomerRows.push(row);

      const genderKey = String(row.gender || 'unknown').trim().toLowerCase() || 'unknown';
      genderCounts[genderKey] = (genderCounts[genderKey] || 0) + 1;

      const ageKey = analyticsAgeBucket(row.birth_date);
      ageCounts[ageKey] = (ageCounts[ageKey] || 0) + 1;

      if (row.location_lat != null && row.location_lng != null) {
        customerHeatmap[ownerId] = {
          id: ownerId,
          label: row.customer_label,
          latitude: Number(row.location_lat),
          longitude: Number(row.location_lng),
          value: 1,
        };
      }
    }

    const pointsRow = (await client.query(
      `SELECT COALESCE(SUM(points_delta), 0) AS total_points
         FROM points_ledger_merchant
        WHERE merchant_id = $1
          AND created_at >= $2`,
      [merchantId, currentStart.toISOString()]
    )).rows[0];

    const offerRows = (await client.query(
      `SELECT category, lifecycle_status, created_at
         FROM offers
        WHERE owner_id = $1
        ORDER BY created_at DESC`,
      [req.user.userId]
    )).rows;
    const currentOffers = offerRows.filter((row) => new Date(row.created_at) >= currentStart);
    const offerCategories = {};
    const offerStatuses = {};
    for (const row of currentOffers) {
      const categoryKey = String(row.category || 'other').trim() || 'other';
      const statusKey = String(row.lifecycle_status || 'unknown').trim() || 'unknown';
      offerCategories[categoryKey] = (offerCategories[categoryKey] || 0) + 1;
      offerStatuses[statusKey] = (offerStatuses[statusKey] || 0) + 1;
    }
    const topOfferCategory = analyticsCountEntries(offerCategories)[0]?.label || '-';

    const groupRow = (await client.query(
      `SELECT cg.id,
              cg.name,
              (SELECT COUNT(*)::int FROM community_group_members gm WHERE gm.group_id = cg.id) AS members_count,
              (SELECT COUNT(*)::int FROM community_messages cm WHERE cm.group_id = cg.id AND cm.created_at >= $2) AS messages_count
         FROM community_groups cg
        WHERE cg.role_type = 'merchant'
          AND cg.role_profile_id = $1
        LIMIT 1`,
      [merchantId, currentStart.toISOString()]
    )).rows[0];

    const topProductParams = [merchantId, currentStart.toISOString()];
    let topProductBranchClause = '';
    if (branchId) {
      topProductParams.push(branchId);
      topProductBranchClause = ` AND COALESCE(i.branch_id, '') = $${topProductParams.length}`;
    }
    const topProductRows = (await client.query(
      `SELECT COALESCE(pr.name, li.item_name, 'Unknown') AS product_name,
              COALESCE(bp.business_name, 'Unknown brand') AS brand_name,
              COALESCE(SUM(COALESCE(li.line_total, 0)), 0) AS sales_total,
              COALESCE(SUM(COALESCE(li.quantity, 1)), 0) AS quantity_total
         FROM invoice_scans i
         JOIN invoice_line_items li ON li.invoice_scan_id = i.id
         LEFT JOIN brand_matches bm ON bm.invoice_line_item_id = li.id
         LEFT JOIN product_registry pr ON pr.id = bm.product_id
         LEFT JOIN brand_profiles bp ON bp.id = bm.brand_id
        WHERE i.merchant_profile_id = $1
          AND i.state = 'approved'
          AND i.created_at >= $2${topProductBranchClause}
        GROUP BY COALESCE(pr.name, li.item_name, 'Unknown'), COALESCE(bp.business_name, 'Unknown brand')
        ORDER BY COALESCE(SUM(COALESCE(li.line_total, 0)), 0) DESC,
                 COALESCE(SUM(COALESCE(li.quantity, 1)), 0) DESC
        LIMIT 8`,
      topProductParams
    )).rows;

    const loyaltyRow = (await client.query(
      `SELECT score, trend
         FROM loyalty_health_scores
        WHERE merchant_id = $1
        ORDER BY generated_at DESC
        LIMIT 1`,
      [merchantId]
    )).rows[0];

    const peakHour = analyticsCountEntries(hourCounts)[0]?.label || '-';
    const peakDay = analyticsCountEntries(weekdayCounts)[0]?.label || '-';
    const branchScope = branchId
      ? branchRows.find((row) => String(row.id || '') === branchId) || null
      : null;

    return res.json({
      ok: true,
      merchantId,
      merchantName: profileRow?.business_name || null,
      branchScope: branchScope ? { id: branchScope.id, name: branchScope.name } : null,
      branches: branchRows.map((row) => ({
        id: row.id,
        name: row.name,
        address: row.address,
        latitude: row.latitude == null ? null : Number(row.latitude),
        longitude: row.longitude == null ? null : Number(row.longitude),
      })),
      sales: {
        total: Number(currentSales.toFixed(2)),
        invoiceCount: currentRows.length,
        averageBill,
        pointsAwarded: Number(pointsRow?.total_points || 0),
        salesGrowthPercent: analyticsPercentChange(currentSales, previousSales),
      },
      customers: {
        unique: currentCustomerIds.size,
        newCount: newCustomerCount,
        returningCount: returningCustomerCount,
        retentionPercent: Number((retentionRate * 100).toFixed(2)),
        churnPercent: Number((churnRate * 100).toFixed(2)),
      },
      demographics: {
        gender: analyticsCountEntries(genderCounts),
        ageBuckets: analyticsCountEntries(ageCounts),
      },
      customerHeatmap: Object.values(customerHeatmap),
      offerPerformance: {
        totalOffers: currentOffers.length,
        topCategory: topOfferCategory,
        statusBreakdown: analyticsCountEntries(offerStatuses),
      },
      peakTimes: {
        peakHour,
        peakDay,
        byHour: analyticsCountEntries(hourCounts),
        byWeekday: analyticsCountEntries(weekdayCounts),
      },
      groupMetrics: {
        groups: groupRow ? 1 : 0,
        groupName: groupRow?.name || null,
        members: Number(groupRow?.members_count || 0),
        messages: Number(groupRow?.messages_count || 0),
      },
      topBrandProducts: topProductRows.map((row) => ({
        name: row.product_name,
        brandName: row.brand_name,
        salesTotal: Number(row.sales_total || 0),
        quantity: Number(row.quantity_total || 0),
      })),
      financialSummary: {
        pointValue: Number(profileRow?.point_value || 0),
        branches: branchRows.length,
        totalSales: Number(currentSales.toFixed(2)),
        pointsAwarded: Number(pointsRow?.total_points || 0),
        averageBill,
      },
      loyaltyHealth: {
        score: Number(loyaltyRow?.score || 50),
        trend: loyaltyRow?.trend || 'stable',
      },
      topCustomersCount: uniqueCustomerRows.length,
    });
  } catch (e) {
    return res.status(500).json({ error: 'merchant_analytics_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/brand/analytics', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) {
      return res.status(403).json({ error: 'brand_role_required' });
    }

    const rangeDays = analyticsRangeDays(req.query.range);
    const currentStart = analyticsDaysAgo(rangeDays);
    const previousStart = analyticsDaysAgo(rangeDays * 2);

    const rows = (await client.query(
      `SELECT i.owner_id,
              i.created_at,
              i.merchant_profile_id,
              COALESCE(mp.business_name, i.merchant_name, 'Unknown merchant') AS merchant_name,
              mp.user_id AS merchant_user_id,
              mp.phone AS merchant_phone,
              mp.location_address AS merchant_address,
              mp.location_lat,
              mp.location_lng,
              COALESCE(pr.name, li.item_name, 'Unknown') AS product_name,
              COALESCE(li.quantity, 1) AS quantity,
              COALESCE(li.line_total, 0) AS line_total,
              COALESCE(u.gender, 'unknown') AS gender,
              u.birth_date
         FROM brand_matches bm
         JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
         JOIN invoice_scans i ON i.id = li.invoice_scan_id
         LEFT JOIN product_registry pr ON pr.id = bm.product_id
         LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
         LEFT JOIN users u ON u.id = i.owner_id
        WHERE bm.brand_id = $1
          AND i.state = 'approved'
          AND i.created_at >= $2
        ORDER BY i.created_at DESC`,
      [brandId, previousStart.toISOString()]
    )).rows;

    const currentRows = rows.filter((row) => new Date(row.created_at) >= currentStart);
    const previousRows = rows.filter((row) => {
      const createdAt = new Date(row.created_at);
      return createdAt >= previousStart && createdAt < currentStart;
    });

    const storeCurrent = {};
    const storePrevious = {};
    const productCurrent = {};
    const productPrevious = {};
    const genderCounts = {};
    const ageCounts = {};
    const merchantHeatmap = {};
    const dailySales = {};
    const uniqueCustomers = new Set();

    for (const row of currentRows) {
      const merchantKey = String(row.merchant_profile_id || row.merchant_name || 'unknown');
      const productKey = String(row.product_name || 'Unknown');
      const salesValue = analyticsSafeNumber(row.line_total);
      const quantityValue = analyticsSafeNumber(row.quantity);
      const day = new Date(row.created_at).toISOString().slice(0, 10);
      dailySales[day] = (dailySales[day] || 0) + salesValue;

      if (!storeCurrent[merchantKey]) {
        storeCurrent[merchantKey] = {
          key: merchantKey,
          name: row.merchant_name,
          salesTotal: 0,
          quantity: 0,
          userId: row.merchant_user_id,
          phone: row.merchant_phone,
          address: row.merchant_address,
        };
      }
      storeCurrent[merchantKey].salesTotal += salesValue;
      storeCurrent[merchantKey].quantity += quantityValue;

      if (!productCurrent[productKey]) {
        productCurrent[productKey] = {
          name: productKey,
          salesTotal: 0,
          quantity: 0,
        };
      }
      productCurrent[productKey].salesTotal += salesValue;
      productCurrent[productKey].quantity += quantityValue;

      if (row.location_lat != null && row.location_lng != null) {
        merchantHeatmap[merchantKey] = {
          id: merchantKey,
          label: row.merchant_name,
          latitude: Number(row.location_lat),
          longitude: Number(row.location_lng),
          value: Number(storeCurrent[merchantKey].salesTotal.toFixed(2)),
        };
      }

      const ownerId = String(row.owner_id || '');
      if (!ownerId || uniqueCustomers.has(ownerId)) continue;
      uniqueCustomers.add(ownerId);

      const genderKey = String(row.gender || 'unknown').trim().toLowerCase() || 'unknown';
      genderCounts[genderKey] = (genderCounts[genderKey] || 0) + 1;

      const ageKey = analyticsAgeBucket(row.birth_date);
      ageCounts[ageKey] = (ageCounts[ageKey] || 0) + 1;
    }

    for (const row of previousRows) {
      const merchantKey = String(row.merchant_profile_id || row.merchant_name || 'unknown');
      const productKey = String(row.product_name || 'Unknown');
      const salesValue = analyticsSafeNumber(row.line_total);
      const quantityValue = analyticsSafeNumber(row.quantity);

      if (!storePrevious[merchantKey]) {
        storePrevious[merchantKey] = { salesTotal: 0, quantity: 0 };
      }
      storePrevious[merchantKey].salesTotal += salesValue;
      storePrevious[merchantKey].quantity += quantityValue;

      if (!productPrevious[productKey]) {
        productPrevious[productKey] = { salesTotal: 0, quantity: 0 };
      }
      productPrevious[productKey].salesTotal += salesValue;
      productPrevious[productKey].quantity += quantityValue;
    }

    const topSellingStores = analyticsTopEntries(storeCurrent, (entry) => ({
      name: entry.name,
      salesTotal: Number(entry.salesTotal.toFixed(2)),
      quantity: Number(entry.quantity || 0),
      key: entry.key,
      userId: entry.userId,
      phone: entry.phone,
      address: entry.address,
    }));
    const lowestSellingStores = Object.values(storeCurrent)
      .sort((a, b) => analyticsSafeNumber(a.salesTotal) - analyticsSafeNumber(b.salesTotal))
      .slice(0, 8)
      .map((entry) => ({
        name: entry.name,
        salesTotal: Number(analyticsSafeNumber(entry.salesTotal).toFixed(2)),
        quantity: Number(entry.quantity || 0),
        key: entry.key,
        userId: entry.userId,
        phone: entry.phone,
        address: entry.address,
      }));
    const topProducts = analyticsTopEntries(productCurrent, (entry) => ({
      name: entry.name,
      salesTotal: Number(entry.salesTotal.toFixed(2)),
      quantity: Number(entry.quantity || 0),
    }));

    const topStore = topSellingStores[0];
    const topProduct = topProducts[0];
    const currentTotal = currentRows.reduce((sum, row) => sum + analyticsSafeNumber(row.line_total), 0);
    const previousTotal = previousRows.reduce((sum, row) => sum + analyticsSafeNumber(row.line_total), 0);

    return res.json({
      ok: true,
      brandId,
      distributionHeatmap: Object.values(merchantHeatmap),
      topSellingStores,
      lowestSellingStores,
      topProducts,
      dailySales: Object.entries(dailySales)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, sales]) => ({ date, sales: Number(Number(sales).toFixed(2)) })),
      growthLevels: [
        {
          level: 'overall',
          label: 'Overall brand sales',
          current: Number(currentTotal.toFixed(2)),
          previous: Number(previousTotal.toFixed(2)),
          growthPercent: analyticsPercentChange(currentTotal, previousTotal),
        },
        {
          level: 'store',
          label: topStore?.name || 'Top store',
          current: Number(analyticsSafeNumber(topStore?.salesTotal).toFixed(2)),
          previous: Number(analyticsSafeNumber(storePrevious[topStore?.key || '']?.salesTotal).toFixed(2)),
          growthPercent: analyticsPercentChange(
            analyticsSafeNumber(topStore?.salesTotal),
            analyticsSafeNumber(storePrevious[topStore?.key || '']?.salesTotal)
          ),
        },
        {
          level: 'product',
          label: topProduct?.name || 'Top product',
          current: Number(analyticsSafeNumber(topProduct?.salesTotal).toFixed(2)),
          previous: Number(analyticsSafeNumber(productPrevious[topProduct?.name || '']?.salesTotal).toFixed(2)),
          growthPercent: analyticsPercentChange(
            analyticsSafeNumber(topProduct?.salesTotal),
            analyticsSafeNumber(productPrevious[topProduct?.name || '']?.salesTotal)
          ),
        },
      ],
      consumerDemographics: {
        gender: analyticsCountEntries(genderCounts),
        ageBuckets: analyticsCountEntries(ageCounts),
      },
      matchedCustomers: uniqueCustomers.size,
      matchedSales: Number(currentTotal.toFixed(2)),
    });
  } catch (e) {
    return res.status(500).json({ error: 'brand_analytics_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/customers/top', auth, async (req, res) => {
  const merchantName = String(req.query.merchantName || '').trim();
  if (!merchantName) {
    return res.status(400).json({ error: 'merchant_name_required' });
  }
  const merchantKey = normalizeMerchantKey(merchantName);
  const limit = Math.max(1, Math.min(100, Number(req.query.limit || 20)));

  const rows = (await pool.query(
    `SELECT i.owner_id,
            u.email,
            COALESCE(u.full_name, '') AS full_name,
            COUNT(*)::int AS invoices_count,
            COALESCE(SUM(i.total_amount), 0) AS total_spent,
            MAX(i.created_at) AS last_purchase_at,
            COALESCE(SUM(CASE WHEN i.category = 'food' THEN i.total_amount ELSE 0 END), 0) AS food_spent,
            COALESCE(SUM(CASE WHEN i.category = 'grocery' THEN i.total_amount ELSE 0 END), 0) AS grocery_spent,
            COALESCE(SUM(CASE WHEN i.category = 'pharmacy' THEN i.total_amount ELSE 0 END), 0) AS pharmacy_spent,
            COALESCE(SUM(CASE WHEN i.category = 'transport' THEN i.total_amount ELSE 0 END), 0) AS transport_spent
       FROM invoice_scans i
       LEFT JOIN users u ON u.id = i.owner_id
      WHERE i.merchant_key = $1
      GROUP BY i.owner_id, u.email, u.full_name
      ORDER BY COALESCE(SUM(i.total_amount), 0) DESC, COUNT(*) DESC
      LIMIT $2`,
    [merchantKey, limit]
  )).rows;

  res.json(rows.map((row) => ({
    customerId: row.owner_id,
    customerEmail: row.email,
    customerName: row.full_name,
    invoicesCount: Number(row.invoices_count || 0),
    totalSpent: Number(row.total_spent || 0),
    lastPurchaseAt: toIso(row.last_purchase_at),
    consumption: {
      food: Number(row.food_spent || 0),
      grocery: Number(row.grocery_spent || 0),
      pharmacy: Number(row.pharmacy_spent || 0),
      transport: Number(row.transport_spent || 0),
    },
  })));
});

app.post('/api/wallet/ensure', auth, async (req, res) => {
  const userId = req.user.userId;
  await pool.query('INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,\'SAR\',NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  await pool.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  res.json({ ok: true });
});

app.get('/api/wallet', auth, async (req, res) => {
  const userId = req.user.userId;
  await pool.query('INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,\'SAR\',NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  const row = (await pool.query('SELECT * FROM wallet_accounts WHERE owner_id = $1', [userId])).rows[0];
  res.json({ ownerId: row.owner_id, balance: Number(row.balance), currency: row.currency, updatedAt: toIso(row.updated_at) });
});

app.get('/api/wallet/points', auth, async (req, res) => {
  const userId = req.user.userId;
  await pool.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
  const row = (await pool.query('SELECT * FROM point_accounts WHERE owner_id = $1', [userId])).rows[0];
  res.json({ ownerId: row.owner_id, availablePoints: row.available_points, lifetimePoints: row.lifetime_points, updatedAt: toIso(row.updated_at) });
});

app.get('/api/wallet/points-breakdown', auth, async (req, res) => {
  const userId = req.user.userId;
  const [merchantRows, brandRows] = await Promise.all([
    pool.query(
      `SELECT f.merchant_id,
              f.fraction_balance,
              f.updated_at,
              m.business_name
         FROM customer_merchant_fraction_balance f
         LEFT JOIN merchant_profiles m ON m.id = f.merchant_id
        WHERE f.customer_id = $1
        ORDER BY f.updated_at DESC`,
      [userId]
    ),
    pool.query(
      `SELECT f.brand_id,
              f.fraction_balance,
              f.updated_at,
              b.business_name
         FROM customer_brand_fraction_balance f
         LEFT JOIN brand_profiles b ON b.id = f.brand_id
        WHERE f.customer_id = $1
        ORDER BY f.updated_at DESC`,
      [userId]
    ),
  ]);

  return res.json({
    ownerId: userId,
    merchantFractions: merchantRows.rows.map((r) => ({
      merchantId: r.merchant_id,
      merchantName: r.business_name,
      fraction: Number(r.fraction_balance || 0),
      updatedAt: toIso(r.updated_at),
    })),
    brandFractions: brandRows.rows.map((r) => ({
      brandId: r.brand_id,
      brandName: r.business_name,
      fraction: Number(r.fraction_balance || 0),
      updatedAt: toIso(r.updated_at),
    })),
  });
});

app.get('/api/wallet/points/sources', auth, async (req, res) => {
  const userId = req.user.userId;
  const [merchantRows, brandRows] = await Promise.all([
    pool.query(
      `SELECT m.id AS source_id,
              m.business_name AS source_name,
              COALESCE(SUM(CASE WHEN plm.status = 'active' THEN plm.points_delta ELSE 0 END), 0) AS active_points,
              COALESCE(SUM(plm.points_delta), 0) AS lifetime_points
         FROM points_ledger_merchant plm
         JOIN merchant_profiles m ON m.id = plm.merchant_id
        WHERE plm.customer_id = $1
        GROUP BY m.id, m.business_name
        ORDER BY m.business_name ASC`,
      [userId]
    ),
    pool.query(
      `SELECT b.id AS source_id,
              b.business_name AS source_name,
              COALESCE(SUM(CASE WHEN plb.status = 'active' THEN plb.points_delta ELSE 0 END), 0) AS active_points,
              COALESCE(SUM(plb.points_delta), 0) AS lifetime_points
         FROM points_ledger_brand plb
         JOIN brand_profiles b ON b.id = plb.brand_id
        WHERE plb.customer_id = $1
        GROUP BY b.id, b.business_name
        ORDER BY b.business_name ASC`,
      [userId]
    ),
  ]);

  return res.json({
    ownerId: userId,
    merchantSources: merchantRows.rows.map((r) => ({
      sourceId: r.source_id,
      sourceName: r.source_name,
      activePoints: Number(r.active_points || 0),
      lifetimePoints: Number(r.lifetime_points || 0),
    })),
    brandSources: brandRows.rows.map((r) => ({
      sourceId: r.source_id,
      sourceName: r.source_name,
      activePoints: Number(r.active_points || 0),
      lifetimePoints: Number(r.lifetime_points || 0),
    })),
  });
});

app.get('/api/wallet/ledger', auth, async (req, res) => {
  const userId = req.user.userId;
  const limit = Math.max(1, Math.min(200, Number(req.query.limit || 50)));
  const rows = (await pool.query('SELECT * FROM ledger_entries WHERE owner_id = $1 ORDER BY created_at DESC LIMIT $2', [userId, limit])).rows;
  res.json(rows.map((l) => ({
    ownerId: l.owner_id,
    type: l.type,
    amount: Number(l.amount),
    points: l.points,
    reference: l.reference,
    createdAt: toIso(l.created_at),
  })));
});

app.post('/api/wallet/cashback', auth, async (req, res) => {
  const userId = req.user.userId;
  const purchaseAmount = Number((req.body || {}).purchaseAmount || 0);
  const reference = String((req.body || {}).reference || '').trim();
  if (!Number.isFinite(purchaseAmount) || purchaseAmount <= 0 || !reference) {
    return res.status(400).json({ error: 'invalid_payload' });
  }
  const cashback = Number((purchaseAmount * 0.05).toFixed(2));
  const earnedPoints = Math.floor(purchaseAmount);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('INSERT INTO wallet_accounts (owner_id, balance, currency, updated_at) VALUES ($1,0,\'SAR\',NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    await client.query('UPDATE wallet_accounts SET balance = balance + $1, updated_at = NOW() WHERE owner_id = $2', [cashback, userId]);
    await client.query('UPDATE point_accounts SET available_points = available_points + $1, lifetime_points = lifetime_points + $1, updated_at = NOW() WHERE owner_id = $2', [earnedPoints, userId]);
    await client.query('UPDATE users SET points = points + $1, points_history = points_history || to_jsonb($2::int) WHERE id = $3', [earnedPoints, earnedPoints, userId]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'cashbackEarned', cashback, 0, reference]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'pointsEarned', 0, earnedPoints, reference]);
    await client.query('COMMIT');
    res.json({ ok: true, cashback, earnedPoints });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: 'cashback_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.post('/api/wallet/redeem', auth, async (req, res) => {
  const userId = req.user.userId;
  const points = Number((req.body || {}).points || 0);
  const reference = String((req.body || {}).reference || '').trim();
  if (!Number.isInteger(points) || points <= 0 || !reference) {
    return res.status(400).json({ error: 'invalid_payload' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at) VALUES ($1,0,0,NOW()) ON CONFLICT (owner_id) DO NOTHING', [userId]);
    const row = (await client.query('SELECT available_points FROM point_accounts WHERE owner_id = $1 FOR UPDATE', [userId])).rows[0];
    if (!row || Number(row.available_points) < points) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'insufficient_points' });
    }
    await client.query('UPDATE point_accounts SET available_points = available_points - $1, updated_at = NOW() WHERE owner_id = $2', [points, userId]);
    await client.query('UPDATE users SET points = GREATEST(points - $1, 0) WHERE id = $2', [points, userId]);
    await client.query('INSERT INTO ledger_entries (id, owner_id, type, amount, points, reference) VALUES ($1,$2,$3,$4,$5,$6)', [id(), userId, 'pointsRedeemed', 0, points, reference]);
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: 'redeem_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/offers/:id/lifecycle', auth, async (req, res) => {
  const row = (await pool.query('SELECT * FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, row.owner_id)) return res.status(403).json({ error: 'forbidden' });
  res.json({
    lifecycleStatus: row.lifecycle_status,
    createdAt: toIso(row.created_at),
    lifecycleUpdatedAt: toIso(row.lifecycle_updated_at),
    lifecycleReason: row.lifecycle_reason,
    redeemedAt: toIso(row.redeemed_at),
    archivedAt: toIso(row.archived_at),
  });
});

app.post('/api/offers/:id/lifecycle/ensure-defaults', auth, async (req, res) => {
  const owner = (await pool.query('SELECT owner_id FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!owner) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, owner.owner_id)) return res.status(403).json({ error: 'forbidden' });
  await pool.query(
    `UPDATE offers
        SET lifecycle_status = COALESCE(lifecycle_status, 'draft'),
            lifecycle_updated_at = COALESCE(lifecycle_updated_at, NOW())
      WHERE id = $1`,
    [req.params.id]
  );
  res.json({ ok: true });
});

app.post('/api/offers/:id/lifecycle/transition', auth, async (req, res) => {
  const targetStatus = String((req.body || {}).targetStatus || '').trim();
  const reason = (req.body || {}).reason || null;
  if (!targetStatus) return res.status(400).json({ error: 'targetStatus_required' });
  const owner = (await pool.query('SELECT owner_id FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!owner) return res.status(404).json({ error: 'not_found' });
  if (!canAccessUserObject(req.user, owner.owner_id)) return res.status(403).json({ error: 'forbidden' });
  await pool.query(
    `UPDATE offers
        SET lifecycle_status = $1,
            lifecycle_updated_at = NOW(),
            lifecycle_reason = $2,
            published_at = CASE WHEN $1 = 'active' THEN NOW() ELSE published_at END,
            redeemed_at = CASE WHEN $1 = 'redeemed' THEN NOW() ELSE redeemed_at END,
            expired_at = CASE WHEN $1 = 'expired' THEN NOW() ELSE expired_at END,
            archived_at = CASE WHEN $1 = 'archived' THEN NOW() ELSE archived_at END
      WHERE id = $3`,
    [targetStatus, reason, req.params.id]
  );
  res.json({ ok: true });
});

app.post('/api/offers/:id/lifecycle/sync-temporal', auth, async (req, res) => {
  const row = (await pool.query('SELECT id, lifecycle_status, start_date, end_date FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!row) return res.status(404).json({ error: 'not_found' });
  const owner = (await pool.query('SELECT owner_id FROM offers WHERE id = $1', [req.params.id])).rows[0];
  if (!canAccessUserObject(req.user, owner.owner_id)) return res.status(403).json({ error: 'forbidden' });
  const now = new Date();
  let status = row.lifecycle_status;
  if (row.end_date && new Date(row.end_date) < now) status = 'expired';
  else if ((status === 'approved' || status === 'pending_review') && row.start_date && new Date(row.start_date) <= now) status = 'active';
  if (status !== row.lifecycle_status) {
    await pool.query('UPDATE offers SET lifecycle_status = $1, lifecycle_updated_at = NOW(), lifecycle_reason = $2 WHERE id = $3', [status, 'temporal_sync', req.params.id]);
  }
  res.json({ ok: true, lifecycleStatus: status });
});

app.get('/api/stats/counts', auth, async (req, res) => {
  const userId = req.user.userId;
  const offers = (await pool.query('SELECT COUNT(*)::int AS c FROM offers')).rows[0].c;
  const community = (await pool.query('SELECT COUNT(*)::int AS c FROM groups')).rows[0].c;
  const rewards = userId
    ? (await pool.query('SELECT available_points::int AS p FROM point_accounts WHERE owner_id = $1', [userId])).rows[0]?.p || 0
    : 0;
  res.json({ offers, community, rewards });
});

if (AI_ONLY_MODE) {
  app.listen(PORT, DEV_OWNER_BYPASS ? '127.0.0.1' : undefined, () => {
    console.log(`Kupuna AI-only API listening on ${PORT}`);
  });
} else {
  initSchema()
    .then(() => {
      app.listen(PORT, DEV_OWNER_BYPASS ? '127.0.0.1' : undefined, () => {
        console.log(`Kupuna company API listening on ${PORT}`);
      });
      setInterval(() => {
        runSubscriptionTransitions().catch((e) => {
          console.error('Subscription transition runner failed', e);
        });
      }, 60 * 60 * 1000);
    })
    .catch((e) => {
      console.error('Failed to initialize schema', e);
      process.exit(1);
    });
}
