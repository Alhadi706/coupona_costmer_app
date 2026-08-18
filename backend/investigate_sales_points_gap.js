// Investigation script: proves whether "sales" and "points" in merchant analytics
// come from the same data source, for BOTH the POS/cashier grant-points path and
// the OCR invoice-scan-and-approve path.
//
// Run: node backend/investigate_sales_points_gap.js
const API = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3007/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);

async function api(pathName, method = 'GET', body = null, token = null, expectOk = true) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${API}${pathName}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const raw = await response.text();
  let data;
  try { data = raw ? JSON.parse(raw) : {}; } catch { data = { raw }; }
  if (!response.ok && expectOk) {
    const err = new Error(`HTTP ${response.status} ${response.statusText} :: ${JSON.stringify(data)}`);
    err.status = response.status;
    err.data = data;
    throw err;
  }
  return { ok: response.ok, status: response.status, data };
}

async function signupAndLogin(email, phone, fullName, role) {
  await api('/auth/signup', 'POST', { email, password: PASSWORD, role, phone, fullName });
  const login = await api('/auth/login', 'POST', { email, password: PASSWORD });
  return login.data;
}

async function run() {
  const out = { meta: { at: new Date().toISOString(), api: API }, steps: {} };

  // --- Setup: fresh merchant (Mona) + admin (Omar) + customer (Layla) + cashier (Sami) ---
  const mona = await signupAndLogin(`mona.gap.${stamp}@kupuna.test`, `0971${stamp.slice(-6)}`, 'منى', 'customer');
  const omar = await signupAndLogin(`omar.gap.${stamp}@kupuna.test`, `0972${stamp.slice(-6)}`, 'عمر', 'admin');
  const layla = await signupAndLogin(`layla.gap.${stamp}@kupuna.test`, `0973${stamp.slice(-6)}`, 'ليلى', 'customer');
  const sami = await signupAndLogin(`sami.gap.${stamp}@kupuna.test`, `0974${stamp.slice(-6)}`, 'سامي', 'customer');

  const tMona = mona.token, tOmar = omar.token, tLayla = layla.token, tSami = sami.token;

  const req = await api('/roles/merchant/request', 'POST', {
    businessName: 'متجر منى',
    category: 'بقالة',
    commercialRegistration: `CR-MONA-GAP-${stamp.slice(-6)}`,
    phone: `0971${stamp.slice(-6)}`,
    locationLat: 32.9, locationLng: 13.2,
    locationAddress: 'Tripoli',
    workingHours: '08:00-22:00',
    planType: 'pro',
  }, tMona);
  await api(`/admin/role-requests/${req.data.requestId}/approve`, 'POST', {}, tOmar);

  const rolesMe = await api('/roles/me', 'GET', null, tMona);
  const merchantSub = (rolesMe.data.subscriptions || []).find((r) => r.roleType === 'merchant');
  const merchantId = merchantSub?.roleProfileId;
  out.steps.merchantId = merchantId;

  await api('/merchant/settings/point-value', 'PATCH', { pointValue: 10 }, tMona);
  const branch = await api('/merchant/branches', 'POST', {
    name: 'متجر منى - الفرع الرئيسي', address: 'Tripoli', location: 'Tripoli',
    latitude: 32.9, longitude: 13.2, category: 'بقالة', workingHours: '08:00-22:00',
  }, tMona);
  const branchId = branch.data.id;
  out.steps.branchId = branchId;

  const bind = await api('/merchant/cashiers/bind', 'POST', { branchId, cashierPhone: `0974${stamp.slice(-6)}` }, tMona);
  out.steps.cashierBind = bind.data;

  // --- Baseline analytics (should be all zero) ---
  const baseline = await api(`/merchant/analytics?range=30d`, 'GET', null, tMona);
  out.steps.baselineAnalytics = { sales: baseline.data.sales.total, invoiceCount: baseline.data.sales.invoiceCount, pointsAwarded: baseline.data.sales.pointsAwarded };

  // === PATH A: POS / cashier grant-points (purchaseAmount = 150) ===
  const grant = await api('/cashier/grant-points', 'POST', {
    branchId, customerId: layla.userId, purchaseAmount: 150,
  }, tSami);
  out.steps.pathA_grantPoints = grant.data;

  const analyticsAfterGrant = await api(`/merchant/analytics?range=30d`, 'GET', null, tMona);
  out.steps.pathA_analyticsAfterGrant = {
    sales: analyticsAfterGrant.data.sales.total,
    invoiceCount: analyticsAfterGrant.data.sales.invoiceCount,
    pointsAwarded: analyticsAfterGrant.data.sales.pointsAwarded,
  };
  const laylaPointsAfterGrant = await api('/wallet/points/sources', 'GET', null, tLayla);
  out.steps.pathA_laylaPointSources = laylaPointsAfterGrant.data;

  // === PATH B: OCR invoice scan -> approve (totalAmount = 200) ===
  const scan = await api('/invoices/scan-v2', 'POST', {
    merchantName: 'متجر منى',
    merchantProfileId: merchantId,
    branchId,
    invoiceDate: new Date().toISOString().slice(0, 10),
    totalAmount: 200,
    currency: 'SAR',
    category: 'general',
    invoiceNumber: `INV-GAP-${stamp}`,
    rawText: 'test invoice for sales/points gap investigation',
  }, tLayla);
  out.steps.pathB_scan = scan.data;

  const approve = await api(`/invoices/${scan.data.id}/state-transition`, 'POST', { to: 'approved' }, tMona);
  out.steps.pathB_approve = approve.data;

  const analyticsAfterApprove = await api(`/merchant/analytics?range=30d`, 'GET', null, tMona);
  out.steps.pathB_analyticsAfterApprove = {
    sales: analyticsAfterApprove.data.sales.total,
    invoiceCount: analyticsAfterApprove.data.sales.invoiceCount,
    pointsAwarded: analyticsAfterApprove.data.sales.pointsAwarded,
  };
  const laylaPointsAfterApprove = await api('/wallet/points/sources', 'GET', null, tLayla);
  out.steps.pathB_laylaPointSources = laylaPointsAfterApprove.data;

  // --- Verdict ---
  out.verdict = {
    pathA_pointsGrantedButSalesUnchanged:
      grant.data.points > 0 && analyticsAfterGrant.data.sales.total === baseline.data.sales.total,
    pathA_pointsAwardedFieldIncludedNonInvoicePoints:
      analyticsAfterGrant.data.sales.pointsAwarded === grant.data.points,
    pathB_salesIncreasedByExactInvoiceAmount:
      analyticsAfterApprove.data.sales.total === (analyticsAfterGrant.data.sales.total + 200),
    pathB_pointsAwardedFieldIncludedInvoicePointsToo:
      analyticsAfterApprove.data.sales.pointsAwarded === (analyticsAfterGrant.data.sales.pointsAwarded + approve.data.awards.merchantPoints),
  };

  console.log(JSON.stringify(out, null, 2));
}

run().catch((e) => {
  console.error('INVESTIGATION_FAILED', e.message, e.data || '');
  process.exit(1);
});
