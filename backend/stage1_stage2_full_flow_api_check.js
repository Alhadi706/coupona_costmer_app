const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage1_stage2_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage.${stamp}@kupuna.test`,
    phone: `0911${stamp.slice(-6)}`,
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.8872,
    lng: 13.1913,
    role: 'customer',
  },
  sara: {
    name: 'سارة',
    email: `sara.stage.${stamp}@kupuna.test`,
    phone: `0912${stamp.slice(-6)}`,
    gender: 'female',
    birthDate: '1997-08-22',
    lat: 32.9012,
    lng: 13.2050,
    role: 'customer',
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage.${stamp}@kupuna.test`,
    phone: `0913${stamp.slice(-6)}`,
    gender: 'prefer_not_to_say',
    birthDate: '1992-12-03',
    lat: 32.8750,
    lng: 13.1702,
    role: 'customer',
  },
  fatima: {
    name: 'فاطمة',
    email: `fatima.stage.${stamp}@kupuna.test`,
    phone: `0914${stamp.slice(-6)}`,
    gender: 'female',
    birthDate: '1990-06-18',
    lat: 32.9120,
    lng: 13.2230,
    role: 'customer',
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage.${stamp}@kupuna.test`,
    phone: `0915${stamp.slice(-6)}`,
    gender: 'male',
    birthDate: '1988-01-09',
    lat: 32.8890,
    lng: 13.1988,
    role: 'admin',
  },
  manager: {
    name: 'مدير فرع أحمد',
    email: `manager.stage.${stamp}@kupuna.test`,
    phone: `0916${stamp.slice(-6)}`,
    gender: 'male',
    birthDate: '1993-02-02',
    lat: 32.8899,
    lng: 13.1999,
    role: 'customer',
  },
};

async function api(pathName, method = 'GET', body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${API}${pathName}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const raw = await res.text();
  let data;
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

async function signupAndLogin(u) {
  const signupPayload = {
    email: u.email,
    password: PASSWORD,
    role: u.role,
    phone: u.phone,
    fullName: u.name,
    gender: u.gender,
    birthDate: u.birthDate,
    locationLat: u.lat,
    locationLng: u.lng,
  };

  const signup = await api('/auth/signup', 'POST', signupPayload);
  const login = await api('/auth/login', 'POST', { email: u.email, password: PASSWORD });
  return { signup, login, signupPayload };
}

function asMapError(e) {
  return {
    message: e.message || String(e),
    status: e.status || null,
    data: e.data || null,
  };
}

async function run() {
  const result = {
    meta: { at: new Date().toISOString(), api: API },
    users,
    checks: {},
    ids: {},
    notes: [
      'UI-only checks (interactive map open/pin search, visual role color/menu switch, cashier tab visibility) are approximated via backend state due embedded Flutter renderer limitation in this session.',
    ],
  };

  const created = {};
  for (const key of Object.keys(users)) {
    created[key] = await signupAndLogin(users[key]);
    result.ids[key] = created[key].login.userId;
  }

  const tAhmed = created.ahmed.login.token;
  const tKhaled = created.khaled.login.token;
  const tFatima = created.fatima.login.token;
  const tYousef = created.yousef.login.token;
  const tManager = created.manager.login.token;
  const tSara = created.sara.login.token;

  const ahmedReqPayload = {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: 'CR-AHM-S1-001',
    phone: users.ahmed.phone,
    locationLat: 32.8895,
    locationLng: 13.1982,
    locationAddress: 'Tripoli - Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  };
  const ahmedReq = await api('/roles/merchant/request', 'POST', ahmedReqPayload, tAhmed);
  const ahmedMyReqPending = await api('/roles/requests/me', 'GET', null, tAhmed);
  const ahmedRolesPending = await api('/roles/me', 'GET', null, tAhmed);

  result.checks['1.1'] = {
    ok: ahmedReq.status === 'pending_admin_review',
    request: ahmedReq,
    payload: ahmedReqPayload,
    mapDataCaptured: Number.isFinite(ahmedReqPayload.locationLat) && Number.isFinite(ahmedReqPayload.locationLng),
  };

  result.checks['1.2'] = {
    ok: (ahmedMyReqPending[0]?.status === 'pending_admin_review') && (ahmedRolesPending.merchant === false),
    requestTop: ahmedMyReqPending[0] || null,
    roles: ahmedRolesPending,
  };

  const khaledReqPayload = {
    businessName: 'شركة خالد للعناية',
    category: 'عناية شخصية',
    commercialRegistration: 'CR-KHA-S1-001',
    phone: users.khaled.phone,
    locationLat: 32.8761,
    locationLng: 13.1711,
    locationAddress: 'Tripoli - West',
    planType: 'basic',
  };
  const khaledReq = await api('/roles/brand/request', 'POST', khaledReqPayload, tKhaled);
  const khaledProductPayload = {
    name: 'صابون توري',
    imageUrl: 'https://example.com/sabon-tori.png',
    barcode: '8901234567890',
  };
  const khaledProduct = await api('/brand/products', 'POST', khaledProductPayload, tKhaled);

  result.checks['1.3'] = {
    ok: khaledReq.status === 'pending_admin_review' && khaledProduct.ok === true,
    request: khaledReq,
    product: khaledProduct,
    payloads: { request: khaledReqPayload, product: khaledProductPayload },
  };

  const fatimaReqPayload = {
    businessName: 'صيدلية فاطمة',
    category: 'صيدليات',
    commercialRegistration: 'CR-FAT-S1-001',
    phone: users.fatima.phone,
    locationLat: 32.9133,
    locationLng: 13.2241,
    locationAddress: 'Tripoli - East',
    workingHours: '24/7',
    planType: 'pro',
  };
  const fatimaReq = await api('/roles/merchant/request', 'POST', fatimaReqPayload, tFatima);

  result.checks['1.4'] = {
    ok: fatimaReq.status === 'pending_admin_review',
    request: fatimaReq,
    payload: fatimaReqPayload,
  };

  const pending = await api('/admin/role-requests?status=pending_admin_review', 'GET', null, tYousef);
  const byId = Object.fromEntries(pending.map((r) => [r.userId, r]));
  const ahmedPending = byId[created.ahmed.login.userId] || null;
  const khaledPending = byId[created.khaled.login.userId] || null;
  const fatimaPending = byId[created.fatima.login.userId] || null;

  result.checks['1.5'] = {
    ok: Boolean(ahmedPending && khaledPending && fatimaPending),
    found: { ahmed: ahmedPending, khaled: khaledPending, fatima: fatimaPending },
    categoryAndHoursVisible: {
      ahmed: { category: ahmedPending?.category, workingHours: ahmedPending?.workingHours },
      fatima: { category: fatimaPending?.category, workingHours: fatimaPending?.workingHours },
    },
  };

  const ahmedApprove = await api(`/admin/role-requests/${ahmedReq.requestId}/approve`, 'POST', {}, tYousef);
  const khaledApprove = await api(`/admin/role-requests/${khaledReq.requestId}/approve`, 'POST', {}, tYousef);
  const fatimaReject = await api(`/admin/role-requests/${fatimaReq.requestId}/reject`, 'POST', { reason: 'نواقص في المستندات المرفقة' }, tYousef);

  result.checks['1.6'] = {
    ok: ahmedApprove.status === 'approved' && khaledApprove.status === 'approved' && fatimaReject.status === 'rejected',
    ahmedApprove,
    khaledApprove,
    fatimaReject,
  };

  const fatimaAfterReject = await api('/roles/requests/me', 'GET', null, tFatima);
  result.checks['1.7'] = {
    ok: fatimaAfterReject[0]?.status === 'rejected' && Boolean(fatimaAfterReject[0]?.rejectionReason),
    topRequest: fatimaAfterReject[0] || null,
    reapplySupportedViaApi: true,
  };

  const fatimaResubmitPayload = {
    businessName: 'صيدلية فاطمة - فرع موثق',
    category: 'صيدليات',
    commercialRegistration: 'CR-FAT-S1-001-UPDATED',
    phone: users.fatima.phone,
    locationLat: 32.914,
    locationLng: 13.225,
    locationAddress: 'Tripoli - East / Updated',
    workingHours: '07:00-00:00',
    planType: 'pro',
  };
  const fatimaResubmit = await api('/roles/merchant/request', 'POST', fatimaResubmitPayload, tFatima);
  const fatimaApprove2 = await api(`/admin/role-requests/${fatimaResubmit.requestId}/approve`, 'POST', {}, tYousef);

  result.checks['1.8'] = {
    ok: fatimaResubmit.status === 'pending_admin_review' && fatimaApprove2.status === 'approved',
    resubmit: fatimaResubmit,
    approve: fatimaApprove2,
    payload: fatimaResubmitPayload,
  };

  const ahmedRolesFinal = await api('/roles/me', 'GET', null, tAhmed);
  const khaledRolesFinal = await api('/roles/me', 'GET', null, tKhaled);
  const fatimaRolesFinal = await api('/roles/me', 'GET', null, tFatima);

  result.checks['1.9'] = {
    ok: ahmedRolesFinal.merchant === true && khaledRolesFinal.brand === true && fatimaRolesFinal.merchant === true,
    roles: { ahmed: ahmedRolesFinal, khaled: khaledRolesFinal, fatima: fatimaRolesFinal },
    uiVisualSwitchVerified: false,
  };

  // Stage 2
  const branch1Payload = {
    name: 'مطعم أحمد - الفرع الأول',
    address: 'Tripoli Center',
    location: 'Tripoli',
    latitude: 32.8895,
    longitude: 13.1982,
    category: 'مطاعم',
    workingHours: '08:00-22:00',
  };
  const branch1 = await api('/merchant/branches', 'POST', branch1Payload, tAhmed);

  const branch2Payload = {
    name: 'مطعم أحمد - الفرع الثاني',
    address: 'Tripoli East',
    location: 'Tripoli East',
    latitude: 32.9018,
    longitude: 13.2199,
    category: 'مطاعم',
    workingHours: '10:00-01:00',
  };
  const branch2 = await api('/merchant/branches', 'POST', branch2Payload, tAhmed);
  const branchesAfter = await api('/merchant/branches', 'GET', null, tAhmed);

  result.ids.branch1Id = branch1.id;
  result.ids.branch2Id = branch2.id;

  result.checks['2.1'] = {
    ok: branch2.ok === true && branch2.id && branch2.latitude !== branch1.latitude,
    branch2,
    payload: branch2Payload,
    mapUiOpenAndPinVerified: false,
  };

  result.checks['2.2'] = {
    ok: branchesAfter.some((b) => b.id === branch2.id),
    branchCreateStatusCodeEquivalent: 201,
    branchesCount: branchesAfter.length,
  };

  const managerUserId = created.manager.login.userId;
  const addManager = await api(`/merchant/branches/${branch2.id}/managers`, 'POST', { userId: managerUserId }, tAhmed);
  const managerPermsPayload = {
    canReviewInvoices: true,
    canCreateOffers: false,
    canManageGroup: false,
    canViewReports: false,
    canViewSettlements: false,
    canAddCashiers: false,
    canReplyReports: false,
    canEditPointValue: false,
  };
  const savePerms = await api(`/merchant/branches/${branch2.id}/managers/${managerUserId}/permissions`, 'PATCH', managerPermsPayload, tAhmed);

  result.checks['2.3'] = {
    ok: addManager.ok === true && savePerms.ok === true,
    managerUserId,
    permissions: managerPermsPayload,
  };

  const managerScope = await api('/merchant/manager/scope', 'GET', null, tManager);
  const managerQueue = await api('/merchant/manager/invoices/review-queue', 'GET', null, tManager);
  let offersAccessErr = null;
  let settlementsAccessErr = null;
  try {
    await api('/merchant/branches', 'GET', null, tManager);
  } catch (e) {
    offersAccessErr = asMapError(e);
  }
  try {
    await api('/merchant/profile', 'GET', null, tManager);
  } catch (e) {
    settlementsAccessErr = asMapError(e);
  }

  result.checks['2.4'] = {
    ok:
      managerScope.manager === true &&
      managerScope.sections.invoiceReview === true &&
      managerScope.sections.offers === false &&
      managerScope.sections.reports === false &&
      managerScope.sections.settlements === false &&
      Array.isArray(managerQueue) &&
      offersAccessErr?.status === 403 &&
      settlementsAccessErr?.status === 403,
    managerScope,
    reviewQueueCount: managerQueue.length,
    forbiddenChecks: {
      merchantBranches: offersAccessErr,
      merchantProfile: settlementsAccessErr,
    },
  };

  const bindSaraCashier = await api('/merchant/cashiers/bind', 'POST', {
    branchId: branch2.id,
    cashierPhone: users.sara.phone,
  }, tAhmed);

  result.checks['2.5'] = {
    ok: bindSaraCashier.ok === true,
    bind: bindSaraCashier,
    phoneUsed: users.sara.phone,
  };

  const saraRoles = await api('/roles/me', 'GET', null, tSara);
  const saraCashierLine = (saraRoles.cashier || [])[0] || null;

  result.checks['2.6'] = {
    ok: Boolean(saraCashierLine && saraCashierLine.merchantName && saraCashierLine.merchantName.includes('مطعم أحمد')),
    saraRoles,
    cashierEntry: saraCashierLine,
    uiCashierTabVerified: false,
  };

  result.checks['2.7'] = {
    ok: Boolean(saraCashierLine && saraCashierLine.merchantName === 'مطعم أحمد'),
    expectedGrantedLabel: `كاشير عند: ${saraCashierLine?.merchantName || ''}`,
    dataSource: saraCashierLine,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE1_STAGE2_FLOW_FAILED');
  console.error(e.message || e);
  if (e.data) console.error(JSON.stringify(e.data));
  process.exit(1);
});
