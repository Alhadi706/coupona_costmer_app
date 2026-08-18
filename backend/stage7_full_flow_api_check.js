const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage7_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage7.${stamp}@kupuna.test`,
    phone: `0961${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  khaledMerchant: {
    name: 'خالد التاجر',
    email: `khaledmerchant.stage7.${stamp}@kupuna.test`,
    phone: `0962${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1990-05-10',
    lat: 32.9090,
    lng: 13.2150,
  },
  sara: {
    name: 'سارة',
    email: `sara.stage7.${stamp}@kupuna.test`,
    phone: `0963${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1997-08-22',
    lat: 32.9000,
    lng: 13.2038,
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage7.${stamp}@kupuna.test`,
    phone: `0964${stamp.slice(-6)}`,
    role: 'admin',
    gender: 'male',
    birthDate: '1988-01-09',
    lat: 32.8890,
    lng: 13.1988,
  },
  toriOwner: {
    name: 'مالك توري',
    email: `tori.stage7.${stamp}@kupuna.test`,
    phone: `0965${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1991-11-11',
    lat: 32.8980,
    lng: 13.2020,
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

  return { ok: response.ok, status: response.status, data };
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

async function createApprovedInvoice({ tokenCustomer, tokenMerchant, merchantId, merchantName, suffix, totalAmount = 40 }) {
  const inv = await api('/invoices/scan-v2', 'POST', {
    merchantName,
    merchantProfileId: merchantId,
    invoiceNumber: `INV-ST7-${suffix}-${Date.now()}`,
    invoiceDate: todayIso(),
    totalAmount,
    imageHash: `img-st7-${suffix}-${Date.now()}`,
    category: 'food',
    rawText: `${merchantName}\n${totalAmount}`,
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/line-items`, 'POST', {
    items: [
      { name: 'وجبة', quantity: 1, unitPrice: totalAmount, lineTotal: totalAmount },
    ],
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/state-transition`, 'POST', {
    to: 'approved',
    note: `stage7 approved ${suffix}`,
  }, tokenMerchant);

  return inv.data.id;
}

async function createApprovedInvoiceWithBrand({ tokenCustomer, tokenMerchant, merchantId, merchantName, tokenBrand, brandId, brandProductId, suffix }) {
  const inv = await api('/invoices/scan-v2', 'POST', {
    merchantName,
    merchantProfileId: merchantId,
    invoiceNumber: `INV-ST7-BRAND-${suffix}-${Date.now()}`,
    invoiceDate: todayIso(),
    totalAmount: 60,
    imageHash: `img-st7-brand-${suffix}-${Date.now()}`,
    category: 'food',
    rawText: `${merchantName}\nمنتج توري\n60`,
  }, tokenCustomer);

  const li = await api(`/invoices/${inv.data.id}/line-items`, 'POST', {
    items: [
      { name: 'منتج توري', quantity: 1, unitPrice: 20, lineTotal: 20 },
      { name: 'وجبة', quantity: 1, unitPrice: 40, lineTotal: 40 },
    ],
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/brand-matches`, 'POST', {
    matches: [
      {
        invoiceLineItemId: li.data.lineItemIds[0],
        brandId,
        productId: brandProductId,
        confidence: 95,
      },
    ],
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/state-transition`, 'POST', {
    to: 'approved',
    note: `stage7 brand approved ${suffix}`,
  }, tokenMerchant);

  return inv.data.id;
}

async function run() {
  const result = {
    meta: { at: new Date().toISOString(), api: API },
    users,
    ids: {},
    checks: {},
    notes: [
      'Stage 7 validated via deterministic API assertions for report flow and rewards.',
    ],
  };

  const logins = {};
  for (const [key, user] of Object.entries(users)) {
    logins[key] = await signupAndLogin(user);
    result.ids[key] = logins[key].userId;
  }

  const tAhmed = logins.ahmed.token;
  const tKhaledMerchant = logins.khaledMerchant.token;
  const tSara = logins.sara.token;
  const tYousef = logins.yousef.token;
  const tToriOwner = logins.toriOwner.token;

  const ahmedReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST7-${stamp.slice(-6)}`,
    phone: users.ahmed.phone,
    locationLat: users.ahmed.lat,
    locationLng: users.ahmed.lng,
    locationAddress: 'Tripoli Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  }, tAhmed);

  const khaledReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم خالد',
    category: 'مطاعم',
    commercialRegistration: `CR-KHA-ST7-${stamp.slice(-6)}`,
    phone: users.khaledMerchant.phone,
    locationLat: users.khaledMerchant.lat,
    locationLng: users.khaledMerchant.lng,
    locationAddress: 'Tripoli North',
    workingHours: '09:00-22:00',
    planType: 'pro',
  }, tKhaledMerchant);

  const toriReq = await api('/roles/brand/request', 'POST', {
    businessName: 'توري',
    category: 'عناية شخصية',
    commercialRegistration: `CR-TORI-ST7-${stamp.slice(-6)}`,
    phone: users.toriOwner.phone,
    locationLat: users.toriOwner.lat,
    locationLng: users.toriOwner.lng,
    locationAddress: 'Tripoli West',
    planType: 'pro',
  }, tToriOwner);

  await api(`/admin/role-requests/${ahmedReq.data.requestId}/approve`, 'POST', {}, tYousef);
  await api(`/admin/role-requests/${khaledReq.data.requestId}/approve`, 'POST', {}, tYousef);
  await api(`/admin/role-requests/${toriReq.data.requestId}/approve`, 'POST', {}, tYousef);

  const ahmedRoles = await api('/roles/me', 'GET', null, tAhmed);
  const khaledRoles = await api('/roles/me', 'GET', null, tKhaledMerchant);
  const toriRoles = await api('/roles/me', 'GET', null, tToriOwner);

  const ahmedMerchantId = ahmedRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  const khaledMerchantId = khaledRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  const toriBrandId = toriRoles.data.subscriptions.find((s) => s.roleType === 'brand')?.roleProfileId;

  result.ids.ahmedMerchantId = ahmedMerchantId;
  result.ids.khaledMerchantId = khaledMerchantId;
  result.ids.toriBrandId = toriBrandId;

  // Ensure Sara has only Ahmed in interactions before first report.
  await createApprovedInvoice({
    tokenCustomer: tSara,
    tokenMerchant: tAhmed,
    merchantId: ahmedMerchantId,
    merchantName: 'مطعم أحمد',
    suffix: 'SARA-AHM-ONLY',
    totalAmount: 30,
  });

  const eligibleStores = await api('/reports/eligible-stores', 'GET', null, tSara);
  const ahmedStore = (eligibleStores.data || []).find((s) => s.storeId === ahmedMerchantId);

  const firstReport = await api('/reports', 'POST', {
    targetStoreId: ahmedMerchantId,
    reportType: 'خدمة سيئة',
    description: 'تأخر شديد في الخدمة وسلوك غير مناسب من الموظف.',
    imageUrl: 'https://example.com/report-stage7-1.jpg',
  }, tSara);

  // 7.1
  result.checks['7.1'] = {
    ok:
      (eligibleStores.data || []).length === 1
      && Boolean(ahmedStore)
      && firstReport.ok
      && firstReport.data.status === 'new',
    eligibleStores,
    firstReport,
  };

  // 7.2
  result.checks['7.2'] = {
    ok: String(firstReport.data.thankYouMessage || '').trim().length > 0,
    thankYouMessage: firstReport.data.thankYouMessage || null,
  };

  // 7.3
  const confirmation = String(firstReport.data.confirmationMessage || '');
  result.checks['7.3'] = {
    ok:
      confirmation.includes('مطعم أحمد')
      && confirmation.includes(String(firstReport.data.id || ''))
      && confirmation.toLowerCase().includes(String(firstReport.data.status || '').toLowerCase()),
    confirmationMessage: confirmation,
    reportId: firstReport.data.id,
    status: firstReport.data.status,
  };

  // 7.4
  const ahmedInboxBeforeAccept = await api('/merchant/reports/inbox', 'GET', null, tAhmed);
  const saraReportInAhmedInbox = (ahmedInboxBeforeAccept.data || []).find((r) => r.id === firstReport.data.id);
  result.checks['7.4'] = {
    ok:
      Boolean(saraReportInAhmedInbox)
      && saraReportInAhmedInbox.reportType === 'خدمة سيئة'
      && String(saraReportInAhmedInbox.description || '').includes('تأخر شديد')
      && String(saraReportInAhmedInbox.imageUrl || '').includes('report-stage7-1.jpg'),
    reportInAhmedInbox: saraReportInAhmedInbox || null,
  };

  // 7.5 + 7.6
  const saraPointsBefore = await api('/wallet/points', 'GET', null, tSara);
  const acceptWithReward = await api(`/merchant/reports/${firstReport.data.id}/accept`, 'POST', {
    grantReward: true,
    rewardPoints: 12,
    resolutionNote: 'تمت المعالجة وسيتم تحسين الخدمة.',
  }, tAhmed);
  const saraPointsAfter = await api('/wallet/points', 'GET', null, tSara);
  const saraNotifications = await api('/notifications/my', 'GET', null, tSara);
  const finalNotif = (saraNotifications.data || []).find((n) =>
    String(n.type || '').includes('report_accepted')
    || String(n.type || '').includes('report_reward')
  );

  result.checks['7.5'] = {
    ok: acceptWithReward.ok && acceptWithReward.data.status === 'reward_granted' && Number(acceptWithReward.data.rewardPoints || 0) === 12,
    acceptWithReward,
  };

  result.checks['7.6'] = {
    ok:
      Boolean(finalNotif)
      && Number(saraPointsAfter.data.availablePoints || 0) === Number(saraPointsBefore.data.availablePoints || 0) + 12,
    saraPointsBefore,
    saraPointsAfter,
    finalNotification: finalNotif || null,
  };

  // 7.7 brand-product report appears in both Ahmed and Khaled inboxes.
  const toriProduct = await api('/brand/products', 'POST', {
    name: 'منتج توري',
    imageUrl: 'https://example.com/tori-product-stage7.png',
    barcode: `TORI-ST7-${stamp.slice(-8)}`,
  }, tToriOwner);

  await createApprovedInvoiceWithBrand({
    tokenCustomer: tSara,
    tokenMerchant: tAhmed,
    merchantId: ahmedMerchantId,
    merchantName: 'مطعم أحمد',
    tokenBrand: tToriOwner,
    brandId: toriBrandId,
    brandProductId: toriProduct.data.id,
    suffix: 'AHMED',
  });

  await createApprovedInvoiceWithBrand({
    tokenCustomer: tSara,
    tokenMerchant: tKhaledMerchant,
    merchantId: khaledMerchantId,
    merchantName: 'مطعم خالد',
    tokenBrand: tToriOwner,
    brandId: toriBrandId,
    brandProductId: toriProduct.data.id,
    suffix: 'KHALED',
  });

  const secondReport = await api('/reports', 'POST', {
    targetBrandId: toriBrandId,
    reportType: 'منتج منتهي الصلاحية',
    description: 'منتج توري منتهي الصلاحية في نقطة البيع.',
    imageUrl: 'https://example.com/report-stage7-2.jpg',
  }, tSara);

  const ahmedInboxAfterBrandReport = await api('/merchant/reports/inbox', 'GET', null, tAhmed);
  const khaledInboxAfterBrandReport = await api('/merchant/reports/inbox', 'GET', null, tKhaledMerchant);

  const inAhmed = (ahmedInboxAfterBrandReport.data || []).find((r) => r.id === secondReport.data.id);
  const inKhaled = (khaledInboxAfterBrandReport.data || []).find((r) => r.id === secondReport.data.id);

  result.checks['7.7'] = {
    ok: Boolean(inAhmed) && Boolean(inKhaled),
    secondReport,
    inAhmed: inAhmed || null,
    inKhaled: inKhaled || null,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE7_FLOW_FAILED');
  console.error(e?.message || e);
  if (e?.data) {
    console.error(JSON.stringify(e.data));
  }
  process.exit(1);
});
