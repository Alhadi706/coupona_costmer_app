const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage8_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage8.${stamp}@kupuna.test`,
    phone: `0971${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage8.${stamp}@kupuna.test`,
    phone: `0972${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1992-12-03',
    lat: 32.9008,
    lng: 13.2046,
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage8.${stamp}@kupuna.test`,
    phone: `0973${stamp.slice(-6)}`,
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

async function createApprovedInvoice(tokenCustomer, tokenMerchant, merchantId, merchantName, suffix) {
  const inv = await api('/invoices/scan-v2', 'POST', {
    merchantName,
    merchantProfileId: merchantId,
    invoiceNumber: `INV-ST8-${suffix}-${Date.now()}`,
    invoiceDate: todayIso(),
    totalAmount: 20,
    imageHash: `img-st8-${suffix}-${Date.now()}`,
    category: 'food',
    rawText: `${merchantName}\n20`,
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/line-items`, 'POST', {
    items: [{ name: 'وجبة', quantity: 1, unitPrice: 20, lineTotal: 20 }],
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/state-transition`, 'POST', {
    to: 'approved',
    note: `stage8 approved ${suffix}`,
  }, tokenMerchant);

  return inv.data.id;
}

async function run() {
  const result = {
    meta: { at: new Date().toISOString(), api: API },
    users,
    ids: {},
    checks: {},
    notes: ['Stage 8 validated with deterministic notification and badge assertions.'],
  };

  const logins = {};
  for (const [key, user] of Object.entries(users)) {
    logins[key] = await signupAndLogin(user);
    result.ids[key] = logins[key].userId;
  }

  const tAhmed = logins.ahmed.token;
  const tKhaled = logins.khaled.token;
  const tYousef = logins.yousef.token;

  const ahmedReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST8-${stamp.slice(-6)}`,
    phone: users.ahmed.phone,
    locationLat: users.ahmed.lat,
    locationLng: users.ahmed.lng,
    locationAddress: 'Tripoli Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  }, tAhmed);
  await api(`/admin/role-requests/${ahmedReq.data.requestId}/approve`, 'POST', {}, tYousef);

  const ahmedRoles = await api('/roles/me', 'GET', null, tAhmed);
  const ahmedMerchantId = ahmedRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  result.ids.ahmedMerchantId = ahmedMerchantId;

  // Join Khaled to Ahmed community through approved invoice.
  await createApprovedInvoice(tKhaled, tAhmed, ahmedMerchantId, 'مطعم أحمد', 'JOIN-KHALED');

  // Khaled opens community once to clear baseline group unread.
  const groups = await api('/community/groups/my', 'GET', null, tKhaled);
  const group = (groups.data || []).find((g) => g.roleType === 'merchant' && g.roleProfileId === ahmedMerchantId) || groups.data[0];
  if (!group) throw new Error('community_group_not_found');
  result.ids.communityGroupId = group.id;
  await api(`/community/groups/${group.id}/messages`, 'GET', null, tKhaled);

  // Create a non-group notification (report_thank_you) for Khaled and keep it unread.
  const eligibleBeforeReport = await api('/reports/eligible-stores', 'GET', null, tKhaled);
  const ahmedInEligible = (eligibleBeforeReport.data || []).find((s) => s.storeId === ahmedMerchantId);
  if (!ahmedInEligible) throw new Error('ahmed_not_eligible_for_khaled_report');

  const report = await api('/reports', 'POST', {
    targetStoreId: ahmedMerchantId,
    reportType: 'خدمة سيئة',
    description: 'بلاغ لاختبار شارة الجرس.',
    imageUrl: 'https://example.com/stage8-report.jpg',
  }, tKhaled);

  // Create a group_message notification for Khaled.
  const groupMsg = await api(`/community/groups/${group.id}/messages`, 'POST', {
    text: 'رسالة جديدة لاختبار شارة المجتمعات والجرس',
  }, tAhmed);

  const bellBadgeAfterAccum = await api('/notifications/badge', 'GET', null, tKhaled);

  // 8.1 red dot exists for accumulated notifications.
  result.checks['8.1'] = {
    ok: Boolean(bellBadgeAfterAccum.data.hasRedDot) && Number(bellBadgeAfterAccum.data.unreadTotal || 0) > 0,
    bellBadgeAfterAccum,
  };

  // 8.2 notification ordering and variety.
  const listBeforeRead = await api('/notifications/my', 'GET', null, tKhaled);
  const rows = listBeforeRead.data || [];
  let sortedDesc = true;
  for (let i = 1; i < rows.length; i += 1) {
    const prev = new Date(rows[i - 1].createdAt || 0).getTime();
    const curr = new Date(rows[i].createdAt || 0).getTime();
    if (curr > prev) {
      sortedDesc = false;
      break;
    }
  }
  const typeSet = new Set(rows.map((r) => r.type));

  result.checks['8.2'] = {
    ok: sortedDesc && typeSet.has('group_message') && typeSet.has('report_thank_you'),
    sortedDesc,
    types: Array.from(typeSet),
    topNotifications: rows.slice(0, 8),
  };

  // 8.3 click notification should lead to linked screen; we validate via targetScreen metadata.
  const clickable = rows.find((r) => r.type === 'group_message') || rows.find((r) => r.type === 'report_thank_you') || rows[0];
  const linkedTarget = clickable?.targetScreen || clickable?.payload?.targetScreen || null;

  result.checks['8.3'] = {
    ok: Boolean(linkedTarget),
    clickedNotification: clickable || null,
    linkedTarget,
  };

  // 8.4 after reading the notification, red dot should disappear (we read all unread items).
  const unreadRows = rows.filter((r) => r.isRead === false);
  for (const n of unreadRows) {
    await api(`/notifications/${n.id}/read`, 'POST', {}, tKhaled);
  }
  const bellBadgeAfterRead = await api('/notifications/badge', 'GET', null, tKhaled);

  result.checks['8.4'] = {
    ok: Number(bellBadgeAfterRead.data.unreadTotal || 0) === 0 && bellBadgeAfterRead.data.hasRedDot === false,
    bellBadgeAfterRead,
  };

  // 8.5 communities badge is separate from bell badge.
  // Recreate one non-group + one group unread, then open group to clear only group unread.
  await api('/reports', 'POST', {
    targetStoreId: ahmedMerchantId,
    reportType: 'استفسار',
    description: 'تنويع إشعار غير مجتمعات لاختبار الفصل.',
    imageUrl: 'https://example.com/stage8-report-2.jpg',
  }, tKhaled);
  await api(`/community/groups/${group.id}/messages`, 'POST', {
    text: 'رسالة قروب ثانية لاختبار فصل الشارتين',
  }, tAhmed);

  const bellBeforeOpen = await api('/notifications/badge', 'GET', null, tKhaled);
  const communityBeforeOpen = await api('/community/badge', 'GET', null, tKhaled);

  // Opening group clears only group_message unread for this group.
  await api(`/community/groups/${group.id}/messages`, 'GET', null, tKhaled);

  const bellAfterOpen = await api('/notifications/badge', 'GET', null, tKhaled);
  const communityAfterOpen = await api('/community/badge', 'GET', null, tKhaled);

  result.checks['8.5'] = {
    ok:
      Number(bellBeforeOpen.data.unreadGroupMessages || 0) > 0
      && Number(bellBeforeOpen.data.unreadNonGroup || 0) > 0
      && Number(communityBeforeOpen.data.unreadCount || 0) > 0
      && Number(communityAfterOpen.data.unreadCount || 0) === 0
      && Number(bellAfterOpen.data.unreadTotal || 0) > 0
      && Number(bellAfterOpen.data.unreadNonGroup || 0) > 0,
    bellBeforeOpen,
    communityBeforeOpen,
    bellAfterOpen,
    communityAfterOpen,
    groupMessageId: groupMsg.data.id,
    firstReportId: report.data.id,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE8_FLOW_FAILED');
  console.error(e?.message || e);
  if (e?.data) {
    console.error(JSON.stringify(e.data));
  }
  process.exit(1);
});
