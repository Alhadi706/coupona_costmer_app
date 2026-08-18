const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage6_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage6.${stamp}@kupuna.test`,
    phone: `0951${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage6.${stamp}@kupuna.test`,
    phone: `0952${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1992-12-03',
    lat: 32.9008,
    lng: 13.2046,
  },
  trial: {
    name: 'عضو تجريبي',
    email: `trial.stage6.${stamp}@kupuna.test`,
    phone: `0953${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1998-01-20',
    lat: 32.9004,
    lng: 13.2053,
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage6.${stamp}@kupuna.test`,
    phone: `0954${stamp.slice(-6)}`,
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

async function createApprovedInvoiceForMember(tokenCustomer, tokenMerchant, merchantId, merchantName, suffix) {
  const inv = await api('/invoices/scan-v2', 'POST', {
    merchantName,
    merchantProfileId: merchantId,
    invoiceNumber: `INV-ST6-${suffix}-${Date.now()}`,
    invoiceDate: todayIso(),
    totalAmount: 20,
    imageHash: `img-st6-${suffix}-${Date.now()}`,
    category: 'food',
    rawText: `${merchantName}\n20`,
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/line-items`, 'POST', {
    items: [
      { name: 'وجبة', quantity: 1, unitPrice: 20, lineTotal: 20 },
    ],
  }, tokenCustomer);

  await api(`/invoices/${inv.data.id}/state-transition`, 'POST', {
    to: 'approved',
    note: `stage6 approve ${suffix}`,
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
      'Stage 6 validated through deterministic API assertions.',
    ],
  };

  const logins = {};
  for (const [key, user] of Object.entries(users)) {
    logins[key] = await signupAndLogin(user);
    result.ids[key] = logins[key].userId;
  }

  const tAhmed = logins.ahmed.token;
  const tKhaled = logins.khaled.token;
  const tTrial = logins.trial.token;
  const tYousef = logins.yousef.token;

  const ahmedReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST6-${stamp.slice(-6)}`,
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

  const ahmedBranch = await api('/merchant/branches', 'POST', {
    name: 'مطعم أحمد - فرع المرحلة 6',
    address: 'Tripoli Center',
    location: 'Tripoli Center',
    latitude: users.ahmed.lat,
    longitude: users.ahmed.lng,
    category: 'مطاعم',
    workingHours: '08:00-23:00',
  }, tAhmed);
  result.ids.ahmedBranchId = ahmedBranch.data.id;

  await createApprovedInvoiceForMember(tKhaled, tAhmed, ahmedMerchantId, 'مطعم أحمد', 'KHALED');
  await createApprovedInvoiceForMember(tTrial, tAhmed, ahmedMerchantId, 'مطعم أحمد', 'TRIAL');

  const ahmedGroups = await api('/community/groups/my', 'GET', null, tAhmed);
  const group = (ahmedGroups.data || []).find((g) => g.roleType === 'merchant' && g.roleProfileId === ahmedMerchantId) || ahmedGroups.data[0];
  if (!group) {
    throw new Error('merchant_community_group_not_found');
  }
  result.ids.ahmedCommunityGroupId = group.id;

  const khaledGroups = await api('/community/groups/my', 'GET', null, tKhaled);
  const trialGroups = await api('/community/groups/my', 'GET', null, tTrial);

  const khaledInGroup = (khaledGroups.data || []).some((g) => g.id === group.id);
  const trialInGroup = (trialGroups.data || []).some((g) => g.id === group.id);

  // 6.1 Ahmed posts welcome, pins it, all members see it pinned.
  const welcome = await api(`/community/groups/${group.id}/messages`, 'POST', {
    text: 'مرحبًا بكم في مجتمع مطعم أحمد',
  }, tAhmed);
  await api(`/community/groups/${group.id}/messages/${welcome.data.id}/pin`, 'POST', {}, tAhmed);

  const msgsKhaledAfterPin = await api(`/community/groups/${group.id}/messages`, 'GET', null, tKhaled);
  const msgsTrialAfterPin = await api(`/community/groups/${group.id}/messages`, 'GET', null, tTrial);
  const pinnedForKhaled = (msgsKhaledAfterPin.data || []).find((m) => m.id === welcome.data.id);
  const pinnedForTrial = (msgsTrialAfterPin.data || []).find((m) => m.id === welcome.data.id);

  result.checks['6.1'] = {
    ok: khaledInGroup && trialInGroup && Boolean(pinnedForKhaled?.isPinned) && Boolean(pinnedForTrial?.isPinned),
    groupId: group.id,
    welcomeMessageId: welcome.data.id,
    khaledPinned: pinnedForKhaled || null,
    trialPinned: pinnedForTrial || null,
  };

  // 6.2 Khaled posts, Ahmed deletes, and message disappears content for everyone.
  const khaledMsg = await api(`/community/groups/${group.id}/messages`, 'POST', {
    text: 'هذه رسالة من خالد يجب حذفها',
  }, tKhaled);

  await api(`/community/groups/${group.id}/messages/${khaledMsg.data.id}`, 'DELETE', null, tAhmed);

  const msgsKhaledAfterDelete = await api(`/community/groups/${group.id}/messages`, 'GET', null, tKhaled);
  const msgsTrialAfterDelete = await api(`/community/groups/${group.id}/messages`, 'GET', null, tTrial);
  const deletedForKhaled = (msgsKhaledAfterDelete.data || []).find((m) => m.id === khaledMsg.data.id);
  const deletedForTrial = (msgsTrialAfterDelete.data || []).find((m) => m.id === khaledMsg.data.id);

  result.checks['6.2'] = {
    ok: Boolean(deletedForKhaled?.isDeleted) && deletedForKhaled?.text === '[deleted]'
      && Boolean(deletedForTrial?.isDeleted) && deletedForTrial?.text === '[deleted]',
    khaledMessageId: khaledMsg.data.id,
    khaledView: deletedForKhaled || null,
    trialView: deletedForTrial || null,
  };

  // 6.3 Ahmed bans trial member, trial cannot send messages anymore.
  const ban = await api(`/community/groups/${group.id}/members/${logins.trial.userId}/ban`, 'POST', {
    reason: 'Stage6 moderation test',
  }, tAhmed);

  const trialPostAfterBan = await api(`/community/groups/${group.id}/messages`, 'POST', {
    text: 'محاولة كتابة بعد الحظر',
  }, tTrial, false);

  result.checks['6.3'] = {
    ok: ban.ok && !trialPostAfterBan.ok && trialPostAfterBan.status === 403,
    ban,
    postAfterBan: trialPostAfterBan,
  };

  // 6.4 New message creates community badge for unread members and opening group clears it.
  await api(`/community/groups/${group.id}/messages`, 'GET', null, tAhmed);
  const badgeBefore = await api('/community/badge', 'GET', null, tKhaled);
  await api(`/community/groups/${group.id}/messages`, 'GET', null, tKhaled);
  const badgeAfterOpenBaseline = await api('/community/badge', 'GET', null, tKhaled);
  const ahmedBadgeBaseline = await api('/community/badge', 'GET', null, tAhmed);

  const newMsg = await api(`/community/groups/${group.id}/messages`, 'POST', {
    text: 'إعلان جديد داخل القروب لاختبار الشارة',
  }, tAhmed);

  const khaledBadgeAfterNew = await api('/community/badge', 'GET', null, tKhaled);
  const ahmedBadgeAfterNew = await api('/community/badge', 'GET', null, tAhmed);

  const groupsWithUnread = await api('/community/groups/my', 'GET', null, tKhaled);
  const khaledGroupUnread = (groupsWithUnread.data || []).find((g) => g.id === group.id);

  await api(`/community/groups/${group.id}/messages`, 'GET', null, tKhaled);
  const khaledBadgeAfterOpen = await api('/community/badge', 'GET', null, tKhaled);
  const groupsAfterRead = await api('/community/groups/my', 'GET', null, tKhaled);
  const khaledGroupUnreadAfterRead = (groupsAfterRead.data || []).find((g) => g.id === group.id);

  result.checks['6.4'] = {
    ok:
      Number(badgeAfterOpenBaseline.data.unreadCount || 0) === 0
      && Number(khaledBadgeAfterNew.data.unreadCount || 0) > 0
      && Number(ahmedBadgeAfterNew.data.unreadCount || 0) === Number(ahmedBadgeBaseline.data.unreadCount || 0)
      && Number(khaledGroupUnread?.unreadCount || 0) > 0
      && Number(khaledBadgeAfterOpen.data.unreadCount || 0) === 0
      && Number(khaledGroupUnreadAfterRead?.unreadCount || 0) === 0,
    newMessageId: newMsg.data.id,
    badgeBefore,
    badgeAfterOpenBaseline,
    ahmedBadgeBaseline,
    khaledBadgeAfterNew,
    ahmedBadgeAfterNew,
    khaledGroupUnreadBeforeRead: khaledGroupUnread || null,
    khaledBadgeAfterOpen,
    khaledGroupUnreadAfterRead: khaledGroupUnreadAfterRead || null,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE6_FLOW_FAILED');
  console.error(e?.message || e);
  if (e?.data) {
    console.error(JSON.stringify(e.data));
  }
  process.exit(1);
});
