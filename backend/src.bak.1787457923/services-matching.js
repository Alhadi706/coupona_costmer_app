const { pool } = require('./db');
const { id, toIso } = require('./helpers');
const { ensureCommunityGroupForRole, ensureCommunityMembership, joinCustomerToMerchantCommunity,
  joinCustomerToBrandCommunities, insertNotification } = require('./services-social');

async function applyInvoiceApprovalRewards(client, invoiceId, ownerId, merchantProfileId) {
  const summary = {
    merchantPoints: 0,
    merchantFraction: 0,
    brandPoints: 0,
    brandBreakdown: [],
  };

  const invoice = (await client.query(
    'SELECT total_amount FROM invoice_scans WHERE id = $1 LIMIT 1',
    [invoiceId]
  )).rows[0];
  const invoiceTotalAmount = Number(invoice?.total_amount || 0);

  if (merchantProfileId && Number.isFinite(invoiceTotalAmount) && invoiceTotalAmount > 0) {
    const alreadyMerchantAwarded = (await client.query(
      'SELECT 1 FROM points_ledger_merchant WHERE invoice_scan_id = $1 LIMIT 1',
      [invoiceId]
    )).rows[0];

    if (!alreadyMerchantAwarded) {
      const merchant = (await client.query(
        'SELECT point_value FROM merchant_profiles WHERE id = $1 LIMIT 1',
        [merchantProfileId]
      )).rows[0];
      const pointValue = Number(merchant?.point_value || 0);
      if (Number.isFinite(pointValue) && pointValue > 0) {
        await client.query(
          `INSERT INTO customer_merchant_fraction_balance (customer_id, merchant_id, fraction_balance)
           VALUES ($1,$2,0)
           ON CONFLICT (customer_id, merchant_id) DO NOTHING`,
          [ownerId, merchantProfileId]
        );
        const bal = (await client.query(
          `SELECT fraction_balance
             FROM customer_merchant_fraction_balance
            WHERE customer_id = $1 AND merchant_id = $2
            FOR UPDATE`,
          [ownerId, merchantProfileId]
        )).rows[0];
        const before = Number(bal?.fraction_balance || 0);
        const calc = calculatePointsWithFraction(invoiceTotalAmount, pointValue, before);
        await client.query(
          `UPDATE customer_merchant_fraction_balance
              SET fraction_balance = $3,
                  updated_at = NOW()
            WHERE customer_id = $1 AND merchant_id = $2`,
          [ownerId, merchantProfileId, calc.newFraction]
        );
        await client.query(
          `INSERT INTO points_ledger_merchant (
            id, customer_id, merchant_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at
          ) VALUES (
            $1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months'
          )`,
          [id(), ownerId, merchantProfileId, invoiceId, calc.points, before, calc.newFraction]
        );
        summary.merchantPoints = calc.points;
        summary.merchantFraction = calc.newFraction;
      }
    }
  }

  const brandRows = (await client.query(
    `SELECT bm.brand_id,
            COALESCE(SUM(COALESCE(li.line_total, 0)), 0) AS amount
       FROM brand_matches bm
       JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
      WHERE li.invoice_scan_id = $1
      GROUP BY bm.brand_id`,
    [invoiceId]
  )).rows;

  for (const row of brandRows) {
    const brandId = String(row.brand_id || '').trim();
    const lineAmount = Number(row.amount || 0);
    if (!brandId || !Number.isFinite(lineAmount) || lineAmount <= 0) continue;

    const alreadyBrandAwarded = (await client.query(
      'SELECT 1 FROM points_ledger_brand WHERE invoice_scan_id = $1 AND brand_id = $2 LIMIT 1',
      [invoiceId, brandId]
    )).rows[0];
    if (alreadyBrandAwarded) continue;

    const brand = (await client.query(
      'SELECT point_value FROM brand_profiles WHERE id = $1 LIMIT 1',
      [brandId]
    )).rows[0];
    const pointValue = Number(brand?.point_value || 0);
    if (!Number.isFinite(pointValue) || pointValue <= 0) continue;

    await client.query(
      `INSERT INTO customer_brand_fraction_balance (customer_id, brand_id, fraction_balance)
       VALUES ($1,$2,0)
       ON CONFLICT (customer_id, brand_id) DO NOTHING`,
      [ownerId, brandId]
    );

    const bal = (await client.query(
      `SELECT fraction_balance
         FROM customer_brand_fraction_balance
        WHERE customer_id = $1 AND brand_id = $2
        FOR UPDATE`,
      [ownerId, brandId]
    )).rows[0];

    const before = Number(bal?.fraction_balance || 0);
    const calc = calculatePointsWithFraction(lineAmount, pointValue, before);
    await client.query(
      `UPDATE customer_brand_fraction_balance
          SET fraction_balance = $3,
              updated_at = NOW()
        WHERE customer_id = $1 AND brand_id = $2`,
      [ownerId, brandId, calc.newFraction]
    );
    await client.query(
      `INSERT INTO points_ledger_brand (
        id, customer_id, brand_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months'
      )`,
      [id(), ownerId, brandId, invoiceId, calc.points, before, calc.newFraction]
    );

    summary.brandPoints += calc.points;
    summary.brandBreakdown.push({
      brandId,
      lineAmount,
      points: calc.points,
      fraction: calc.newFraction,
    });
  }

  const totalAwardedPoints = summary.merchantPoints + summary.brandPoints;
  if (totalAwardedPoints > 0) {
    await client.query(
      `INSERT INTO point_accounts (owner_id, available_points, lifetime_points, updated_at)
       VALUES ($1,0,0,NOW())
       ON CONFLICT (owner_id) DO NOTHING`,
      [ownerId]
    );
    await client.query(
      `UPDATE point_accounts
          SET available_points = available_points + $2,
              lifetime_points = lifetime_points + $2,
              updated_at = NOW()
        WHERE owner_id = $1`,
      [ownerId, totalAwardedPoints]
    );
    await client.query(
      `UPDATE users
          SET points = points + $2,
              points_history = points_history || to_jsonb($2::int)
        WHERE id = $1`,
      [ownerId, totalAwardedPoints]
    );
    await insertNotification(
      client,
      ownerId,
      'points_confirmed',
      'Points added',
      `Invoice approval granted ${totalAwardedPoints} point(s).`,
      {
        invoiceId,
        merchantPoints: summary.merchantPoints,
        brandPoints: summary.brandPoints,
      }
    );
  }

  return summary;
}

function offerMatchesTargeting(offerRow, userContext) {
  const targetType = String(offerRow.target_type || 'all').trim().toLowerCase();
  const targetValue = String(offerRow.target_value || '').trim().toLowerCase();
  const minPoints = Number(offerRow.min_points || 0);

  if (!targetType || targetType === 'all') return true;
  if (targetType === 'city') {
    return String(userContext.city || '').trim().toLowerCase() === targetValue;
  }
  if (targetType === 'country') {
    return String(userContext.country || '').trim().toLowerCase() === targetValue;
  }
  if (targetType === 'min_points') {
    return Number(userContext.availablePoints || 0) >= minPoints;
  }
  if (targetType === 'user_id') {
    return String(userContext.userId || '') === String(offerRow.target_value || '');
  }
  if (targetType === 'demographic_geo') {
    const criteria = parseTargetingCriteria(offerRow) || {};
    const minAge = Number(criteria.minAge);
    const maxAge = Number(criteria.maxAge);
    const userAge = Number(userContext.age);
    if (Number.isFinite(minAge) && (!Number.isFinite(userAge) || userAge < minAge)) return false;
    if (Number.isFinite(maxAge) && (!Number.isFinite(userAge) || userAge > maxAge)) return false;

    const requiredGender = String(criteria.gender || '').trim().toLowerCase();
    if (requiredGender && requiredGender !== 'any') {
      const userGender = String(userContext.gender || '').trim().toLowerCase();
      if (requiredGender !== userGender) return false;
    }

    const requiredCity = String(criteria.city || '').trim().toLowerCase();
    if (requiredCity) {
      if (String(userContext.city || '').trim().toLowerCase() !== requiredCity) return false;
    }

    const requiredCountry = String(criteria.country || '').trim().toLowerCase();
    if (requiredCountry) {
      if (String(userContext.country || '').trim().toLowerCase() !== requiredCountry) return false;
    }

    const centerLat = Number(criteria.centerLat);
    const centerLng = Number(criteria.centerLng);
    const maxDistanceKm = Number(criteria.maxDistanceKm);
    if (Number.isFinite(centerLat) && Number.isFinite(centerLng) && Number.isFinite(maxDistanceKm)) {
      const userLat = Number(userContext.locationLat);
      const userLng = Number(userContext.locationLng);
      if (!Number.isFinite(userLat) || !Number.isFinite(userLng)) return false;
      const d = haversineDistanceKm(userLat, userLng, centerLat, centerLng);
      if (d > maxDistanceKm) return false;
    }

    return true;
  }
  return false;
}

function calculatePointsWithFraction(purchaseAmount, pointValue, existingFraction) {
  const pv = Number(pointValue);
  const amount = Number(purchaseAmount);
  const fraction = Number(existingFraction || 0);
  if (!Number.isFinite(pv) || pv <= 0 || !Number.isFinite(amount) || amount <= 0) {
    return { points: 0, newFraction: fraction };
  }
  const effective = amount + fraction;
  const points = Math.floor(effective / pv);
  const newFraction = Number((effective - points * pv).toFixed(6));
  return { points, newFraction };
}

async function getMerchantProfileIdByUser(client, userId) {
  const row = (await client.query('SELECT id FROM merchant_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0];
  return row ? row.id : null;
}

async function getBrandProfileIdByUser(client, userId) {
  const row = (await client.query('SELECT id FROM brand_profiles WHERE user_id = $1 LIMIT 1', [userId])).rows[0];
  return row ? row.id : null;
}

function normalizeRoleType(value) {
  const v = String(value || '').trim().toLowerCase();
  if (v === 'merchant' || v === 'brand') return v;
  return null;
}

// Best-effort match: an OCR/AI-detected merchant name rarely matches a merchant_profiles
// row by exact ID, so compare the same normalized key used for invoice_scans.merchant_key.
async function resolveMerchantProfileIdByKey(client, merchantKey) {
  if (!merchantKey) return null;
  const rows = (await client.query(
    "SELECT id, business_name FROM merchant_profiles WHERE status = 'active'"
  )).rows;
  let best = null;
  for (const row of rows) {
    const profileKey = normalizeMerchantKey(row.business_name);
    if (!profileKey || profileKey.length < 4) continue;
    const matches = profileKey === merchantKey ||
      merchantKey.includes(profileKey) || profileKey.includes(merchantKey);
    if (matches && (!best || profileKey.length > best.length)) {
      best = { id: row.id, length: profileKey.length };
    }
  }
  return best?.id || null;
}

// Heuristic brand/product match for a scanned line item name (no AI call): looks for a
// substring match against active brands' product catalog and keeps the most specific hit.
async function autoMatchLineItemToBrand(client, itemName) {
  const normalizedItem = normalizeMerchantKey(itemName);
  if (normalizedItem.length < 4) return null;
  const rows = (await client.query(
    `SELECT pr.id AS product_id, pr.brand_id, pr.name
       FROM product_registry pr
       JOIN brand_profiles bp ON bp.id = pr.brand_id AND bp.status = 'active'`
  )).rows;
  let best = null;
  for (const row of rows) {
    const normalizedProduct = normalizeMerchantKey(row.name);
    if (normalizedProduct.length < 4) continue;
    if (normalizedItem.includes(normalizedProduct) || normalizedProduct.includes(normalizedItem)) {
      if (!best || normalizedProduct.length > best.matchLength) {
        best = { brandId: row.brand_id, productId: row.product_id, matchLength: normalizedProduct.length };
      }
    }
  }
  return best;
}

function matchesPeerAdCategory(targetCategory, merchantCategory) {
  const t = String(targetCategory || '').trim().toLowerCase();
  if (!t) return true;
  const m = String(merchantCategory || '').trim().toLowerCase();
  return t === m;
}

function parseGeoJson(raw) {
  if (!raw) return null;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(String(raw));
  } catch (_e) {
    return null;
  }
}

function matchesPeerAdGeo(geoJson, lat, lng) {
  const geo = parseGeoJson(geoJson);
  if (!geo || typeof geo !== 'object') return true;
  const centerLat = Number(geo.centerLat);
  const centerLng = Number(geo.centerLng);
  const maxDistanceKm = Number(geo.maxDistanceKm);
  if (!Number.isFinite(centerLat) || !Number.isFinite(centerLng) || !Number.isFinite(maxDistanceKm)) {
    return true;
  }
  const mLat = Number(lat);
  const mLng = Number(lng);
  if (!Number.isFinite(mLat) || !Number.isFinite(mLng)) return false;
  return haversineDistanceKm(mLat, mLng, centerLat, centerLng) <= maxDistanceKm;
}

function mapRewardRow(r) {
  return {
    id: r.id,
    reward_name: r.reward_name,
    description: r.description,
    value: r.value,
    kind: r.kind || 'digital',
    sourceType: r.source_type || 'system',
    sourceId: r.source_id || r.id,
    storeName: r.store_name || null,
    imageUrl: r.image_url || null,
    expiresAt: toIso(r.expires_at),
    pickupInstructions: r.pickup_instructions || null,
    drawEnabled: r.draw_enabled === true,
    drawAt: toIso(r.draw_at),
    drawWinnerUserId: r.draw_winner_user_id || null,
    drawCompletedAt: toIso(r.draw_completed_at),
  };
}

const REWARDS_WITH_STORE_NAME_SQL = `
  SELECT r.*, COALESCE(m.business_name, b.business_name) AS store_name
  FROM rewards r
  LEFT JOIN merchant_profiles m ON r.source_type = 'merchant' AND m.id = r.source_id
  LEFT JOIN brand_profiles b ON r.source_type = 'brand' AND b.id = r.source_id
`;

async function validateRewardSource(sourceType, sourceId) {
  if (sourceType === 'merchant') {
    const found = await pool.query('SELECT 1 FROM merchant_profiles WHERE id = $1', [sourceId]);
    if (!found.rowCount) return 'merchant_not_found';
  } else if (sourceType === 'brand') {
    const found = await pool.query('SELECT 1 FROM brand_profiles WHERE id = $1', [sourceId]);
    if (!found.rowCount) return 'brand_not_found';
  }
  return null;
}

function analyticsRangeDays(value) {
  switch (String(value || '30d').trim()) {
    case '7d':
      return 7;
    case '90d':
      return 90;
    default:
      return 30;
  }
}

function analyticsDaysAgo(days) {
  return new Date(Date.now() - (days * 24 * 60 * 60 * 1000));
}

function analyticsSafeNumber(value) {
  const parsed = Number(value || 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function analyticsPercentChange(current, previous) {
  const currentValue = analyticsSafeNumber(current);
  const previousValue = analyticsSafeNumber(previous);
  if (previousValue === 0) {
    return currentValue > 0 ? 100 : 0;
  }
  return Number((((currentValue - previousValue) / previousValue) * 100).toFixed(2));
}

function analyticsAgeBucket(birthDateValue) {
  if (!birthDateValue) return 'unknown';
  const birthDate = new Date(birthDateValue);
  if (Number.isNaN(birthDate.getTime())) return 'unknown';
  const now = new Date();
  let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - birthDate.getUTCMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getUTCDate() < birthDate.getUTCDate())) {
    age -= 1;
  }
  if (!Number.isFinite(age) || age < 18) return '<18';
  if (age <= 24) return '18-24';
  if (age <= 34) return '25-34';
  if (age <= 44) return '35-44';
  if (age <= 54) return '45-54';
  return '55+';
}

function analyticsCountEntries(input) {
  return Object.entries(input)
    .map(([label, value]) => ({ label, value: Number(value || 0) }))
    .sort((a, b) => b.value - a.value || String(a.label).localeCompare(String(b.label)));
}

function analyticsTopEntries(input, mapper) {
  return Object.values(input)
    .sort((a, b) => analyticsSafeNumber(b.salesTotal || b.value) - analyticsSafeNumber(a.salesTotal || a.value))
    .slice(0, 8)
    .map(mapper);
}


module.exports = {
  applyInvoiceApprovalRewards,
  offerMatchesTargeting,
  calculatePointsWithFraction,
  getMerchantProfileIdByUser,
  getBrandProfileIdByUser,
  normalizeRoleType,
  resolveMerchantProfileIdByKey,
  autoMatchLineItemToBrand,
  matchesPeerAdCategory,
  parseGeoJson,
  matchesPeerAdGeo,
  mapRewardRow,
  validateRewardSource,
  analyticsRangeDays,
  analyticsDaysAgo,
  analyticsSafeNumber,
  analyticsPercentChange,
  analyticsAgeBucket,
  analyticsCountEntries,
  analyticsTopEntries,
};
