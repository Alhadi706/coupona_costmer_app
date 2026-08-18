const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://127.0.0.1:3007/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage10_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage10.${stamp}@kupuna.test`,
    phone: `0961${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage10.${stamp}@kupuna.test`,
    phone: `0962${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1992-12-03',
    lat: 32.8750,
    lng: 13.1702,
  },
  sara: {
    name: 'سارة',
    email: `sara.stage10.${stamp}@kupuna.test`,
    phone: `0963${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1997-08-22',
    lat: 32.9015,
    lng: 13.2056,
  },
  yousef: {
    name: 'يوسف',
    email: `yousef.stage10.${stamp}@kupuna.test`,
    phone: `0964${stamp.slice(-6)}`,
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

async function signupAndLogin(user) {
  await api('/auth/signup', 'POST', {
    email: user.email,
    password: PASSWORD,
    role: user.role,
    phone: user.phone,
    fullName: user.name,
    gender: user.gender,
    birthDate: user.birthDate,
    locationLat: user.lat,
    locationLng: user.lng,
  });
  const login = await api('/auth/login', 'POST', {
    email: user.email,
    password: PASSWORD,
  });
  await api('/customer/location/me', 'POST', {
    latitude: user.lat,
    longitude: user.lng,
  }, login.data.token);
  return login.data;
}

function findSubscription(data, roleType) {
  return (data.subscriptions || []).find((row) => row.roleType === roleType) || null;
}

function findMerchantSource(data, merchantId) {
  return (data.merchantSources || []).find((row) => row.sourceId === merchantId) || null;
}

async function run() {
  const result = {
    meta: { at: new Date().toISOString(), api: API },
    users,
    ids: {},
    checks: {},
    notes: [
      'Browser-level click proof remains unreliable with Flutter Web semantics here, so stage 10 is validated deterministically via the new admin subscription endpoints, notifications, role payloads, and mutation guards.',
    ],
  };

  const logins = {};
  for (const [key, user] of Object.entries(users)) {
    logins[key] = await signupAndLogin(user);
    result.ids[key] = logins[key].userId;
  }

  const tAhmed = logins.ahmed.token;
  const tKhaled = logins.khaled.token;
  const tSara = logins.sara.token;
  const tYousef = logins.yousef.token;

  const ahmedReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST10-${stamp.slice(-6)}`,
    phone: users.ahmed.phone,
    locationLat: users.ahmed.lat,
    locationLng: users.ahmed.lng,
    locationAddress: 'Tripoli Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  }, tAhmed);
  await api(`/admin/role-requests/${ahmedReq.data.requestId}/approve`, 'POST', {}, tYousef);

  const ahmedRolesInitial = await api('/roles/me', 'GET', null, tAhmed);
  const merchantSubscription = findSubscription(ahmedRolesInitial.data, 'merchant');
  const ahmedMerchantId = merchantSubscription?.roleProfileId;
  const subscriptionId = merchantSubscription?.id;
  result.ids.ahmedMerchantId = ahmedMerchantId;
  result.ids.subscriptionId = subscriptionId;

  await api('/merchant/settings/point-value', 'PATCH', { pointValue: 10 }, tAhmed);
  const branch = await api('/merchant/branches', 'POST', {
    name: 'مطعم أحمد - الفرع الرئيسي',
    address: 'Tripoli Center',
    location: 'Tripoli Center',
    latitude: users.ahmed.lat,
    longitude: users.ahmed.lng,
    category: 'مطاعم',
    workingHours: '08:00-23:00',
  }, tAhmed);
  result.ids.ahmedBranchId = branch.data.id;

  const bindSara = await api('/merchant/cashiers/bind', 'POST', {
    branchId: branch.data.id,
    cashierPhone: users.sara.phone,
  }, tAhmed);
  result.ids.saraCashierId = bindSara.data.id;

  const grantKhaledBefore = await api('/cashier/grant-points', 'POST', {
    branchId: branch.data.id,
    customerId: logins.khaled.userId,
    purchaseAmount: 97,
  }, tSara);
  const grantSaraBefore = await api('/cashier/grant-points', 'POST', {
    branchId: branch.data.id,
    customerId: logins.sara.userId,
    purchaseAmount: 42,
  }, tSara);

  const khaledPointsBefore = await api('/wallet/points/sources', 'GET', null, tKhaled);
  const saraPointsBefore = await api('/wallet/points/sources', 'GET', null, tSara);
  const khaledMerchantSourceBefore = findMerchantSource(khaledPointsBefore.data, ahmedMerchantId);
  const saraMerchantSourceBefore = findMerchantSource(saraPointsBefore.data, ahmedMerchantId);

  const ahmedGroupsBefore = await api('/community/groups/my', 'GET', null, tAhmed);
  const ahmedMerchantGroup = (ahmedGroupsBefore.data || []).find((row) => row.roleType === 'merchant' && row.roleProfileId === ahmedMerchantId) || null;

  const expireTrial = await api(`/admin/subscriptions/${subscriptionId}/expire-trial-now`, 'POST', {}, tYousef);
  const ahmedRolesGrace = await api('/roles/me', 'GET', null, tAhmed);
  const ahmedNotificationsGrace = await api('/notifications/my', 'GET', null, tAhmed);
  const graceSubscription = findSubscription(ahmedRolesGrace.data, 'merchant');
  const graceNotification = (ahmedNotificationsGrace.data || []).find((row) => row.type === 'subscription_grace_period') || null;
  const graceMutation = await api('/merchant/settings/point-value', 'PATCH', { pointValue: 11 }, tAhmed);

  result.checks['10.1_10.2_trial_to_grace_with_access'] = {
    ok:
      expireTrial.data.status === 'grace_period' &&
      graceSubscription?.status === 'grace_period' &&
      Boolean(graceNotification) &&
      graceMutation.data.ok === true,
    expireTrial: expireTrial.data,
    graceSubscription,
    graceNotification,
    graceMutation: graceMutation.data,
  };

  const endGrace = await api(`/admin/subscriptions/${subscriptionId}/end-grace-now`, 'POST', {}, tYousef);
  const ahmedRolesSuspended = await api('/roles/me', 'GET', null, tAhmed);
  const saraRolesSuspended = await api('/roles/me', 'GET', null, tSara);
  const ahmedNotificationsSuspended = await api('/notifications/my', 'GET', null, tAhmed);
  const suspendedNotification = (ahmedNotificationsSuspended.data || []).find((row) => row.type === 'subscription_suspended') || null;
  const suspendedMutation = await api('/merchant/settings/point-value', 'PATCH', { pointValue: 12 }, tAhmed, false);
  const khaledPointsAfterSuspend = await api('/wallet/points/sources', 'GET', null, tKhaled);
  const saraPointsAfterSuspend = await api('/wallet/points/sources', 'GET', null, tSara);
  const khaledMerchantSourceAfterSuspend = findMerchantSource(khaledPointsAfterSuspend.data, ahmedMerchantId);
  const saraMerchantSourceAfterSuspend = findMerchantSource(saraPointsAfterSuspend.data, ahmedMerchantId);
  const ahmedGroupsAfterSuspend = await api('/community/groups/my', 'GET', null, tAhmed);
  const ahmedMerchantGroupAfterSuspend = (ahmedGroupsAfterSuspend.data || []).find((row) => row.roleType === 'merchant' && row.roleProfileId === ahmedMerchantId) || null;

  result.checks['10.3_10.4_suspend_read_only_cashier_off_points_and_group_persist'] = {
    ok:
      endGrace.data.status === 'suspended' &&
      findSubscription(ahmedRolesSuspended.data, 'merchant')?.status === 'suspended' &&
      suspendedMutation.status === 403 &&
      suspendedMutation.data?.error === 'merchant_subscription_read_only' &&
      ((saraRolesSuspended.data.cashier || []).some((row) => row.isActive === true) === false) &&
      Number(khaledMerchantSourceBefore?.activePoints || 0) === Number(khaledMerchantSourceAfterSuspend?.activePoints || 0) &&
      Number(saraMerchantSourceBefore?.activePoints || 0) === Number(saraMerchantSourceAfterSuspend?.activePoints || 0) &&
      Boolean(ahmedMerchantGroupAfterSuspend) &&
      Boolean(suspendedNotification),
    endGrace: endGrace.data,
    suspendedSubscription: findSubscription(ahmedRolesSuspended.data, 'merchant'),
    suspendedNotification,
    suspendedMutation: { status: suspendedMutation.status, data: suspendedMutation.data },
    saraCashierRows: saraRolesSuspended.data.cashier,
    khaledPointsBefore: khaledMerchantSourceBefore,
    khaledPointsAfterSuspend: khaledMerchantSourceAfterSuspend,
    saraPointsBefore: saraMerchantSourceBefore,
    saraPointsAfterSuspend: saraMerchantSourceAfterSuspend,
    groupBefore: ahmedMerchantGroup,
    groupAfterSuspend: ahmedMerchantGroupAfterSuspend,
    grantKhaledBefore: grantKhaledBefore.data,
    grantSaraBefore: grantSaraBefore.data,
  };

  const activateNow = await api(`/admin/subscriptions/${subscriptionId}/activate-now`, 'POST', {}, tYousef);
  const ahmedRolesReactivated = await api('/roles/me', 'GET', null, tAhmed);
  const saraRolesReactivated = await api('/roles/me', 'GET', null, tSara);
  const ahmedNotificationsReactivated = await api('/notifications/my', 'GET', null, tAhmed);
  const reactivatedNotification = (ahmedNotificationsReactivated.data || []).find((row) => row.type === 'subscription_reactivated') || null;
  const activeMutation = await api('/merchant/settings/point-value', 'PATCH', { pointValue: 13 }, tAhmed);
  const grantAfterReactivation = await api('/cashier/grant-points', 'POST', {
    branchId: branch.data.id,
    customerId: logins.khaled.userId,
    purchaseAmount: 26,
  }, tSara);

  result.checks['10.5_reactivate_dashboard_and_cashier'] = {
    ok:
      activateNow.data.status === 'active' &&
      findSubscription(ahmedRolesReactivated.data, 'merchant')?.status === 'active' &&
      ((saraRolesReactivated.data.cashier || []).some((row) => row.isActive === true) === true) &&
      activeMutation.data.ok === true &&
      grantAfterReactivation.data.ok === true &&
      Boolean(reactivatedNotification),
    activateNow: activateNow.data,
    reactivatedSubscription: findSubscription(ahmedRolesReactivated.data, 'merchant'),
    saraCashierRows: saraRolesReactivated.data.cashier,
    reactivatedNotification,
    activeMutation: activeMutation.data,
    grantAfterReactivation: grantAfterReactivation.data,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});