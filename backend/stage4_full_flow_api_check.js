const fs = require('fs');
const path = require('path');

const API = process.env.KUPUNA_API_BASE || 'http://localhost:3006/api';
const PASSWORD = 'Test1234!';
const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 17);
const outPath = path.join(__dirname, 'stage4_full_flow_api_result.json');

const users = {
  ahmed: {
    name: 'أحمد',
    email: `ahmed.stage4.${stamp}@kupuna.test`,
    phone: `0931${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1994-04-12',
    lat: 32.9012,
    lng: 13.2050,
  },
  sara: {
    name: 'سارة',
    email: `sara.stage4.${stamp}@kupuna.test`,
    phone: `0932${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1997-08-22',
    lat: 32.9012,
    lng: 13.2050,
  },
  khaled: {
    name: 'خالد',
    email: `khaled.stage4.${stamp}@kupuna.test`,
    phone: `0933${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'male',
    birthDate: '1992-12-03',
    lat: 32.9020,
    lng: 13.2048,
  },
  nonMatch: {
    name: 'ليلى',
    email: `layla.stage4.${stamp}@kupuna.test`,
    phone: `0934${stamp.slice(-6)}`,
    role: 'customer',
    gender: 'female',
    birthDate: '1968-03-10',
    lat: 32.5000,
    lng: 13.6000,
  },
  admin: {
    name: 'يوسف',
    email: `admin.stage4.${stamp}@kupuna.test`,
    phone: `0935${stamp.slice(-6)}`,
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
    ids: {},
    checks: {},
    notes: [
      'UI-only market and dashboard visual checks are validated by deterministic API state assertions in this run.',
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
  const tNonMatch = logins.nonMatch.token;
  const tAdmin = logins.admin.token;

  // Activate Ahmed as merchant.
  const merchantReq = await api('/roles/merchant/request', 'POST', {
    businessName: 'مطعم أحمد',
    category: 'مطاعم',
    commercialRegistration: `CR-AHM-ST4-${stamp.slice(-6)}`,
    phone: users.ahmed.phone,
    locationLat: users.ahmed.lat,
    locationLng: users.ahmed.lng,
    locationAddress: 'Tripoli Center',
    workingHours: '08:00-23:00',
    planType: 'pro',
  }, tAhmed);
  await api(`/admin/role-requests/${merchantReq.data.requestId}/approve`, 'POST', {}, tAdmin);

  const ahmedRoles = await api('/roles/me', 'GET', null, tAhmed);
  const merchantProfileId = ahmedRoles.data.subscriptions.find((s) => s.roleType === 'merchant')?.roleProfileId;
  result.ids.merchantProfileId = merchantProfileId;

  await api('/merchant/settings/point-value', 'PATCH', { pointValue: 10 }, tAhmed);

  const branch = await api('/merchant/branches', 'POST', {
    name: 'مطعم أحمد - الفرع الرئيسي',
    address: 'Tripoli Center',
    location: 'Tripoli',
    latitude: users.ahmed.lat,
    longitude: users.ahmed.lng,
    category: 'مطاعم',
    workingHours: '08:00-23:00',
  }, tAhmed);
  result.ids.branchId = branch.data.id;

  await api('/merchant/cashiers/bind', 'POST', {
    branchId: branch.data.id,
    cashierPhone: users.sara.phone,
  }, tAhmed);

  // Ensure demographic/profile fields are explicit for targeting checks.
  await api(`/users/${logins.khaled.userId}/profile`, 'POST', {
    fullName: users.khaled.name,
    gender: 'male',
    city: 'Tripoli',
    country: 'Libya',
    profileCompleted: true,
  }, tKhaled);
  await api('/customer/location/me', 'POST', {
    latitude: users.khaled.lat,
    longitude: users.khaled.lng,
  }, tKhaled);

  await api(`/users/${logins.nonMatch.userId}/profile`, 'POST', {
    fullName: users.nonMatch.name,
    gender: 'female',
    city: 'Benghazi',
    country: 'Libya',
    profileCompleted: true,
  }, tNonMatch);
  await api('/customer/location/me', 'POST', {
    latitude: users.nonMatch.lat,
    longitude: users.nonMatch.lng,
  }, tNonMatch);

  // 4.1 Create targeted offer with age+gender+geo criteria.
  const offer = await api('/offers/targeted', 'POST', {
    offerType: 'targeted',
    category: 'مطاعم',
    description: 'عرض مخصص للشباب الذكور في نطاق مطعم أحمد',
    targetType: 'demographic_geo',
    criteria: {
      minAge: 25,
      maxAge: 40,
      gender: 'male',
      city: 'Tripoli',
      country: 'Libya',
      centerLat: users.ahmed.lat,
      centerLng: users.ahmed.lng,
      maxDistanceKm: 5,
    },
  }, tAhmed);
  result.ids.offerId = offer.data.id;

  result.checks['4.1'] = {
    ok: offer.data.ok === true,
    offer: offer.data,
  };

  // 4.2 Offer must be visible only for matching users.
  const offersForKhaled = await api('/offers', 'GET', null, tKhaled);
  const offersForNonMatch = await api('/offers', 'GET', null, tNonMatch);
  const offerVisibleForKhaled = offersForKhaled.data.some((o) => o.id === offer.data.id);
  const offerVisibleForNonMatch = offersForNonMatch.data.some((o) => o.id === offer.data.id);

  result.checks['4.2'] = {
    ok: offerVisibleForKhaled === true && offerVisibleForNonMatch === false,
    visibleForKhaled: offerVisibleForKhaled,
    visibleForNonMatch: offerVisibleForNonMatch,
  };

  // Fund Khaled points through cashier mode at Ahmed branch.
  const grant = await api('/cashier/grant-points', 'POST', {
    branchId: branch.data.id,
    customerId: logins.khaled.userId,
    purchaseAmount: 300,
  }, tSara);

  // Seed escrow balance for later settlement impact validation.
  const escrowAccount = await api('/escrow/accounts', 'POST', {
    sourceType: 'merchant',
    sourceId: merchantProfileId,
    balance: 100,
  }, tAhmed);
  result.ids.escrowAccountId = escrowAccount.data.id;

  const pointsBeforeClaims = await api('/wallet/points', 'GET', null, tKhaled);

  // 4.3 Digital reward: immediate usable code, no cashier required.
  const digitalClaim = await api('/reward-claims/create', 'POST', {
    sourceType: 'merchant',
    sourceId: merchantProfileId,
    pointsCost: 5,
    rewardKind: 'digital',
  }, tKhaled);
  const pointsAfterDigital = await api('/wallet/points', 'GET', null, tKhaled);

  result.checks['4.3'] = {
    ok:
      digitalClaim.data.ok === true &&
      digitalClaim.data.status === 'used' &&
      typeof digitalClaim.data.digitalCode === 'string' &&
      digitalClaim.data.digitalCode.length >= 8,
    claim: digitalClaim.data,
    pointsBefore: pointsBeforeClaims.data,
    pointsAfter: pointsAfterDigital.data,
    pointsDeducted: Number(pointsBeforeClaims.data.availablePoints) - Number(pointsAfterDigital.data.availablePoints),
  };

  // 4.4 Physical reward: points deducted and pickup QR issued.
  const pointsBeforePhysical = await api('/wallet/points', 'GET', null, tKhaled);
  const physicalClaim = await api('/reward-claims/create', 'POST', {
    sourceType: 'merchant',
    sourceId: merchantProfileId,
    pointsCost: 7,
    rewardKind: 'physical',
  }, tKhaled);
  const pointsAfterPhysical = await api('/wallet/points', 'GET', null, tKhaled);

  result.ids.physicalClaimId = physicalClaim.data.id;

  result.checks['4.4'] = {
    ok:
      physicalClaim.data.ok === true &&
      physicalClaim.data.status === 'pending_pickup' &&
      typeof physicalClaim.data.pickupQrCode === 'string' &&
      physicalClaim.data.pickupQrCode.length > 10 &&
      Number(pointsBeforePhysical.data.availablePoints) - Number(pointsAfterPhysical.data.availablePoints) === 7,
    claim: physicalClaim.data,
    pointsBefore: pointsBeforePhysical.data,
    pointsAfter: pointsAfterPhysical.data,
  };

  // 4.5 Cashier scans pickup code and claim becomes redeemed.
  const redeemPhysical = await api('/cashier/redeem-claim', 'POST', {
    pickupQrCode: physicalClaim.data.pickupQrCode,
  }, tSara);
  const khaledClaimsAfterRedeem = await api('/reward-claims/my?limit=20', 'GET', null, tKhaled);
  const redeemedClaim = khaledClaimsAfterRedeem.data.find((c) => c.id === physicalClaim.data.id);

  result.checks['4.5'] = {
    ok: redeemPhysical.data.ok === true && redeemPhysical.data.status === 'redeemed' && redeemedClaim?.status === 'redeemed',
    redeemResponse: redeemPhysical.data,
    claimAfterRedeem: redeemedClaim || null,
  };

  // 4.6 Expiry test: make pending claim expired then refund points.
  const pointsBeforeExpiryClaim = await api('/wallet/points', 'GET', null, tKhaled);
  const pendingClaimForExpiry = await api('/reward-claims/create', 'POST', {
    sourceType: 'merchant',
    sourceId: merchantProfileId,
    pointsCost: 4,
    rewardKind: 'physical',
  }, tKhaled);

  await api(`/admin/reward-claims/${pendingClaimForExpiry.data.id}/expire-now`, 'POST', {}, tAdmin);
  const refundRun = await api('/reward-claims/refund-expired/run', 'POST', {}, tAdmin);
  const pointsAfterRefund = await api('/wallet/points', 'GET', null, tKhaled);
  const claimsAfterRefund = await api('/reward-claims/my?limit=30', 'GET', null, tKhaled);
  const refundedClaim = claimsAfterRefund.data.find((c) => c.id === pendingClaimForExpiry.data.id);

  result.checks['4.6'] = {
    ok:
      refundRun.data.ok === true &&
      Number(pointsAfterRefund.data.availablePoints) === Number(pointsBeforeExpiryClaim.data.availablePoints) &&
      refundedClaim?.status === 'refunded_as_points',
    pendingClaim: pendingClaimForExpiry.data,
    refundRun: refundRun.data,
    pointsBefore: pointsBeforeExpiryClaim.data,
    pointsAfter: pointsAfterRefund.data,
    claimAfterRefund: refundedClaim || null,
  };

  // 4.7 Escrow deduction reflected after physical delivery.
  const escrowSummary = await api('/merchant/escrow/summary', 'GET', null, tAhmed);
  const redeemSettlement = (escrowSummary.data.settlements || []).find((s) => s.id === redeemPhysical.data.settlementId);

  result.checks['4.7'] = {
    ok:
      escrowSummary.data.ok === true &&
      Number(escrowSummary.data.escrowAccount.balance) === 93 &&
      Boolean(redeemSettlement) &&
      Number(redeemSettlement.amount) === 7,
    escrowSummary: escrowSummary.data,
    matchedSettlement: redeemSettlement || null,
    cashierGrantForSeedPoints: grant.data,
  };

  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log(`WROTE=${outPath}`);
}

run().catch((e) => {
  console.error('STAGE4_FLOW_FAILED');
  console.error(e.message || e);
  if (e.data) {
    console.error(JSON.stringify(e.data));
  }
  process.exit(1);
});
