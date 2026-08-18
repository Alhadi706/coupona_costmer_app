const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage5_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage5.${stamp}@kupuna.test`,
    phone: `0941${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  fatima: {
    name: 'فاطمة',
    email: `fatima.stage5.${stamp}@kupuna.test`,
    phone: `0942${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1990-06-18',
    lat: 32.9017,
    lng: 13.2060,
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage5.${stamp}@kupuna.test`,
    phone: `0943${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1992-12-03',
    lat: 32.9008,
    lng: 13.2046,
  },
  sara: {
    name: 'سارة',
    email: `sara.stage5.${stamp}@kupuna.test`,
    phone: `0944${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1997-08-22',
    lat: 32.9000,
    lng: 13.2038,
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage5.${stamp}@kupuna.test`,
    phone: `0945${stamp.slice(-6)}`,
    role: 'admin',
    gender: 'male',
    birthDate: '1988-01-09',
    lat: 32.8890,
    lng: 13.1988,
  },
  toriOwner: {
    name: 'مالك توري',
    email: `tori.stage5.${stamp}@kupuna.test`,
    phone: `0946${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1991-11-11',
    lat: 32.8980,
    lng: 13.2020,
  },
  grocer: {
    name: 'تاجر غذائي',
    email: `grocer.stage5.${stamp}@kupuna.test`,
    phone: `0947${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1989-05-09',
    lat: 32.9003,
    lng: 13.2049,
  },
  cashier: {
    name: 'كاشير أحمد',
    email: `cashier.stage5.${stamp}@kupuna.test`,
    phone: `0948${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1996-01-01',
    lat: 32.9012,
    lng: 13.2050,
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

async function run() {
  const result = {
    meta: { at: new Date().toISOString(), api: API },
    users,
    ids: {},
    checks: {},
    notes: [
      'UI actions are validated through deterministic API state and payload assertions in this run.',
    ],
  };

  const logins = {};
  for (const [key, user] of Object.entries(users)) {
    logins[key] = await signupAndLogin(user);
    result.ids[key] = logins[key].userId;
  }

  const tAhmed = logins.ahmed.token;
  const tFatima = logins.fatima.token;
  const tKhaled = logins.khaled.token;
  const tSara = logins.sara.token;
  const tYousef = logins.yousef.token;
  const tToriOwner = logins.toriOwner.token;
  const tGrocer = logins.grocer.token;
  const tCashier = logins.cashier.token;

  // Activate roles
  const ahmedReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST5-${stamp.slice(-6)}`,
    phone: users.ahmed.phone,
    locationLat: users.ahmed.lat,
    locationLng: users.ahmed.lng,
    locationAddress: 'Tripoli Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  }, tAhmed);

  const fatimaReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'صيدلية فاطمة',
    category: 'صيدليات',
    commercialRegistration: `CR-FAT-ST5-${stamp.slice(-6)}`,
    phone: users.fatima.phone,
    locationLat: users.fatima.lat,
    locationLng: users.fatima.lng,
    locationAddress: 'Tripoli East',
    workingHours: '24/7',
    planType: 'pro',
  }, tFatima);

  const grocerReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'متجر غذائي المستهدف',
    category: 'محلات غذائية',
    commercialRegistration: `CR-GRO-ST5-${stamp.slice(-6)}`,
    phone: users.grocer.phone,
    locationLat: users.grocer.lat,
    locationLng: users.grocer.lng,
    locationAddress: 'Tripoli Target Zone',
    workingHours: '09:00-22:00',
    planType: 'pro',
  }, tGrocer);

  const toriReq = await api('/roles/brand/request', 'POST', {
    businessName: 'توري',
    category: 'عناية شخصية',
    commercialRegistration: `CR-TORI-ST5-${stamp.slice(-6)}`,
    phone: users.toriOwner.phone,
    locationLat: users.toriOwner.lat,
    locationLng: users.toriOwner.lng,
    locationAddress: 'Tripoli West',
    planType: 'pro',
  }, tToriOwner);

  await api(`/admin/role-requests/${ahmedReq.data.requestId}/approve`, 'POST', {}, tYousef);
  await api(`/admin/role-requests/${fatimaReq.data.requestId}/approve`, 'POST', {}, tYousef);
  await api(`/admin/role-requests/${grocerReq.data.requestId}/approve`, 'POST', {}, tYousef);
  await api(`/admin/role-requests/${toriReq.data.requestId}/approve`, 'POST', {}, tYousef);

  const ahmedRoles = await api('/roles/me', 'GET', null, tAhmed);
  const fatimaRoles = await api('/roles/me', 'GET', null, tFatima);
  const toriRoles = await api('/roles/me', 'GET', null, tToriOwner);
  const grocerRoles = await api('/roles/me', 'GET', null, tGrocer);

  const ahmedMerchantId = ahmedRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  const fatimaMerchantId = fatimaRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  const toriBrandId = toriRoles.data.subscriptions.find((s) => s.roleType === 'brand')?.roleProfileId;
  const grocerMerchantId = grocerRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;

  result.ids.ahmedMerchantId = ahmedMerchantId;
  result.ids.fatimaMerchantId = fatimaMerchantId;
  result.ids.toriBrandId = toriBrandId;
  result.ids.grocerMerchantId = grocerMerchantId;

  await api('/merchant/settings/point-value', 'PATCH', { pointValue: 10 }, tAhmed);
  await api('/merchant/settings/point-value', 'PATCH', { pointValue: 5 }, tFatima);
  await api('/brand/settings/point-value', 'PATCH', { pointValue: 10 }, tToriOwner);

  // Branch + cashier setup for Ahmed
  const ahmedBranch = await api('/merchant/branches', 'POST', {
    name: 'مطعم أحمد - فرع المرحلة 5',
    address: 'Tripoli Center',
    location: 'Tripoli Center',
    latitude: users.ahmed.lat,
    longitude: users.ahmed.lng,
    category: 'مطاعم',
    workingHours: '08:00-23:00',
  }, tAhmed);
  result.ids.ahmedBranchId = ahmedBranch.data.id;

  await api('/merchant/cashiers/bind', 'POST', {
    branchId: ahmedBranch.data.id,
    cashierPhone: users.cashier.phone,
  }, tAhmed);

  // Seed merchant points for Khaled from Ahmed
  await api('/cashier/grant-points', 'POST', {
    branchId: ahmedBranch.data.id,
    customerId: logins.khaled.userId,
    purchaseAmount: 100,
  }, tCashier);

  // Seed brand points for Khaled from Tori via invoice line match then approval
  const invoice = await api('/invoices/scan-v2', 'POST', {
    merchantName: 'مطعم أحمد',
    merchantProfileId: ahmedMerchantId,
    invoiceNumber: `INV-ST5-${stamp}`,
    invoiceDate: todayIso(),
    totalAmount: 100,
    imageHash: `img-st5-${stamp}`,
    category: 'food',
    rawText: 'مطعم أحمد\nصابون توري\n100',
  }, tKhaled);

  await api(`/invoices/${invoice.data.id}/line-items`, 'POST', {
    items: [
      { name: 'صابون توري', quantity: 1, unitPrice: 30, lineTotal: 30 },
      { name: 'وجبة', quantity: 1, unitPrice: 70, lineTotal: 70 },
    ],
  }, tKhaled);

  const toriProduct = await api('/brand/products', 'POST', {
    name: 'صابون توري',
    imageUrl: 'https://example.com/tori-soap-stage5.png',
    barcode: `TORI-ST5-${stamp.slice(-8)}`,
  }, tToriOwner);

  const li = await api(`/invoices/${invoice.data.id}/line-items`, 'POST', {
    items: [
      { name: 'صابون توري', quantity: 1, unitPrice: 30, lineTotal: 30 },
    ],
  }, tKhaled);

  await api(`/invoices/${invoice.data.id}/brand-matches`, 'POST', {
    matches: [
      {
        invoiceLineItemId: li.data.lineItemIds[0],
        brandId: toriBrandId,
        productId: toriProduct.data.id,
        confidence: 95,
      },
    ],
  }, tKhaled);

  await api(`/invoices/${invoice.data.id}/state-transition`, 'POST', {
    to: 'approved',
    note: 'stage5 approval for source points verification',
  }, tAhmed);

  // 5.1 verify Khaled has points from Ahmed + Tori and admin sets exchange rate Ahmed->Fatima
  const khaledSources = await api('/wallet/points/sources', 'GET', null, tKhaled);
  const ahmedSource = (khaledSources.data.merchantSources || []).find((s) => s.sourceId === ahmedMerchantId);
  const toriSource = (khaledSources.data.brandSources || []).find((s) => s.sourceId === toriBrandId);

  const rateSet = await api('/admin/exchange-rates', 'POST', {
    sourceType: 'merchant',
    sourceId: ahmedMerchantId,
    destinationType: 'merchant',
    destinationId: fatimaMerchantId,
  }, tYousef);

  result.checks['5.1'] = {
    ok:
      Number(ahmedSource?.activePoints || 0) > 0 &&
      Number(toriSource?.activePoints || 0) > 0 &&
      rateSet.data.ok === true,
    khaledSources: khaledSources.data,
    setExchangeRate: rateSet.data,
  };

  // 5.2 Khaled exchanges points Ahmed->Fatima and formula exact match
  const exchange = await api('/points/exchange', 'POST', {
    sourceType: 'merchant',
    sourceId: ahmedMerchantId,
    destinationType: 'merchant',
    destinationId: fatimaMerchantId,
    sourcePoints: 12,
  }, tKhaled);

  const expected = Number((12 * rateSet.data.sourcePointValue / rateSet.data.destinationPointValue).toFixed(6));
  result.checks['5.2'] = {
    ok: Number(exchange.data.destinationPoints) === expected,
    exchange: exchange.data,
    expectedDestinationPoints: expected,
  };

  // 5.3 Sara creates paid peer ad targeting grocery category + geo zone.
  const peerAd = await api('/peer-ads', 'POST', {
    content: 'هريسة منزلية',
    targetType: 'merchant_category_geo',
    targetCategory: 'محلات غذائية',
    targetGeo: {
      centerLat: users.grocer.lat,
      centerLng: users.grocer.lng,
      maxDistanceKm: 3,
    },
    feePaid: 3,
  }, tSara);
  result.ids.peerAdId = peerAd.data.id;

  result.checks['5.3'] = {
    ok: peerAd.data.ok === true && peerAd.data.status === 'pending_admin_review',
    ad: peerAd.data,
  };

  // 5.4 pending admin and hidden from merchants before approval.
  const pendingAds = await api('/admin/peer-ads?status=pending_admin_review', 'GET', null, tYousef);
  const grocerFeedBefore = await api('/peer-ads/feed', 'GET', null, tGrocer);
  const appearsBefore = grocerFeedBefore.data.some((a) => a.id === peerAd.data.id);

  result.checks['5.4'] = {
    ok: pendingAds.data.some((a) => a.id === peerAd.data.id) && appearsBefore === false,
    pendingListContainsAd: pendingAds.data.some((a) => a.id === peerAd.data.id),
    visibleBeforeApproval: appearsBefore,
  };

  // 5.5 Yusuf approves ad
  const approveAd = await api(`/admin/peer-ads/${peerAd.data.id}/approve`, 'POST', {}, tYousef);

  result.checks['5.5'] = {
    ok: approveAd.data.ok === true && approveAd.data.status === 'active',
    approveAd: approveAd.data,
  };

  // 5.6 targeted merchant sees ad in peer ads feed
  const grocerFeedAfter = await api('/peer-ads/feed', 'GET', null, tGrocer);
  const appearsAfter = grocerFeedAfter.data.find((a) => a.id === peerAd.data.id) || null;

  result.checks['5.6'] = {
    ok: Boolean(appearsAfter),
    peerAdVisibleForTargetMerchant: appearsAfter,
  };

  // 5.7 merchant sends sourcing inquiry and Sara receives direct chat message, no auto points/financial effects.
  const saraPointsBefore = await api('/wallet/points', 'GET', null, tSara);
  const grocerPointsBefore = await api('/wallet/points', 'GET', null, tGrocer);

  const inquiry = await api('/sourcing/inquiries', 'POST', {
    peerAdId: peerAd.data.id,
    message: 'أرغب بطلب توريد منتظم لهريسة منزلية. ما السعر والحد الأدنى؟',
  }, tGrocer);

  const saraInquiries = await api('/sourcing/inquiries/my?role=owner', 'GET', null, tSara);
  const ownerHasInquiry = saraInquiries.data.some((r) => r.id === inquiry.data.id);

  const saraChats = await api(`/private-chats?userId=${logins.sara.userId}`, 'GET', null, tSara);
  const inquiryChat = saraChats.data.find((c) => c.id === inquiry.data.chatId) || null;
  let messages = [];
  if (inquiryChat) {
    const m = await api(`/private-chats/${inquiryChat.id}/messages`, 'GET', null, tSara);
    messages = m.data;
  }
  const sourcingMessageFound = messages.some((m) => String(m.text || '').includes(`[SOURCING:${inquiry.data.id}]`));

  const saraNotifications = await api('/notifications/my', 'GET', null, tSara);
  const sourcingNotif = saraNotifications.data.find((n) => n.type === 'sourcing_inquiry' && n.payload?.inquiryId === inquiry.data.id);

  const saraPointsAfter = await api('/wallet/points', 'GET', null, tSara);
  const grocerPointsAfter = await api('/wallet/points', 'GET', null, tGrocer);

  result.checks['5.7'] = {
    ok:
      inquiry.data.ok === true &&
      ownerHasInquiry === true &&
      Boolean(inquiryChat) &&
      sourcingMessageFound === true &&
      Boolean(sourcingNotif) &&
      Number(saraPointsAfter.data.availablePoints) === Number(saraPointsBefore.data.availablePoints) &&
      Number(grocerPointsAfter.data.availablePoints) === Number(grocerPointsBefore.data.availablePoints),
    inquiry: inquiry.data,
    ownerHasInquiry,
    inquiryChat,
    sourcingMessageFound,
    sourcingNotification: sourcingNotif || null,
    saraPointsBefore: saraPointsBefore.data,
    saraPointsAfter: saraPointsAfter.data,
    grocerPointsBefore: grocerPointsBefore.data,
    grocerPointsAfter: grocerPointsAfter.data,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE5_FLOW_FAILED');
  console.error(e.message || e);
  if (e.data) {
    console.error(JSON.stringify(e.data));
  }
  process.exit(1);
});
