/**
 * Automated verification: customer marketplace offer publishing.
 *
 * Steps:
 *   1. Authenticate a test customer (signup-or-login via the real auth API).
 *   2. GET  /api/customer/community-offers            -> expect 200
 *   3. POST /api/customer/community-offers            -> expect 200 + ok:true
 *      payload: title "عرض تجريبي", category "REAL_ESTATE" (عقارات), price 10
 *   4. GET feed again -> the created offer must be listed.
 *   5. Negative: POST without a token -> expect 401.
 *
 * Usage:  node test_customer_marketplace_offers.js
 * Env:    API_PORT (default 3002)
 */
const API_PORT = process.env.API_PORT || 3002;
const BASE = `http://127.0.0.1:${API_PORT}/api`;

const TEST_EMAIL = 'marketplace_test_customer@kupuna.dev';
const TEST_PASSWORD = 'Test#12345';

const OFFER = {
  title: 'عرض تجريبي',
  description: 'عرض اختباري آلي للتحقق من نشر العروض في سوق الزبائن',
  category: 'REAL_ESTATE', // عقارات
  images: [],
  price_lyd: 10,
  accepts_points_trade: false,
  visibility_scope: 'PUBLIC_COMMUNITY',
};

let failures = 0;

function check(name, condition, details = '') {
  const status = condition ? 'PASS' : 'FAIL';
  if (!condition) failures += 1;
  console.log(`[${status}] ${name}${details ? ` — ${details}` : ''}`);
}

async function api(path, { method = 'GET', token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body == null ? undefined : JSON.stringify(body),
  });
  let data = null;
  try {
    data = await response.json();
  } catch (_) {
    /* empty body */
  }
  return { status: response.status, data };
}

async function ensureTestCustomer() {
  const login = await api('/auth/login', {
    method: 'POST',
    body: { email: TEST_EMAIL, password: TEST_PASSWORD },
  });
  if (login.status === 200 && login.data && login.data.token) {
    return login.data.token;
  }
  const signup = await api('/auth/signup', {
    method: 'POST',
    body: {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      fullName: 'Marketplace Test Customer',
    },
  });
  if (signup.status !== 200) {
    throw new Error(`signup failed: ${signup.status} ${JSON.stringify(signup.data)}`);
  }
  const relogin = await api('/auth/login', {
    method: 'POST',
    body: { email: TEST_EMAIL, password: TEST_PASSWORD },
  });
  if (relogin.status !== 200 || !relogin.data || !relogin.data.token) {
    throw new Error(`login after signup failed: ${relogin.status}`);
  }
  return relogin.data.token;
}

async function main() {
  console.log(`Target API: ${BASE}`);

  // Step 1 — authenticate test customer.
  const token = await ensureTestCustomer();
  check('customer authenticated (login/signup)', typeof token === 'string' && token.length > 20);

  // Step 2 — authenticated feed fetch succeeds.
  const feedBefore = await api('/customer/community-offers', { token });
  check('GET /customer/community-offers with token -> 200', feedBefore.status === 200, `status=${feedBefore.status}`);

  // Step 3 — publish the test offer.
  const created = await api('/customer/community-offers', {
    method: 'POST',
    token,
    body: OFFER,
  });
  const createdOk =
    (created.status === 200 || created.status === 201) &&
    created.data &&
    created.data.ok === true &&
    created.data.offer &&
    created.data.offer.id;
  check('POST /customer/community-offers -> 200/201 + ok:true', createdOk, `status=${created.status}`);
  if (!createdOk) {
    console.log('Response:', JSON.stringify(created.data));
    throw new Error('offer creation failed');
  }
  const offerId = created.data.offer.id;
  check('response contains created offer id', typeof offerId === 'string' && offerId.length > 0, `id=${offerId}`);
  check(
    'server normalized category to REAL_ESTATE (عقارات)',
    created.data.offer.category === 'REAL_ESTATE',
    `category=${created.data.offer.category}`,
  );
  check(
    'server computed points_required (10 LYD x 10 = 100)',
    Number(created.data.offer.points_required) === 100,
    `points_required=${created.data.offer.points_required}`,
  );

  // Step 4 — feed now lists the created offer.
  const feedAfter = await api('/customer/community-offers', { token });
  const offers = (feedAfter.data && (feedAfter.data.offers || feedAfter.data)) || [];
  const found = Array.isArray(offers) && offers.some((o) => String(o.id) === String(offerId));
  check('GET feed lists the newly created offer', found, `offers=${Array.isArray(offers) ? offers.length : 'n/a'}`);

  // Step 5 — no token must be rejected with 401.
  const unauthenticated = await api('/customer/community-offers', {
    method: 'POST',
    body: OFFER,
  });
  check('POST without token -> 401', unauthenticated.status === 401, `status=${unauthenticated.status}`);

  console.log(failures === 0 ? '\nALL CHECKS PASSED' : `\n${failures} CHECK(S) FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error('FATAL:', error.message || error);
  process.exit(1);
});
