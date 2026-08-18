const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const proofPath = path.join(__dirname, 'phase0_five_users_proof_output.txt');
const outPath = path.join(__dirname, 'phase0_stage_role_flow_api_result.json');

function parseEmailsFromProof(text) {
  const users = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^USER=(.+?)\s+EMAIL=(\S+)\s+ROLE=(\S+)/);
    if (m) {
      users[m[1]] = { email: m[2], role: m[3] };
    }
  }
  return users;
}

async function callApi(pathName, method = 'GET', body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${API}${pathName}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const raw = await res.text();
  let data = null;
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = { raw };
  }

  if (!res.ok) {
    const err = new Error(`HTTP ${res.status} ${res.statusText}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }

  return data;
}

async function login(email) {
  return callApi('/auth/login', 'POST', { email, password: PASSWORD });
}

async function run() {
  const proof = fs.readFileSync(proofPath, 'utf8');
  const users = parseEmailsFromProof(proof);

  const ahmed = users['أحمد'];
  const khaled = users['خالد'];
  const fatima = users['فاطمة'];
  const yousef = users['يوسف'];

  if (!ahmed || !khaled || !fatima || !yousef) {
    throw new Error('Missing one or more required users in phase0 proof file.');
  }

  const result = {
    meta: { at: new Date().toISOString(), api: API },
    users: { ahmed, khaled, fatima, yousef },
    checks: {},
    notes: [],
  };

  const ahmedLogin = await login(ahmed.email);
  const khaledLogin = await login(khaled.email);
  const fatimaLogin = await login(fatima.email);
  const adminLogin = await login(yousef.email);

  const ahmedToken = ahmedLogin.token;
  const khaledToken = khaledLogin.token;
  const fatimaToken = fatimaLogin.token;
  const adminToken = adminLogin.token;

  const ahmedReqPayload = {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: 'CR-AHM-2026-001',
    phone: '0911000001',
    locationLat: 32.8895,
    locationLng: 13.1982,
    locationAddress: 'Tripoli - Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  };
  const ahmedReq = await callApi('/roles/merchant/request', 'POST', ahmedReqPayload, ahmedToken);

  const ahmedMyReq = await callApi('/roles/requests/me', 'GET', null, ahmedToken);
  const ahmedRolesPending = await callApi('/roles/me', 'GET', null, ahmedToken);

  result.checks['1.1_ahmed_request_submit'] = {
    ok: ahmedReq.status === 'pending_admin_review',
    request: ahmedReq,
    payload: ahmedReqPayload,
  };

  result.checks['1.2_ahmed_pending_and_no_switch'] = {
    ok: (ahmedMyReq[0] && ahmedMyReq[0].status === 'pending_admin_review' && ahmedRolesPending.merchant === false),
    myRequestTop: ahmedMyReq[0] || null,
    roles: ahmedRolesPending,
    uiEquivalent: 'merchant=false means My Roles switch to merchant should remain unavailable',
  };

  const khaledReqPayload = {
    businessName: 'شركة خالد للعناية',
    category: 'عناية شخصية',
    commercialRegistration: 'CR-KHA-2026-001',
    phone: '0911000003',
    locationLat: 32.8761,
    locationLng: 13.1711,
    locationAddress: 'Tripoli - West',
    planType: 'basic',
  };
  const khaledReq = await callApi('/roles/brand/request', 'POST', khaledReqPayload, khaledToken);

  const khaledProductPayload = {
    name: 'صابون توري',
    imageUrl: 'https://example.com/sabon-tori.png',
    barcode: '8901234567890',
  };
  const khaledProduct = await callApi('/brand/products', 'POST', khaledProductPayload, khaledToken);

  result.checks['1.3_khaled_brand_plus_product'] = {
    ok: khaledReq.status === 'pending_admin_review' && khaledProduct.ok === true,
    request: khaledReq,
    product: khaledProduct,
    payloads: { request: khaledReqPayload, product: khaledProductPayload },
  };

  const fatimaReqPayload = {
    businessName: 'صيدلية فاطمة',
    category: 'صيدليات',
    commercialRegistration: 'CR-FAT-2026-001',
    phone: '0911000004',
    locationLat: 32.9133,
    locationLng: 13.2241,
    locationAddress: 'Tripoli - East',
    workingHours: '24/7',
    planType: 'pro',
  };
  const fatimaReq = await callApi('/roles/merchant/request', 'POST', fatimaReqPayload, fatimaToken);

  result.checks['1.4_fatima_pharmacy_request'] = {
    ok: fatimaReq.status === 'pending_admin_review',
    request: fatimaReq,
    payload: fatimaReqPayload,
  };

  const pendingList = await callApi('/admin/role-requests?status=pending_admin_review', 'GET', null, adminToken);
  const pendingByUser = {};
  for (const item of pendingList) pendingByUser[item.userId] = item;

  result.checks['1.5_admin_sees_three_requests'] = {
    ok: [ahmedLogin.userId, khaledLogin.userId, fatimaLogin.userId].every((id) => Boolean(pendingByUser[id])),
    found: {
      ahmed: pendingByUser[ahmedLogin.userId] || null,
      khaled: pendingByUser[khaledLogin.userId] || null,
      fatima: pendingByUser[fatimaLogin.userId] || null,
    },
    note: 'admin endpoint returns business/registration/phone/location. category & workingHours are stored inside request_data but not exposed by this endpoint.',
  };

  const ahmedApprove = await callApi(`/admin/role-requests/${ahmedReq.requestId}/approve`, 'POST', {}, adminToken);
  const khaledApprove = await callApi(`/admin/role-requests/${khaledReq.requestId}/approve`, 'POST', {}, adminToken);
  const fatimaReject = await callApi(`/admin/role-requests/${fatimaReq.requestId}/reject`, 'POST', { reason: 'نواقص في المستندات المرفقة' }, adminToken);

  result.checks['1.6_admin_approve_approve_reject'] = {
    ok: ahmedApprove.status === 'approved' && khaledApprove.status === 'approved' && fatimaReject.status === 'rejected',
    ahmedApprove,
    khaledApprove,
    fatimaReject,
  };

  const fatimaRequestsAfterReject = await callApi('/roles/requests/me', 'GET', null, fatimaToken);
  result.checks['1.7_fatima_sees_rejection_reason'] = {
    ok: (fatimaRequestsAfterReject[0] && fatimaRequestsAfterReject[0].status === 'rejected' && String(fatimaRequestsAfterReject[0].rejectionReason || '').length > 0),
    topRequest: fatimaRequestsAfterReject[0] || null,
    note: 'API supports re-application by submitting /roles/merchant/request again (UI should map this to re-apply/edit action).',
  };

  const fatimaResubmitPayload = {
    businessName: 'صيدلية فاطمة - فرع موثق',
    category: 'صيدليات',
    commercialRegistration: 'CR-FAT-2026-001-UPDATED',
    phone: '0911000004',
    locationLat: 32.914,
    locationLng: 13.225,
    locationAddress: 'Tripoli - East / Updated',
    workingHours: '07:00-00:00',
    planType: 'pro',
  };
  const fatimaResubmit = await callApi('/roles/merchant/request', 'POST', fatimaResubmitPayload, fatimaToken);
  const fatimaApprove2 = await callApi(`/admin/role-requests/${fatimaResubmit.requestId}/approve`, 'POST', {}, adminToken);

  result.checks['1.8_fatima_resubmit_then_approve'] = {
    ok: fatimaResubmit.status === 'pending_admin_review' && fatimaApprove2.status === 'approved',
    resubmit: fatimaResubmit,
    approve: fatimaApprove2,
    payload: fatimaResubmitPayload,
  };

  const ahmedRolesFinal = await callApi('/roles/me', 'GET', null, ahmedToken);
  const khaledRolesFinal = await callApi('/roles/me', 'GET', null, khaledToken);
  const fatimaRolesFinal = await callApi('/roles/me', 'GET', null, fatimaToken);

  result.checks['1.9_final_roles_switchable'] = {
    ok: ahmedRolesFinal.merchant === true && khaledRolesFinal.brand === true && fatimaRolesFinal.merchant === true,
    finalRoles: {
      ahmed: ahmedRolesFinal,
      khaled: khaledRolesFinal,
      fatima: fatimaRolesFinal,
    },
    note: 'API confirms role activation; full visual color/menu badge transition requires UI runtime verification (blocked in this session due embedded browser render issue).',
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((err) => {
  console.error('STAGE_FLOW_FAILED');
  console.error(err.message || err);
  if (err.data) console.error(JSON.stringify(err.data));
  process.exit(1);
});
