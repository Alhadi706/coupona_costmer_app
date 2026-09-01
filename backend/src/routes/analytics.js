const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const https = require('https');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

module.exports = function registerAnalyticsRoutes(app, deps) {
  const {
    pool, CANONICAL_ROLES,
    PORT, JWT_SECRET, POS_GRANT_TOKEN_SECRET, POS_GRANT_TOKEN_TTL_SECONDS, FCM_SERVER_KEY,
    PAYMENT_WEBHOOK_SECRET, GEMINI_API_KEY, GEMINI_MODEL, ACCESS_TOKEN_TTL, KUPUNA_OWNER_EMAIL,
    OWNER_ENFORCEMENT_ENABLED, DEV_OWNER_BYPASS, SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD,
    EMAIL_FROM, OWNER_MFA_CODE_TTL_MS, OWNER_MFA_MAX_ATTEMPTS, DEV_OWNER_CHALLENGE_TTL_MS,
    devOwnerChallenges, GEMINI_FALLBACK_MODELS, AI_ONLY_MODE, UPLOAD_DIR, INVOICES_UPLOAD_DIR,
    CORS_ALLOWED_ORIGINS, AUTH_RATE_LIMIT_WINDOW_MS, LOGIN_RATE_LIMIT_MAX, SIGNUP_RATE_LIMIT_MAX,
    UPLOAD_RATE_LIMIT_WINDOW_MS, UPLOAD_RATE_LIMIT_MAX, requiredEnv, parseList, corsGuard,
    createRateLimiter, loginRateLimit, signupRateLimit, uploadRateLimit, ownerLoginRateLimit,
    ownerVerifyRateLimit, ownerResendRateLimit,
    id, normalizeRole, signAccessToken, isSystemOwner, smtpConfigured, ownerMailer,
    sendOwnerMfaCode, hashOwnerCode, ownerCode, isAdmin, isLoopbackRequest, canAccessUserObject,
    detectImageMime, toIso, normalizeMerchantKey, canonicalMerchantName, normalizeForFingerprint,
    buildInvoiceFingerprint, parseFlexibleDate, haversineDistanceKm, calculateAgeYears,
    parseTargetingCriteria, extractJsonObject, normalizeAiInvoiceFields, analyzeInvoiceWithGemini,
    auth, requireAdmin, ensureCustomerProfile, getIntSetting, canManageInvoice, canRedeemClaim,
    runSubscriptionTransitions, hasBlockRelation, isPrivateChatParticipant, getPeerUserId,
    sendFcmToTokens, getActivePushTokens, insertNotification, ensureCommunityGroupForRole,
    ensureCommunityMembership, joinCustomerToMerchantCommunity, joinCustomerToBrandCommunities,
    canModerateCommunityGroup, canTransitionSubscription, getSubscriptionOwnerUserId,
    syncCashierProfilesForMerchantSubscription, applySubscriptionTransition,
    assertMerchantSubscriptionWritable, isMerchantSubscriptionReadOnlyError,
    ensurePrivateChatBetweenUsers, applyInvoiceApprovalRewards, offerMatchesTargeting,
    calculatePointsWithFraction, getMerchantProfileIdByUser, getBrandProfileIdByUser,
    normalizeRoleType, resolveMerchantProfileIdByKey, autoMatchLineItemToBrand,
    matchesPeerAdCategory, parseGeoJson, matchesPeerAdGeo, mapRewardRow, validateRewardSource,
    analyticsRangeDays, analyticsDaysAgo, analyticsSafeNumber, analyticsPercentChange,
    analyticsAgeBucket, analyticsCountEntries, analyticsTopEntries,
  } = deps;

app.get('/api/merchant/analytics', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const merchantId = await getMerchantProfileIdByUser(client, req.user.userId);
    if (!merchantId) {
      return res.status(403).json({ error: 'merchant_role_required' });
    }

    const rangeDays = analyticsRangeDays(req.query.range);
    const currentStart = analyticsDaysAgo(rangeDays);
    const previousStart = analyticsDaysAgo(rangeDays * 2);
    const branchId = String(req.query.branchId || '').trim() || null;

    const profileRow = (await client.query(
      `SELECT id, business_name, point_value
         FROM merchant_profiles
        WHERE id = $1
        LIMIT 1`,
      [merchantId]
    )).rows[0];

    const branchRows = (await client.query(
      `SELECT id, name, address, latitude, longitude
         FROM branches
        WHERE merchant_id = $1
        ORDER BY created_at ASC`,
      [merchantId]
    )).rows;

    const invoiceParams = [merchantId, previousStart.toISOString()];
    let branchFilterClause = '';
    if (branchId) {
      invoiceParams.push(branchId);
      branchFilterClause = ` AND COALESCE(i.branch_id, '') = $${invoiceParams.length}`;
    }

    const invoiceRows = (await client.query(
      `SELECT i.id,
              i.owner_id,
              i.total_amount,
              i.category,
              i.created_at,
              i.branch_id,
              COALESCE(u.full_name, u.email, i.owner_id) AS customer_label,
              COALESCE(u.gender, 'unknown') AS gender,
              u.birth_date,
              cp.location_lat,
              cp.location_lng
         FROM invoice_scans i
         LEFT JOIN users u ON u.id = i.owner_id
         LEFT JOIN customer_profiles cp ON cp.user_id = i.owner_id
        WHERE i.merchant_profile_id = $1
          AND i.state = 'approved'
          AND i.created_at >= $2${branchFilterClause}
        ORDER BY i.created_at DESC`,
      invoiceParams
    )).rows;

    const historyParams = [merchantId];
    let historyBranchClause = '';
    if (branchId) {
      historyParams.push(branchId);
      historyBranchClause = ` AND COALESCE(branch_id, '') = $${historyParams.length}`;
    }

    const customerHistoryRows = (await client.query(
      `SELECT owner_id, MIN(created_at) AS first_purchase_at
         FROM invoice_scans
        WHERE merchant_profile_id = $1
          AND state = 'approved'${historyBranchClause}
        GROUP BY owner_id`,
      historyParams
    )).rows;

    const currentRows = invoiceRows.filter((row) => new Date(row.created_at) >= currentStart);
    const previousRows = invoiceRows.filter((row) => {
      const createdAt = new Date(row.created_at);
      return createdAt >= previousStart && createdAt < currentStart;
    });

    const currentSales = currentRows.reduce((sum, row) => sum + analyticsSafeNumber(row.total_amount), 0);
    const previousSales = previousRows.reduce((sum, row) => sum + analyticsSafeNumber(row.total_amount), 0);
    const averageBill = currentRows.length === 0 ? 0 : Number((currentSales / currentRows.length).toFixed(2));

    const currentCustomerIds = new Set(currentRows.map((row) => String(row.owner_id || '')).filter(Boolean));
    const previousCustomerIds = new Set(previousRows.map((row) => String(row.owner_id || '')).filter(Boolean));
    const retainedCustomerCount = Array.from(previousCustomerIds).filter((customerId) => currentCustomerIds.has(customerId)).length;

    const newCustomerCount = customerHistoryRows.filter((row) => {
      const ownerId = String(row.owner_id || '');
      if (!currentCustomerIds.has(ownerId)) return false;
      const firstPurchaseAt = new Date(row.first_purchase_at);
      return !Number.isNaN(firstPurchaseAt.getTime()) && firstPurchaseAt >= currentStart;
    }).length;
    const returningCustomerCount = Math.max(0, currentCustomerIds.size - newCustomerCount);
    const retentionRate = previousCustomerIds.size === 0
      ? (currentCustomerIds.size > 0 ? 1 : 0)
      : retainedCustomerCount / previousCustomerIds.size;
    const churnRate = previousCustomerIds.size === 0 ? 0 : 1 - retentionRate;

    const uniqueCustomerRows = [];
    const uniqueCustomerSeen = new Set();
    const genderCounts = {};
    const ageCounts = {};
    const customerHeatmap = {};
    const hourCounts = {};
    const weekdayCounts = {};

    for (const row of currentRows) {
      const createdAt = new Date(row.created_at);
      if (!Number.isNaN(createdAt.getTime())) {
        const hourKey = `${createdAt.getUTCHours().toString().padStart(2, '0')}:00`;
        hourCounts[hourKey] = (hourCounts[hourKey] || 0) + 1;
        const weekdayKey = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][createdAt.getUTCDay()];
        weekdayCounts[weekdayKey] = (weekdayCounts[weekdayKey] || 0) + 1;
      }

      const ownerId = String(row.owner_id || '');
      if (!ownerId || uniqueCustomerSeen.has(ownerId)) continue;
      uniqueCustomerSeen.add(ownerId);
      uniqueCustomerRows.push(row);

      const genderKey = String(row.gender || 'unknown').trim().toLowerCase() || 'unknown';
      genderCounts[genderKey] = (genderCounts[genderKey] || 0) + 1;

      const ageKey = analyticsAgeBucket(row.birth_date);
      ageCounts[ageKey] = (ageCounts[ageKey] || 0) + 1;

      if (row.location_lat != null && row.location_lng != null) {
        customerHeatmap[ownerId] = {
          id: ownerId,
          label: row.customer_label,
          latitude: Number(row.location_lat),
          longitude: Number(row.location_lng),
          value: 1,
        };
      }
    }

    const pointsRow = (await client.query(
      `SELECT COALESCE(SUM(points_delta), 0) AS total_points
         FROM points_ledger_merchant
        WHERE merchant_id = $1
          AND created_at >= $2`,
      [merchantId, currentStart.toISOString()]
    )).rows[0];

    const offerRows = (await client.query(
      `SELECT category, lifecycle_status, created_at
         FROM offers
        WHERE owner_id = $1
        ORDER BY created_at DESC`,
      [req.user.userId]
    )).rows;
    const currentOffers = offerRows.filter((row) => new Date(row.created_at) >= currentStart);
    const offerCategories = {};
    const offerStatuses = {};
    for (const row of currentOffers) {
      const categoryKey = String(row.category || 'other').trim() || 'other';
      const statusKey = String(row.lifecycle_status || 'unknown').trim() || 'unknown';
      offerCategories[categoryKey] = (offerCategories[categoryKey] || 0) + 1;
      offerStatuses[statusKey] = (offerStatuses[statusKey] || 0) + 1;
    }
    const topOfferCategory = analyticsCountEntries(offerCategories)[0]?.label || '-';

    const groupRow = (await client.query(
      `SELECT cg.id,
              cg.name,
              (SELECT COUNT(*)::int FROM community_group_members gm WHERE gm.group_id = cg.id) AS members_count,
              (SELECT COUNT(*)::int FROM community_messages cm WHERE cm.group_id = cg.id AND cm.created_at >= $2) AS messages_count
         FROM community_groups cg
        WHERE cg.role_type = 'merchant'
          AND cg.role_profile_id = $1
        LIMIT 1`,
      [merchantId, currentStart.toISOString()]
    )).rows[0];

    const topProductParams = [merchantId, currentStart.toISOString()];
    let topProductBranchClause = '';
    if (branchId) {
      topProductParams.push(branchId);
      topProductBranchClause = ` AND COALESCE(i.branch_id, '') = $${topProductParams.length}`;
    }
    const topProductRows = (await client.query(
      `SELECT COALESCE(pr.name, li.item_name, 'Unknown') AS product_name,
              COALESCE(bp.business_name, 'Unknown brand') AS brand_name,
              COALESCE(SUM(COALESCE(li.line_total, 0)), 0) AS sales_total,
              COALESCE(SUM(COALESCE(li.quantity, 1)), 0) AS quantity_total
         FROM invoice_scans i
         JOIN invoice_line_items li ON li.invoice_scan_id = i.id
         LEFT JOIN brand_matches bm ON bm.invoice_line_item_id = li.id
         LEFT JOIN product_registry pr ON pr.id = bm.product_id
         LEFT JOIN brand_profiles bp ON bp.id = bm.brand_id
        WHERE i.merchant_profile_id = $1
          AND i.state = 'approved'
          AND i.created_at >= $2${topProductBranchClause}
        GROUP BY COALESCE(pr.name, li.item_name, 'Unknown'), COALESCE(bp.business_name, 'Unknown brand')
        ORDER BY COALESCE(SUM(COALESCE(li.line_total, 0)), 0) DESC,
                 COALESCE(SUM(COALESCE(li.quantity, 1)), 0) DESC
        LIMIT 8`,
      topProductParams
    )).rows;

    const loyaltyRow = (await client.query(
      `SELECT score, trend
         FROM loyalty_health_scores
        WHERE merchant_id = $1
        ORDER BY generated_at DESC
        LIMIT 1`,
      [merchantId]
    )).rows[0];

    const peakHour = analyticsCountEntries(hourCounts)[0]?.label || '-';
    const peakDay = analyticsCountEntries(weekdayCounts)[0]?.label || '-';
    const branchScope = branchId
      ? branchRows.find((row) => String(row.id || '') === branchId) || null
      : null;

    return res.json({
      ok: true,
      merchantId,
      merchantName: profileRow?.business_name || null,
      branchScope: branchScope ? { id: branchScope.id, name: branchScope.name } : null,
      branches: branchRows.map((row) => ({
        id: row.id,
        name: row.name,
        address: row.address,
        latitude: row.latitude == null ? null : Number(row.latitude),
        longitude: row.longitude == null ? null : Number(row.longitude),
      })),
      sales: {
        total: Number(currentSales.toFixed(2)),
        invoiceCount: currentRows.length,
        averageBill,
        pointsAwarded: Number(pointsRow?.total_points || 0),
        salesGrowthPercent: analyticsPercentChange(currentSales, previousSales),
      },
      customers: {
        unique: currentCustomerIds.size,
        newCount: newCustomerCount,
        returningCount: returningCustomerCount,
        retentionPercent: Number((retentionRate * 100).toFixed(2)),
        churnPercent: Number((churnRate * 100).toFixed(2)),
      },
      demographics: {
        gender: analyticsCountEntries(genderCounts),
        ageBuckets: analyticsCountEntries(ageCounts),
      },
      customerHeatmap: Object.values(customerHeatmap),
      offerPerformance: {
        totalOffers: currentOffers.length,
        topCategory: topOfferCategory,
        statusBreakdown: analyticsCountEntries(offerStatuses),
      },
      peakTimes: {
        peakHour,
        peakDay,
        byHour: analyticsCountEntries(hourCounts),
        byWeekday: analyticsCountEntries(weekdayCounts),
      },
      groupMetrics: {
        groups: groupRow ? 1 : 0,
        groupName: groupRow?.name || null,
        members: Number(groupRow?.members_count || 0),
        messages: Number(groupRow?.messages_count || 0),
      },
      topBrandProducts: topProductRows.map((row) => ({
        name: row.product_name,
        brandName: row.brand_name,
        salesTotal: Number(row.sales_total || 0),
        quantity: Number(row.quantity_total || 0),
      })),
      financialSummary: {
        pointValue: Number(profileRow?.point_value || 0),
        branches: branchRows.length,
        totalSales: Number(currentSales.toFixed(2)),
        pointsAwarded: Number(pointsRow?.total_points || 0),
        averageBill,
      },
      loyaltyHealth: {
        score: Number(loyaltyRow?.score || 50),
        trend: loyaltyRow?.trend || 'stable',
      },
      topCustomersCount: uniqueCustomerRows.length,
    });
  } catch (e) {
    return res.status(500).json({ error: 'merchant_analytics_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/brand/analytics', auth, async (req, res) => {
  const client = await pool.connect();
  try {
    const brandId = await getBrandProfileIdByUser(client, req.user.userId);
    if (!brandId) {
      return res.status(403).json({ error: 'brand_role_required' });
    }

    const rangeDays = analyticsRangeDays(req.query.range);
    const currentStart = analyticsDaysAgo(rangeDays);
    const previousStart = analyticsDaysAgo(rangeDays * 2);

    const rows = (await client.query(
      `SELECT i.owner_id,
              i.created_at,
              i.merchant_profile_id,
              COALESCE(mp.business_name, i.merchant_name, 'Unknown merchant') AS merchant_name,
              mp.user_id AS merchant_user_id,
              mp.phone AS merchant_phone,
              mp.location_address AS merchant_address,
              mp.location_lat,
              mp.location_lng,
              COALESCE(pr.name, li.item_name, 'Unknown') AS product_name,
              COALESCE(li.quantity, 1) AS quantity,
              COALESCE(li.line_total, 0) AS line_total,
              COALESCE(u.gender, 'unknown') AS gender,
              u.birth_date
         FROM brand_matches bm
         JOIN invoice_line_items li ON li.id = bm.invoice_line_item_id
         JOIN invoice_scans i ON i.id = li.invoice_scan_id
         LEFT JOIN product_registry pr ON pr.id = bm.product_id
         LEFT JOIN merchant_profiles mp ON mp.id = i.merchant_profile_id
         LEFT JOIN users u ON u.id = i.owner_id
        WHERE bm.brand_id = $1
          AND i.state = 'approved'
          AND i.created_at >= $2
        ORDER BY i.created_at DESC`,
      [brandId, previousStart.toISOString()]
    )).rows;

    const currentRows = rows.filter((row) => new Date(row.created_at) >= currentStart);
    const previousRows = rows.filter((row) => {
      const createdAt = new Date(row.created_at);
      return createdAt >= previousStart && createdAt < currentStart;
    });

    const storeCurrent = {};
    const storePrevious = {};
    const productCurrent = {};
    const productPrevious = {};
    const genderCounts = {};
    const ageCounts = {};
    const merchantHeatmap = {};
    const dailySales = {};
    const uniqueCustomers = new Set();

    for (const row of currentRows) {
      const merchantKey = String(row.merchant_profile_id || row.merchant_name || 'unknown');
      const productKey = String(row.product_name || 'Unknown');
      const salesValue = analyticsSafeNumber(row.line_total);
      const quantityValue = analyticsSafeNumber(row.quantity);
      const day = new Date(row.created_at).toISOString().slice(0, 10);
      dailySales[day] = (dailySales[day] || 0) + salesValue;

      if (!storeCurrent[merchantKey]) {
        storeCurrent[merchantKey] = {
          key: merchantKey,
          name: row.merchant_name,
          salesTotal: 0,
          quantity: 0,
          userId: row.merchant_user_id,
          phone: row.merchant_phone,
          address: row.merchant_address,
        };
      }
      storeCurrent[merchantKey].salesTotal += salesValue;
      storeCurrent[merchantKey].quantity += quantityValue;

      if (!productCurrent[productKey]) {
        productCurrent[productKey] = {
          name: productKey,
          salesTotal: 0,
          quantity: 0,
        };
      }
      productCurrent[productKey].salesTotal += salesValue;
      productCurrent[productKey].quantity += quantityValue;

      if (row.location_lat != null && row.location_lng != null) {
        merchantHeatmap[merchantKey] = {
          id: merchantKey,
          label: row.merchant_name,
          latitude: Number(row.location_lat),
          longitude: Number(row.location_lng),
          value: Number(storeCurrent[merchantKey].salesTotal.toFixed(2)),
        };
      }

      const ownerId = String(row.owner_id || '');
      if (!ownerId || uniqueCustomers.has(ownerId)) continue;
      uniqueCustomers.add(ownerId);

      const genderKey = String(row.gender || 'unknown').trim().toLowerCase() || 'unknown';
      genderCounts[genderKey] = (genderCounts[genderKey] || 0) + 1;

      const ageKey = analyticsAgeBucket(row.birth_date);
      ageCounts[ageKey] = (ageCounts[ageKey] || 0) + 1;
    }

    for (const row of previousRows) {
      const merchantKey = String(row.merchant_profile_id || row.merchant_name || 'unknown');
      const productKey = String(row.product_name || 'Unknown');
      const salesValue = analyticsSafeNumber(row.line_total);
      const quantityValue = analyticsSafeNumber(row.quantity);

      if (!storePrevious[merchantKey]) {
        storePrevious[merchantKey] = { salesTotal: 0, quantity: 0 };
      }
      storePrevious[merchantKey].salesTotal += salesValue;
      storePrevious[merchantKey].quantity += quantityValue;

      if (!productPrevious[productKey]) {
        productPrevious[productKey] = { salesTotal: 0, quantity: 0 };
      }
      productPrevious[productKey].salesTotal += salesValue;
      productPrevious[productKey].quantity += quantityValue;
    }

    const topSellingStores = analyticsTopEntries(storeCurrent, (entry) => ({
      name: entry.name,
      salesTotal: Number(entry.salesTotal.toFixed(2)),
      quantity: Number(entry.quantity || 0),
      key: entry.key,
      userId: entry.userId,
      phone: entry.phone,
      address: entry.address,
    }));
    const lowestSellingStores = Object.values(storeCurrent)
      .sort((a, b) => analyticsSafeNumber(a.salesTotal) - analyticsSafeNumber(b.salesTotal))
      .slice(0, 8)
      .map((entry) => ({
        name: entry.name,
        salesTotal: Number(analyticsSafeNumber(entry.salesTotal).toFixed(2)),
        quantity: Number(entry.quantity || 0),
        key: entry.key,
        userId: entry.userId,
        phone: entry.phone,
        address: entry.address,
      }));
    const topProducts = analyticsTopEntries(productCurrent, (entry) => ({
      name: entry.name,
      salesTotal: Number(entry.salesTotal.toFixed(2)),
      quantity: Number(entry.quantity || 0),
    }));

    const topStore = topSellingStores[0];
    const topProduct = topProducts[0];
    const currentTotal = currentRows.reduce((sum, row) => sum + analyticsSafeNumber(row.line_total), 0);
    const previousTotal = previousRows.reduce((sum, row) => sum + analyticsSafeNumber(row.line_total), 0);

    return res.json({
      ok: true,
      brandId,
      distributionHeatmap: Object.values(merchantHeatmap),
      topSellingStores,
      lowestSellingStores,
      topProducts,
      dailySales: Object.entries(dailySales)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, sales]) => ({ date, sales: Number(Number(sales).toFixed(2)) })),
      growthLevels: [
        {
          level: 'overall',
          label: 'Overall brand sales',
          current: Number(currentTotal.toFixed(2)),
          previous: Number(previousTotal.toFixed(2)),
          growthPercent: analyticsPercentChange(currentTotal, previousTotal),
        },
        {
          level: 'store',
          label: topStore?.name || 'Top store',
          current: Number(analyticsSafeNumber(topStore?.salesTotal).toFixed(2)),
          previous: Number(analyticsSafeNumber(storePrevious[topStore?.key || '']?.salesTotal).toFixed(2)),
          growthPercent: analyticsPercentChange(
            analyticsSafeNumber(topStore?.salesTotal),
            analyticsSafeNumber(storePrevious[topStore?.key || '']?.salesTotal)
          ),
        },
        {
          level: 'product',
          label: topProduct?.name || 'Top product',
          current: Number(analyticsSafeNumber(topProduct?.salesTotal).toFixed(2)),
          previous: Number(analyticsSafeNumber(productPrevious[topProduct?.name || '']?.salesTotal).toFixed(2)),
          growthPercent: analyticsPercentChange(
            analyticsSafeNumber(topProduct?.salesTotal),
            analyticsSafeNumber(productPrevious[topProduct?.name || '']?.salesTotal)
          ),
        },
      ],
      consumerDemographics: {
        gender: analyticsCountEntries(genderCounts),
        ageBuckets: analyticsCountEntries(ageCounts),
      },
      matchedCustomers: uniqueCustomers.size,
      matchedSales: Number(currentTotal.toFixed(2)),
    });
  } catch (e) {
    return res.status(500).json({ error: 'brand_analytics_failed', details: String(e.message || e) });
  } finally {
    client.release();
  }
});

app.get('/api/merchant/customers/top', auth, async (req, res) => {
  const merchantName = String(req.query.merchantName || '').trim();
  if (!merchantName) {
    return res.status(400).json({ error: 'merchant_name_required' });
  }
  const merchantKey = normalizeMerchantKey(merchantName);
  const limit = Math.max(1, Math.min(100, Number(req.query.limit || 20)));

  const rows = (await pool.query(
    `SELECT i.owner_id,
            u.email,
            COALESCE(u.full_name, '') AS full_name,
            COUNT(*)::int AS invoices_count,
            COALESCE(SUM(i.total_amount), 0) AS total_spent,
            MAX(i.created_at) AS last_purchase_at,
            COALESCE(SUM(CASE WHEN i.category = 'food' THEN i.total_amount ELSE 0 END), 0) AS food_spent,
            COALESCE(SUM(CASE WHEN i.category = 'grocery' THEN i.total_amount ELSE 0 END), 0) AS grocery_spent,
            COALESCE(SUM(CASE WHEN i.category = 'pharmacy' THEN i.total_amount ELSE 0 END), 0) AS pharmacy_spent,
            COALESCE(SUM(CASE WHEN i.category = 'transport' THEN i.total_amount ELSE 0 END), 0) AS transport_spent
       FROM invoice_scans i
       LEFT JOIN users u ON u.id = i.owner_id
      WHERE i.merchant_key = $1
      GROUP BY i.owner_id, u.email, u.full_name
      ORDER BY COALESCE(SUM(i.total_amount), 0) DESC, COUNT(*) DESC
      LIMIT $2`,
    [merchantKey, limit]
  )).rows;

  res.json(rows.map((row) => ({
    customerId: row.owner_id,
    customerEmail: row.email,
    customerName: row.full_name,
    invoicesCount: Number(row.invoices_count || 0),
    totalSpent: Number(row.total_spent || 0),
    lastPurchaseAt: toIso(row.last_purchase_at),
    consumption: {
      food: Number(row.food_spent || 0),
      grocery: Number(row.grocery_spent || 0),
      pharmacy: Number(row.pharmacy_spent || 0),
      transport: Number(row.transport_spent || 0),
    },
  })));
});

};
