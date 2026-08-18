const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage3_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage3.${stamp}@kupuna.test`,
    phone: `0921${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  sara: {
    name: 'سارة',
    email: `sara.stage3.${stamp}@kupuna.test`,
    phone: `0922${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1997-08-22',
    lat: 32.9012,
    lng: 13.2050,
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage3.${stamp}@kupuna.test`,
    phone: `0923${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1992-12-03',
    lat: 32.8750,
    lng: 13.1702,
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage3.${stamp}@kupuna.test`,
    phone: `0924${stamp.slice(-6)}`,
    role: 'admin',
    gender: 'male',
    birthDate: '1988-01-09',
    lat: 32.8890,
    lng: 13.1988,
  },
};

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
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = { raw };
  }

  if (!response.ok && expectOk) {
    const err = new Error(`HTTP ${response.status} ${response.statusText}`);
    err.status = response.status;
    err.data = data;
    throw err;
  }

  return {
    ok: response.ok,
    status: response.status,
    data,
  };
}

async function signupAndLogin(u) {
  await api('/auth/signup', 'POST', {
    email: u.email,
    password: PASSWORD,
    role: u.role,
    phone: u.phone,
    fullName: u.name,
    gender: u.gender,
    birthDate: u.birthDate,
    locationLat: u.lat,
    locationLng: u.lng,
  });

  const login = await api('/auth/login', 'POST', {
    email: u.email,
    password: PASSWORD,
  });

  return login.data;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

async function run() {
  const result = {
    meta: {
      at: new Date().toISOString(),
      api: API,
    },
    users,
    checks: {},
    ids: {},
    notes: [
      'UI-only confirmations (Discover list/map toggle visuals, QR camera scanning, OCR upload animation states) are approximated by deterministic API state because embedded Flutter renderer is unstable in this environment.',
    ],
  };

  const logins = {};
  for (const [key, user] of Object.entries(users)) {
    logins[key] = await signupAndLogin(user);
    result.ids[key] = logins[key].userId;
  }

  const tAhmed = logins.ahmed.token;
  const tSara = logins.sara.token;
  const tKhaled = logins.khaled.token;
  const tYousef = logins.yousef.token;

  // Activate Ahmed merchant and Khaled brand.
  const ahmedReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST3-${stamp.slice(-6)}`,
    phone: users.ahmed.phone,
    locationLat: users.sara.lat,
    locationLng: users.sara.lng,
    locationAddress: 'Tripoli - Near Sara',
    workingHours: '08:00-23:00',
    planType: 'pro',
  }, tAhmed);
  const khaledReq = await api('/roles/brand/request', 'POST', {
    businessName: 'توري',
    category: 'عناية شخصية',
    commercialRegistration: `CR-TORI-ST3-${stamp.slice(-6)}`,
    phone: users.khaled.phone,
    locationLat: users.khaled.lat,
    locationLng: users.khaled.lng,
    locationAddress: 'Tripoli - West',
    planType: 'pro',
  }, tKhaled);

  await api(`/admin/role-requests/${ahmedReq.data.requestId}/approve`, 'POST', {}, tYousef);
  await api(`/admin/role-requests/${khaledReq.data.requestId}/approve`, 'POST', {}, tYousef);

  const ahmedRoles = await api('/roles/me', 'GET', null, tAhmed);
  const khaledRoles = await api('/roles/me', 'GET', null, tKhaled);
  const ahmedMerchantProfileId = ahmedRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  const khaledBrandProfileId = khaledRoles.data.subscriptions.find((s) => s.roleType === 'brand')?.roleProfileId;

  await api('/merchant/settings/point-value', 'PATCH', { pointValue: 10 }, tAhmed);
  await api('/brand/settings/point-value', 'PATCH', { pointValue: 10 }, tKhaled);

  const branch = await api('/merchant/branches', 'POST', {
    name: 'مطعم أحمد - الفرع الرئيسي',
    address: 'Tripoli Center',
    location: 'Tripoli Center',
    latitude: users.sara.lat,
    longitude: users.sara.lng,
    category: 'مطاعم',
    workingHours: '08:00-23:00',
  }, tAhmed);
  result.ids.ahmedBranchId = branch.data.id;

  await api('/merchant/cashiers/bind', 'POST', {
    branchId: branch.data.id,
    cashierPhone: users.sara.phone,
  }, tAhmed);

  // 3.1 Discover list + map pin existence approximation.
  const storesNearSara = await api(`/stores?lat=${users.sara.lat}&lng=${users.sara.lng}`, 'GET', null, tSara);
  const ahmedStore = storesNearSara.data.find((s) => String(s.name || '').includes('مطعم أحمد')) || null;
  const finiteDistanceStores = storesNearSara.data.filter((s) => s.distanceKm != null && Number.isFinite(Number(s.distanceKm)));
  const distanceSorted = finiteDistanceStores.every((s, idx) => idx === 0 || Number(s.distanceKm) >= Number(finiteDistanceStores[idx - 1].distanceKm));
  const minDistance = finiteDistanceStores.length
    ? Math.min(...finiteDistanceStores.map((s) => Number(s.distanceKm)))
    : null;

  result.checks['3.1'] = {
    ok: Boolean(ahmedStore && distanceSorted && ahmedStore.lat != null && ahmedStore.lng != null && Number(ahmedStore.distanceKm) === Number(minDistance)),
    discoverCount: storesNearSara.data.length,
    ahmedStore,
    distanceSorted,
    minDistance,
    mapPinRenderableByCoordinates: Boolean(ahmedStore && ahmedStore.lat != null && ahmedStore.lng != null),
  };

  // 3.2 Category filter.
  const filteredRestaurants = await api(`/stores?category=${encodeURIComponent('مطاعم')}&lat=${users.sara.lat}&lng=${users.sara.lng}`, 'GET', null, tSara);
  const allRestaurantCategory = filteredRestaurants.data.every((s) => String(s.category || '').trim() === 'مطاعم');
  result.checks['3.2'] = {
    ok: filteredRestaurants.data.length > 0 && allRestaurantCategory,
    filteredCount: filteredRestaurants.data.length,
    sample: filteredRestaurants.data.slice(0, 5),
  };

  // 3.3 QR/POS path approximation using customerId as QR payload.
  const grant97 = await api('/cashier/grant-points', 'POST', {
    branchId: branch.data.id,
    customerId: logins.khaled.userId,
    purchaseAmount: 97,
  }, tSara);

  result.checks['3.3'] = {
    ok: grant97.data.ok === true && grant97.data.points === 9,
    grantResponse: grant97.data,
    qrApproximation: 'customerId used as deterministic QR payload',
  };

  // 3.4 Khaled wallet points + fraction 7 for Ahmed merchant.
  const khaledPoints = await api('/wallet/points', 'GET', null, tKhaled);
  const khaledBreakdown = await api('/wallet/points-breakdown', 'GET', null, tKhaled);
  const khaledMerchantFraction = (khaledBreakdown.data.merchantFractions || []).find((f) => f.merchantId === ahmedMerchantProfileId);

  result.checks['3.4'] = {
    ok: Number(khaledPoints.data.availablePoints) === 9 && Number(khaledMerchantFraction?.fraction || 0) === 7,
    points: khaledPoints.data,
    merchantFraction: khaledMerchantFraction || null,
  };

  // Prepare brand product then OCR fallback path for Sara.
  const product = await api('/brand/products', 'POST', {
    name: 'صابون توري',
    imageUrl: 'https://example.com/tori-soap.png',
    barcode: `TORI-${stamp.slice(-8)}`,
  }, tKhaled);

  const invoiceNumber = `INV-ST3-${stamp}`;
  const imageHash = `img-st3-${stamp}`;
  const saraScan = await api('/invoices/scan-v2', 'POST', {
    merchantName: 'مطعم أحمد',
    merchantProfileId: ahmedMerchantProfileId,
    invoiceNumber,
    invoiceDate: todayIso(),
    totalAmount: 97,
    imageHash,
    category: 'food',
    rawText: 'مطعم أحمد\nصابون توري 30\nاجمالي 97',
  }, tSara);

  await api(`/invoices/${saraScan.data.id}/line-items`, 'POST', {
    items: [
      { name: 'صابون توري', quantity: 1, unitPrice: 30, lineTotal: 30 },
      { name: 'وجبة', quantity: 1, unitPrice: 67, lineTotal: 67 },
    ],
  }, tSara);

  const saraInvoicesBeforeApprove = await api('/invoices/my?limit=20', 'GET', null, tSara);
  const saraInvoiceBefore = saraInvoicesBeforeApprove.data.find((i) => i.id === saraScan.data.id) || null;

  // Capture line-item IDs then match first line to Khaled brand.
  const lineItemsCreate = await api(`/invoices/${saraScan.data.id}/line-items`, 'POST', {
    items: [
      { name: 'صابون توري', quantity: 1, unitPrice: 30, lineTotal: 30 },
    ],
  }, tSara);
  const toriLineId = lineItemsCreate.data.lineItemIds[0];

  await api(`/invoices/${saraScan.data.id}/brand-matches`, 'POST', {
    matches: [
      {
        invoiceLineItemId: toriLineId,
        brandId: khaledBrandProfileId,
        productId: product.data.id,
        confidence: 97,
      },
    ],
  }, tSara);

  const approveInvoice = await api(`/invoices/${saraScan.data.id}/state-transition`, 'POST', {
    to: 'approved',
    note: 'approved in stage3 flow',
  }, tAhmed);

  result.checks['3.5'] = {
    ok: saraScan.data.state === 'processing' && approveInvoice.data.to === 'approved',
    processingState: saraScan.data.state,
    approveTransition: approveInvoice.data,
    acceptedOrManualReview: approveInvoice.data.to === 'approved' || approveInvoice.data.to === 'manual_review',
  };

  // 3.6 Separate points for merchant + brand for Sara.
  const saraPoints = await api('/wallet/points', 'GET', null, tSara);
  const saraBreakdown = await api('/wallet/points-breakdown', 'GET', null, tSara);
  const saraMerchantFraction = (saraBreakdown.data.merchantFractions || []).find((f) => f.merchantId === ahmedMerchantProfileId);
  const saraBrandFraction = (saraBreakdown.data.brandFractions || []).find((f) => f.brandId === khaledBrandProfileId);
  const awards = approveInvoice.data.awards || {};

  result.checks['3.6'] = {
    ok:
      Number(awards.merchantPoints || 0) === 9 &&
      Number(awards.brandPoints || 0) === 3 &&
      Number(saraPoints.data.availablePoints || 0) >= 12,
    awards,
    walletPoints: saraPoints.data,
    fractions: {
      merchant: saraMerchantFraction || null,
      brand: saraBrandFraction || null,
    },
  };

  // 3.7 Auto-join groups merchant + brand.
  const saraGroups = await api('/community/groups/my', 'GET', null, tSara);
  const hasMerchantGroup = saraGroups.data.some((g) => g.roleType === 'merchant' && g.roleProfileId === ahmedMerchantProfileId);
  const hasBrandGroup = saraGroups.data.some((g) => g.roleType === 'brand' && g.roleProfileId === khaledBrandProfileId);

  result.checks['3.7'] = {
    ok: hasMerchantGroup && hasBrandGroup,
    groupCount: saraGroups.data.length,
    merchantGroupFound: hasMerchantGroup,
    brandGroupFound: hasBrandGroup,
  };

  // 3.8 Fraud test same invoice same account.
  const dupSameSara = await api('/invoices/scan-v2', 'POST', {
    merchantName: 'مطعم أحمد',
    merchantProfileId: ahmedMerchantProfileId,
    invoiceNumber,
    invoiceDate: todayIso(),
    totalAmount: 97,
    imageHash,
    category: 'food',
    rawText: 'مطعم أحمد\nصابون توري 30\nاجمالي 97',
  }, tSara, false);

  result.checks['3.8'] = {
    ok: dupSameSara.status === 409 && dupSameSara.data.error === 'duplicate_reference',
    response: dupSameSara,
  };

  // 3.9 Same invoice from Khaled should also fail + visible fraud flag.
  const adminSummaryBefore = await api('/admin/dashboard/summary', 'GET', null, tYousef);
  const dupFromKhaled = await api('/invoices/scan-v2', 'POST', {
    merchantName: 'مطعم أحمد',
    merchantProfileId: ahmedMerchantProfileId,
    invoiceNumber,
    invoiceDate: todayIso(),
    totalAmount: 97,
    imageHash: `${imageHash}-other`,
    category: 'food',
    rawText: 'مطعم أحمد\nنسخة مكررة',
  }, tKhaled, false);
  const adminSummaryAfter = await api('/admin/dashboard/summary', 'GET', null, tYousef);
  const fraudFlags = await api('/admin/fraud-flags?limit=20', 'GET', null, tYousef);
  const duplicateFraudRecord = fraudFlags.data.find((f) => f.reason === 'duplicate_reference_any_account' && f.details?.invoiceNumber === invoiceNumber);

  result.checks['3.9'] = {
    ok:
      dupFromKhaled.status === 409 &&
      dupFromKhaled.data.error === 'duplicate_reference' &&
      Number(adminSummaryAfter.data.fraudFlags || 0) >= Number(adminSummaryBefore.data.fraudFlags || 0) &&
      Boolean(duplicateFraudRecord),
    duplicateResponse: dupFromKhaled,
    fraudBefore: adminSummaryBefore.data,
    fraudAfter: adminSummaryAfter.data,
    duplicateFraudRecord: duplicateFraudRecord || null,
  };

  // 3.10 Dispute flow end-to-end.
  const invoice2 = await api('/invoices/scan-v2', 'POST', {
    merchantName: 'مطعم أحمد',
    merchantProfileId: ahmedMerchantProfileId,
    invoiceNumber: `INV-ST3-DISPUTE-${stamp}`,
    invoiceDate: todayIso(),
    totalAmount: 50,
    imageHash: `img-dispute-${stamp}`,
    category: 'food',
    rawText: 'مطعم أحمد\nفاتورة اعتراض\n50',
  }, tSara);

  const rejectWithReason = await api(`/invoices/${invoice2.data.id}/state-transition`, 'POST', {
    to: 'rejected',
    note: 'رفض اختباري متعمد - تحقق الاعتراض',
  }, tAhmed);

  const disputeCreate = await api(`/invoices/${invoice2.data.id}/disputes`, 'POST', {
    reason: 'اعتراض موثق: الفاتورة صحيحة وتم الرفض بالخطأ',
    evidence: 'invoice image + purchase proof',
  }, tSara);

  const merchantDisputes = await api('/merchant/invoices/disputes?status=new', 'GET', null, tAhmed);
  const disputeListed = merchantDisputes.data.find((d) => d.id === disputeCreate.data.id);

  const saraPointsBeforeResolve = await api('/wallet/points', 'GET', null, tSara);
  const resolveUpheld = await api(`/merchant/invoices/disputes/${disputeCreate.data.id}/resolve`, 'POST', {
    decision: 'upheld',
    reason: 'تمت مراجعة المستندات واعتماد الاعتراض',
  }, tAhmed);
  const saraPointsAfterResolve = await api('/wallet/points', 'GET', null, tSara);
  const saraInvoiceListAfter = await api('/invoices/my?limit=20', 'GET', null, tSara);
  const invoice2After = saraInvoiceListAfter.data.find((i) => i.id === invoice2.data.id) || null;

  result.checks['3.10'] = {
    ok:
      rejectWithReason.data.to === 'rejected' &&
      disputeCreate.data.status === 'new' &&
      Boolean(disputeListed) &&
      resolveUpheld.data.decision === 'upheld' &&
      resolveUpheld.data.toState === 'approved' &&
      Number(saraPointsAfterResolve.data.availablePoints || 0) > Number(saraPointsBeforeResolve.data.availablePoints || 0) &&
      invoice2After?.state === 'approved',
    rejectWithReason: rejectWithReason.data,
    disputeCreate: disputeCreate.data,
    disputeListed: disputeListed || null,
    resolveUpheld: resolveUpheld.data,
    saraPointsBeforeResolve: saraPointsBeforeResolve.data,
    saraPointsAfterResolve: saraPointsAfterResolve.data,
    invoiceAfterResolve: invoice2After,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE3_FLOW_FAILED');
  console.error(e.message || e);
  if (e.data) {
    console.error(JSON.stringify(e.data));
  }
  process.exit(1);
});
