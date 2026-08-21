const crypto = require('crypto');
const { execSync } = require('child_process');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const API = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3017/api';
const JWT_SECRET = process.env.JWT_SECRET;
const PAYMENT_WEBHOOK_SECRET = process.env.PAYMENT_WEBHOOK_SECRET || 'security-regression-webhook-secret';
const PASSWORD = 'SecurityFix123!';
const stamp = Date.now();
const results = [];

function add(name, expected, actual, pass) {
  results.push({ name, expected, actual: String(actual), status: pass ? 'PASS' : 'FAIL' });
}

async function api(path, method = 'GET', body = null, token = null, headers = {}) {
  const requestHeaders = { 'Content-Type': 'application/json', ...headers };
  if (token) requestHeaders.Authorization = token.startsWith('RAW ') ? token.slice(4) : `Bearer ${token}`;
  const response = await fetch(path.startsWith('http') ? path : `${API}${path}`, {
    method,
    headers: requestHeaders,
    body: body ? JSON.stringify(body) : undefined,
  });
  const raw = await response.text();
  let data = {};
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = { raw };
  }
  return { status: response.status, ok: response.ok, data };
}

async function signup(email, role = 'customer') {
  return api('/auth/signup', 'POST', {
    email,
    password: PASSWORD,
    role,
    fullName: `${role} Test`,
    gender: 'male',
    birthDate: '1990-01-01',
  });
}

async function login(email, password = PASSWORD) {
  return api('/auth/login', 'POST', { email, password });
}

async function createAdminFixture() {
  const dbPassword = execSync("grep '^POSTGRES_PASSWORD=' /opt/projects/kupuna/docker/.env | cut -d= -f2-", { encoding: 'utf8' }).trim();
  const pool = new Pool({ host: '127.0.0.1', port: 5434, user: 'kupuna_user', password: dbPassword, database: 'kupuna_db' });
  const email = `security.fixture.admin.${stamp}@kupuna.test`;
  const hash = await bcrypt.hash(PASSWORD, 10);
  await pool.query(
    'INSERT INTO users (id, email, password_hash, role, full_name, profile_completed) VALUES ($1,$2,$3,$4,$5,TRUE)',
    [crypto.randomUUID(), email, hash, 'admin', 'Security Admin Fixture']
  );
  await pool.end();
  return email;
}

async function main() {
  if (!JWT_SECRET) throw new Error('JWT_SECRET is required for JWT regression checks');

  const userAEmail = `security.a.${stamp}@kupuna.test`;
  const userBEmail = `security.b.${stamp}@kupuna.test`;
  await signup(userAEmail);
  await signup(userBEmail);

  for (const role of ['admin', 'merchant', 'brand', 'agent']) {
    const response = await signup(`security.${role}.${stamp}@kupuna.test`, role);
    add(`public signup cannot create ${role}`, '200 role=customer', `${response.status} role=${response.data.role}`, response.status === 200 && response.data.role === 'customer');
  }

  const loginA = await login(userAEmail);
  const loginB = await login(userBEmail);
  const tokenA = loginA.data.token;
  const tokenB = loginB.data.token;
  const userBId = loginB.data.userId;

  const adminEmail = await createAdminFixture();
  const adminLogin = await login(adminEmail);
  const adminToken = adminLogin.data.token;

  add('valid login returns token', '200 token', loginA.status, loginA.status === 200 && Boolean(tokenA));
  add('invalid login rejected', '401', (await login(userAEmail, 'WrongPassword123!')).status, (await login(userAEmail, 'WrongPassword123!')).status === 401);
  add('nonexistent user login rejected', '401', (await login(`missing.${stamp}@kupuna.test`)).status, (await login(`missing.${stamp}@kupuna.test`)).status === 401);
  add('missing JWT rejected', '401', (await api('/roles/me')).status, (await api('/roles/me')).status === 401);
  add('malformed JWT rejected', '401', (await api('/roles/me', 'GET', null, 'RAW Bearer not-a-jwt')).status, (await api('/roles/me', 'GET', null, 'RAW Bearer not-a-jwt')).status === 401);
  const decoded = jwt.decode(tokenA);
  const expiredToken = jwt.sign({ userId: decoded.userId, email: decoded.email, role: 'customer', tokenVersion: decoded.tokenVersion }, JWT_SECRET, { expiresIn: -1 });
  const wrongSignatureToken = jwt.sign({ userId: decoded.userId, email: decoded.email, role: 'customer', tokenVersion: decoded.tokenVersion }, 'wrong-secret', { expiresIn: '1h' });
  add('expired JWT rejected', '401', (await api('/roles/me', 'GET', null, expiredToken)).status, (await api('/roles/me', 'GET', null, expiredToken)).status === 401);
  add('wrong signature JWT rejected', '401', (await api('/roles/me', 'GET', null, wrongSignatureToken)).status, (await api('/roles/me', 'GET', null, wrongSignatureToken)).status === 401);
  add('non-Bearer authorization rejected', '401', (await api('/roles/me', 'GET', null, null, { Authorization: `Token ${tokenA}` })).status, (await api('/roles/me', 'GET', null, null, { Authorization: `Token ${tokenA}` })).status === 401);
  add('customer cannot access admin endpoint', '403', (await api('/admin/dashboard/summary', 'GET', null, tokenA)).status, (await api('/admin/dashboard/summary', 'GET', null, tokenA)).status === 403);
  add('customer cannot access merchant endpoint', '403', (await api('/merchant/profile', 'GET', null, tokenA)).status, (await api('/merchant/profile', 'GET', null, tokenA)).status === 403);
  add('customer cannot access brand endpoint', '403', (await api('/brand/profile', 'GET', null, tokenA)).status, (await api('/brand/profile', 'GET', null, tokenA)).status === 403);
  add('authorized admin fixture can access admin endpoint', '200', (await api('/admin/dashboard/summary', 'GET', null, adminToken)).status, (await api('/admin/dashboard/summary', 'GET', null, adminToken)).status === 200);
  add('payment webhook missing secret denied', '401', (await api('/payments/webhook', 'POST', { subscriptionId: 'test', paid: true })).status, (await api('/payments/webhook', 'POST', { subscriptionId: 'test', paid: true })).status === 401);
  add('payment webhook wrong secret denied', '401', (await api('/payments/webhook', 'POST', { subscriptionId: 'test', paid: true }, null, { 'x-kupuna-webhook-secret': 'wrong' })).status, (await api('/payments/webhook', 'POST', { subscriptionId: 'test', paid: true }, null, { 'x-kupuna-webhook-secret': 'wrong' })).status === 401);
  add('AI invoice analysis requires auth', '401', (await api('/invoices/analyze-ai', 'POST', { rawText: 'receipt total 10' })).status, (await api('/invoices/analyze-ai', 'POST', { rawText: 'receipt total 10' })).status === 401);
  add('customer cannot create escrow account', '403', (await api('/escrow/accounts', 'POST', { sourceType: 'merchant', sourceId: 'test', balance: 100 }, tokenA)).status, (await api('/escrow/accounts', 'POST', { sourceType: 'merchant', sourceId: 'test', balance: 100 }, tokenA)).status === 403);
  add('customer cannot create escrow settlement', '403', (await api('/escrow/settlements', 'POST', { escrowAccountId: 'test', amount: 1, settlementType: 'manual' }, tokenA)).status, (await api('/escrow/settlements', 'POST', { escrowAccountId: 'test', amount: 1, settlementType: 'manual' }, tokenA)).status === 403);
  add('customer cannot transition report', '403', (await api('/reports/test/transition', 'POST', { to: 'under_review' }, tokenA)).status, (await api('/reports/test/transition', 'POST', { to: 'under_review' }, tokenA)).status === 403);
  const massOffer = await api('/offers', 'POST', {
    offerType: 'other',
    category: 'other',
    description: 'mass assignment regression probe',
    lifecycleStatus: 'active',
    lifecycleReason: 'client_probe',
  }, tokenA);
  const offerList = await api('/offers', 'GET', null, tokenA);
  const createdOffer = Array.isArray(offerList.data) ? offerList.data.find((offer) => offer.id === massOffer.data.id) : null;
  add('offer creation ignores lifecycleStatus mass assignment', 'pending_review', createdOffer?.lifecycleStatus, massOffer.status === 200 && createdOffer?.lifecycleStatus === 'pending_review');

  const forgedRole = jwt.sign({ userId: decoded.userId, email: decoded.email, role: 'admin', tokenVersion: decoded.tokenVersion }, JWT_SECRET, { expiresIn: '1h' });
  add('signed customer token with admin role still denied', '403', (await api('/admin/dashboard/summary', 'GET', null, forgedRole)).status, (await api('/admin/dashboard/summary', 'GET', null, forgedRole)).status === 403);

  add('User A cannot read User B', '403', (await api(`/users/${userBId}`, 'GET', null, tokenA)).status, (await api(`/users/${userBId}`, 'GET', null, tokenA)).status === 403);
  add('User A cannot update User B', '403', (await api(`/users/${userBId}/profile`, 'POST', { fullName: 'Nope' }, tokenA)).status, (await api(`/users/${userBId}/profile`, 'POST', { fullName: 'Nope' }, tokenA)).status === 403);
  add('User B can read self', '200', (await api(`/users/${userBId}`, 'GET', null, tokenB)).status, (await api(`/users/${userBId}`, 'GET', null, tokenB)).status === 200);

  const logout = await api('/auth/logout', 'POST', {}, tokenA);
  add('logout succeeds', '200', logout.status, logout.status === 200);
  add('old token denied after logout', '401', (await api('/roles/me', 'GET', null, tokenA)).status, (await api('/roles/me', 'GET', null, tokenA)).status === 401);

  const newLoginA = await login(userAEmail);
  const newTokenA = newLoginA.data.token;
  const png1x1 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';
  const jpegTiny = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAH/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAEFAqf/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/ASP/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/ASP/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAY/Al//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/IV//2gAMAwEAAgADAAAAEP/EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQMBAT8QH//EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQIBAT8QH//EABQQAQAAAAAAAAAAAAAAAAAAABD/2gAIAQEAAT8QH//Z';
  add('unauthenticated upload denied', '401', (await api('/uploads/image', 'POST', { imageBase64: png1x1, mimeType: 'image/png' })).status, (await api('/uploads/image', 'POST', { imageBase64: png1x1, mimeType: 'image/png' })).status === 401);
  const upload = await api('/uploads/image', 'POST', { imageBase64: png1x1, mimeType: 'image/png' }, newTokenA);
  add('valid PNG upload succeeds', '200', upload.status, upload.status === 200 && String(upload.data.url || '').includes('/api/uploads/'));
  add('valid JPEG upload succeeds', '200', (await api('/uploads/image', 'POST', { imageBase64: jpegTiny, mimeType: 'image/jpeg' }, newTokenA)).status, (await api('/uploads/image', 'POST', { imageBase64: jpegTiny, mimeType: 'image/jpeg' }, newTokenA)).status === 200);
  const filePath = String(upload.data.url || '').replace(API, '');
  add('unauthenticated uploaded file denied', '401', (await api(filePath)).status, (await api(filePath)).status === 401);
  add('owner can read uploaded file', '200', (await api(filePath, 'GET', null, newTokenA)).status, (await api(filePath, 'GET', null, newTokenA)).status === 200);
  add('other user cannot read uploaded file', '403', (await api(filePath, 'GET', null, tokenB)).status, (await api(filePath, 'GET', null, tokenB)).status === 403);
  add('legacy public /uploads path denied', '401/404', (await api(filePath.replace('/api/uploads/', '/uploads/'))).status, [401, 404].includes((await api(filePath.replace('/api/uploads/', '/uploads/'))).status));
  add('upload path traversal denied', '403/404', (await api('/uploads/../../backend/server.js', 'GET', null, newTokenA)).status, [403, 404].includes((await api('/uploads/../../backend/server.js', 'GET', null, newTokenA)).status));
  add('invalid image bytes rejected', '400', (await api('/uploads/image', 'POST', { imageBase64: Buffer.from('not png').toString('base64'), mimeType: 'image/png' }, newTokenA)).status, (await api('/uploads/image', 'POST', { imageBase64: Buffer.from('not png').toString('base64'), mimeType: 'image/png' }, newTokenA)).status === 400);
  add('executable bytes pretending image rejected', '400', (await api('/uploads/image', 'POST', { imageBase64: Buffer.from('MZfake').toString('base64'), mimeType: 'image/png' }, newTokenA)).status, (await api('/uploads/image', 'POST', { imageBase64: Buffer.from('MZfake').toString('base64'), mimeType: 'image/png' }, newTokenA)).status === 400);
  add('empty upload rejected', '400', (await api('/uploads/image', 'POST', { imageBase64: '', mimeType: 'image/png' }, newTokenA)).status, (await api('/uploads/image', 'POST', { imageBase64: '', mimeType: 'image/png' }, newTokenA)).status === 400);
  add('oversized upload rejected', '400', (await api('/uploads/image', 'POST', { imageBase64: Buffer.alloc(5 * 1024 * 1024 + 1).toString('base64'), mimeType: 'image/png' }, newTokenA)).status, (await api('/uploads/image', 'POST', { imageBase64: Buffer.alloc(5 * 1024 * 1024 + 1).toString('base64'), mimeType: 'image/png' }, newTokenA)).status === 400);

  for (const result of results) console.log(JSON.stringify(result));
  const failed = results.filter((result) => result.status !== 'PASS');
  console.log(JSON.stringify({ total: results.length, passed: results.length - failed.length, failed: failed.length }));
  if (failed.length) process.exit(1);
}

main().catch((error) => {
  console.error('SECURITY_REGRESSION_CHECK_FAILED', error.message || error);
  process.exit(1);
});