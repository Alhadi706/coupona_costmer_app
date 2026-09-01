const { pool } = require('./db');
const { id, toIso, parseTargetingCriteria, normalizeMerchantKey } = require('./helpers');
const { ensureCommunityGroupForRole, ensureCommunityMembership, joinCustomerToMerchantCommunity,
  joinCustomerToBrandCommunities, insertNotification } = require('./services-social');
const { issueRaffleTicketsForInvoice } = require('./promotion-campaign-service');

async function applyInvoiceApprovalRewards(client, invoiceId, ownerId, merchantProfileId) {
  const summary = {
    merchantPoints: 0,
    merchantFraction: 0,
    degradedLocalMode: false,
    merchantTokenBalance: null,
    pendingMerchantPoints: 0,
    brandPoints: 0,
    brandBreakdown: [],
    raffleTickets: [],
  };

  const invoice = (await client.query(
    'SELECT total_amount FROM invoice_scans WHERE id = $1 LIMIT 1',
    [invoiceId]
  )).rows[0];
  const invoiceTotalAmount = Number(invoice?.total_amount || 0);

  if (merchantProfileId && Number.isFinite(invoiceTotalAmount) && invoiceTotalAmount > 0) {
    summary.raffleTickets = await issueRaffleTicketsForInvoice(client, 'merchant', merchantProfileId, ownerId, invoiceId, invoiceTotalAmount);
  }

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
          `INSERT INTO merchant_token_wallets (merchant_id, balance, currency, is_local_mode, last_updated_at)
           VALUES ($1, 0, 'SAR', FALSE, NOW())
           ON CONFLICT (merchant_id) DO NOTHING`,
          [merchantProfileId]
        );
        const tokenWallet = (await client.query(
          `SELECT balance
             FROM merchant_token_wallets
            WHERE merchant_id = $1
            FOR UPDATE`,
          [merchantProfileId]
        )).rows[0];
        const tokenBalance = Number(tokenWallet?.balance || 0);
        const { rows: [tierRow] } = await client.query(`
          SELECT CASE WHEN mp.is_public_coalition_active THEN 'gold'
                      WHEN EXISTS (
                        SELECT 1 FROM coalition_members cm JOIN coalitions c ON c.id = cm.coalition_id
                         WHERE cm.merchant_id = mp.id AND c.type = 'private' AND c.is_active = TRUE
                      ) THEN 'silver' ELSE 'bronze' END AS tier,
                  CASE WHEN mp.is_public_coalition_active THEN 'public-platform-coalition'
                       WHEN EXISTS (
                        SELECT 1 FROM coalition_members cm JOIN coalitions c ON c.id = cm.coalition_id
                         WHERE cm.merchant_id = mp.id AND c.type = 'private' AND c.is_active = TRUE
                      ) THEN (
                        SELECT cm.coalition_id FROM coalition_members cm JOIN coalitions c ON c.id = cm.coalition_id
                         WHERE cm.merchant_id = mp.id AND c.type = 'private' AND c.is_active = TRUE
                         ORDER BY cm.joined_at ASC LIMIT 1
                      ) ELSE NULL END AS coalition_id
            FROM merchant_profiles mp WHERE mp.id = $1
        `, [merchantProfileId]);
        const tier = tierRow?.tier || 'bronze';
        const coalitionId = tierRow?.coalition_id || null;
        const pending = tokenBalance < calc.points;
        const balanceAfter = pending ? tokenBalance : tokenBalance - calc.points;
        await client.query(
          `UPDATE merchant_token_wallets
              SET balance = $2,
                  is_local_mode = $3,
                  last_updated_at = NOW()
            WHERE merchant_id = $1`,
          [merchantProfileId, balanceAfter, false]
        );
        if (pending) {
          await client.query(`
            INSERT INTO customer_pending_points
              (id, customer_id, merchant_id, invoice_id, points, points_remaining, tier, coalition_id)
            VALUES ($1, $2, $3, $4, $5, $5, $6, $7)
          `, [id(), ownerId, merchantProfileId, invoiceId, calc.points, tier, coalitionId]);
          summary.pendingMerchantPoints = calc.points;
          summary.merchantPoints = 0;
        }
        await client.query(
          `INSERT INTO merchant_token_ledger
            (id, merchant_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
          [
            id(),
            merchantProfileId,
            ownerId,
            invoiceId,
            pending ? 'points_pending' : 'points_debited',
            pending ? 0 : calc.points,
            balanceAfter,
          ]
        );
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
        if (!pending) summary.merchantPoints = calc.points;
        summary.merchantFraction = calc.newFraction;
        summary.degradedLocalMode = false;
        summary.merchantTokenBalance = balanceAfter;
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
      `INSERT INTO brand_token_wallets (brand_id, balance, currency, is_local_mode, last_updated_at)
       VALUES ($1, 0, 'SAR', FALSE, NOW())
       ON CONFLICT (brand_id) DO NOTHING`,
      [brandId]
    );
    const brandWallet = (await client.query(
      `SELECT balance FROM brand_token_wallets WHERE brand_id = $1 FOR UPDATE`,
      [brandId]
    )).rows[0];
    const brandTokenBalance = Number(brandWallet?.balance || 0);
    const brandPending = brandTokenBalance < calc.points;
    const brandBalanceAfter = brandPending ? brandTokenBalance : brandTokenBalance - calc.points;
    await client.query(
      `UPDATE brand_token_wallets SET balance = $2, is_local_mode = $3, last_updated_at = NOW() WHERE brand_id = $1`,
      [brandId, brandBalanceAfter, false]
    );
    await client.query(
      `INSERT INTO brand_token_ledger (id, brand_id, customer_user_id, receipt_id, type, amount, balance_after, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
      [id(), brandId, ownerId, invoiceId, brandPending ? 'points_pending' : 'points_debited', brandPending ? 0 : calc.points, brandBalanceAfter]
    );

    if (brandPending) {
      await client.query(`
        INSERT INTO customer_pending_brand_points
          (id, customer_id, brand_id, invoice_id, points, points_remaining)
        VALUES ($1, $2, $3, $4, $5, $5)
      `, [id(), ownerId, brandId, invoiceId, calc.points]);
    } else {
      await client.query(
        `INSERT INTO points_ledger_brand (
          id, customer_id, brand_id, invoice_scan_id, points_delta, fraction_before, fraction_after, status, expires_at
        ) VALUES (
          $1,$2,$3,$4,$5,$6,$7,'active',NOW() + INTERVAL '12 months'
        )`,
        [id(), ownerId, brandId, invoiceId, calc.points, before, calc.newFraction]
      );
      summary.brandPoints += calc.points;
    }
    summary.brandBreakdown.push({
      brandId,
      lineAmount,
      points: calc.points,
      pending: brandPending,
      fraction: calc.newFraction,
    });
  }

  const totalAwardedPoints = summary.merchantPoints + summary.brandPoints;
  if (totalAwardedPoints > 0) {
    if (summary.merchantPoints > 0 && merchantProfileId) {
      const { rows: [merchantTier] } = await client.query(`
        SELECT
          CASE WHEN mp.is_public_coalition_active THEN 'gold'
               WHEN EXISTS (
                 SELECT 1 FROM coalition_members cm
                 JOIN coalitions c ON c.id = cm.coalition_id
                 WHERE cm.merchant_id = mp.id AND c.type = 'private' AND c.is_active = TRUE
               ) THEN 'silver'
               ELSE 'bronze' END AS tier,
          CASE WHEN mp.is_public_coalition_active THEN NULL ELSE mp.id END AS merchant_id,
          CASE WHEN mp.is_public_coalition_active THEN NULL ELSE (
            SELECT cm.coalition_id FROM coalition_members cm
            JOIN coalitions c ON c.id = cm.coalition_id
            WHERE cm.merchant_id = mp.id AND c.type = 'private' AND c.is_active = TRUE
            ORDER BY cm.joined_at ASC LIMIT 1
          ) END AS coalition_id
        FROM merchant_profiles mp WHERE mp.id = $1
      `, [merchantProfileId]);
      const tier = merchantTier?.tier || 'bronze';
      await client.query(`
        INSERT INTO customer_point_tiers
          (id, customer_id, tier, merchant_id, coalition_id, balance, lifetime_earned)
        VALUES ($1, $2, $3, $4, $5, $6, $6)
        ON CONFLICT (customer_id, tier, COALESCE(merchant_id, ''), COALESCE(coalition_id, ''))
        DO UPDATE SET balance = customer_point_tiers.balance + EXCLUDED.balance,
                      lifetime_earned = customer_point_tiers.lifetime_earned + EXCLUDED.lifetime_earned,
                      updated_at = NOW()
      `, [id(), ownerId, tier, merchantTier?.merchant_id || null, merchantTier?.coalition_id || null, summary.merchantPoints]);

      const coalitionQuery = tier === 'gold'
        ? `SELECT id FROM coalitions WHERE id = 'public-platform-coalition' AND is_active = TRUE`
        : `SELECT coalition_id AS id FROM coalition_members WHERE merchant_id = $1
             AND EXISTS (SELECT 1 FROM coalitions c WHERE c.id = coalition_members.coalition_id AND c.type = 'private' AND c.is_active = TRUE)`;
      const { rows: tierCoalitions } = await client.query(coalitionQuery, tier === 'gold' ? [] : [merchantProfileId]);
      for (const coalition of tierCoalitions) {
        await client.query(`
          INSERT INTO customer_merchant_point_balances
            (customer_id, merchant_id, coalition_id, points_balance)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (customer_id, merchant_id, coalition_id)
          DO UPDATE SET points_balance = customer_merchant_point_balances.points_balance + EXCLUDED.points_balance,
                        last_updated = NOW()
        `, [ownerId, merchantProfileId, coalition.id, summary.merchantPoints]);
      }
    }
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

    const messageParts = [];
    if (summary.merchantPoints > 0 && merchantProfileId) {
      const { rows: [merchantRow] } = await client.query(
        'SELECT business_name FROM merchant_profiles WHERE id = $1 LIMIT 1',
        [merchantProfileId]
      );
      messageParts.push(`${summary.merchantPoints} نقطة من ${merchantRow?.business_name || 'المتجر'}`);
    }
    for (const entry of summary.brandBreakdown) {
      if (entry.pending || entry.points <= 0) continue;
      const { rows: [brandRow] } = await client.query(
        'SELECT business_name FROM brand_profiles WHERE id = $1 LIMIT 1',
        [entry.brandId]
      );
      messageParts.push(`${entry.points} نقطة من علامة ${brandRow?.business_name || 'البراند'}`);
    }
    const itemizedMessage = messageParts.length > 0
      ? `تهانينا! حصلت على ${messageParts.join('، و')}.`
      : `Invoice approval granted ${totalAwardedPoints} point(s).`;

    await insertNotification(
      client,
      ownerId,
      'points_confirmed',
      'Points added',
      itemizedMessage,
      {
        invoiceId,
        merchantPoints: summary.merchantPoints,
        brandPoints: summary.brandPoints,
        brandBreakdown: summary.brandBreakdown,
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
  REWARDS_WITH_STORE_NAME_SQL,
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
