#!/usr/bin/env bash
set -euo pipefail

DBPASS="$(grep '^POSTGRES_PASSWORD=' /opt/projects/kupuna/docker/.env | cut -d= -f2-)"

cd /opt/projects/kupuna/source/backend
cat > .env <<EOF
PORT=3006
JWT_SECRET=kupuna_isolated_3006_$(date +%s)
PGHOST=127.0.0.1
PGPORT=5434
PGUSER=kupuna_user
PGPASSWORD=${DBPASS}
PGDATABASE=kupuna_db
EOF

npm install --omit=dev >/dev/null 2>&1 || true

PIDS=$(ss -ltnp | awk '/:3006/{print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u)
if [ -n "${PIDS}" ]; then
  kill ${PIDS} || true
  sleep 1
fi

nohup node server.js > /opt/projects/kupuna/logs/company_api_3006.log 2>&1 &

for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:3006/api/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

node <<'NODE'
const base = 'http://127.0.0.1:3006/api';
const ts = Date.now();
const rnd = () => Math.floor(Math.random() * 1e6);
const email = (p) => `${p}.${ts}.${rnd()}@kupuna.test`;

async function api(method, path, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : {}; } catch { json = { raw: text }; }
  if (!res.ok) {
    throw new Error(`${method} ${path} failed (${res.status}): ${JSON.stringify(json)}`);
  }
  return json;
}

(async () => {
  const pw = 'Test1234!';
  const merchantEmail = email('merchant');
  const brandEmail = email('brand');
  const customerEmail = email('customer');
  const cashierEmail = email('cashier');
  const adminEmail = email('admin');

  await api('POST', '/auth/signup', { email: merchantEmail, password: pw, role: 'customer' });
  await api('POST', '/auth/signup', { email: brandEmail, password: pw, role: 'customer' });
  await api('POST', '/auth/signup', { email: customerEmail, password: pw, role: 'customer' });
  await api('POST', '/auth/signup', { email: cashierEmail, password: pw, role: 'customer' });
  await api('POST', '/auth/signup', { email: adminEmail, password: pw, role: 'admin' });

  let merchant = await api('POST', '/auth/login', { email: merchantEmail, password: pw });
  let brand = await api('POST', '/auth/login', { email: brandEmail, password: pw });
  const customer = await api('POST', '/auth/login', { email: customerEmail, password: pw });
  const cashier = await api('POST', '/auth/login', { email: cashierEmail, password: pw });
  const admin = await api('POST', '/auth/login', { email: adminEmail, password: pw });

  const merchantReq = await api('POST', '/roles/merchant/request', {
    businessName: 'Ops Merchant',
    commercialRegistration: `CR-M-${ts}`,
    planType: 'standard'
  }, merchant.token);

  const brandReq = await api('POST', '/roles/brand/request', {
    businessName: 'Ops Brand',
    commercialRegistration: `CR-B-${ts}`,
    planType: 'standard'
  }, brand.token);

  await api('POST', `/admin/role-requests/${merchantReq.requestId}/approve`, {}, admin.token);
  await api('POST', `/admin/role-requests/${brandReq.requestId}/approve`, {}, admin.token);

  merchant = await api('POST', '/auth/login', { email: merchantEmail, password: pw });
  brand = await api('POST', '/auth/login', { email: brandEmail, password: pw });

  await api('PATCH', '/merchant/settings/point-value', { pointValue: 10 }, merchant.token);
  await api('PATCH', '/brand/settings/point-value', { pointValue: 5 }, brand.token);

  const branch = await api('POST', '/merchant/branches', {
    name: 'Ops Branch',
    address: 'Tripoli',
    location: 'Tripoli'
  }, merchant.token);

  await api('POST', '/merchant/cashiers/bind', {
    cashierUserId: cashier.userId,
    branchId: branch.id
  }, merchant.token);

  const grant = await api('POST', '/cashier/grant-points', {
    branchId: branch.id,
    customerId: customer.userId,
    purchaseAmount: 30
  }, cashier.token);

  if (grant.points !== 3) {
    throw new Error(`Expected points=3 but got ${JSON.stringify(grant)}`);
  }

  process.stdout.write(JSON.stringify(grant));
})();
NODE
