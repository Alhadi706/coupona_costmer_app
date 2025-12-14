import * as functions from 'firebase-functions';
import admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const {Timestamp, GeoPoint, FieldValue} = admin.firestore;
const PERFORMANCE_COLLECTION = 'brand_store_performance';
const DEFAULT_LOCATION = new GeoPoint(32.8872, 13.1913);

export const syncCommunityMembership = functions
  .region('us-central1')
  .firestore.document('invoiceLinks/{linkId}')
  .onCreate(async (snapshot, context) => {
    const link = snapshot.data();
    if (!link) {
      functions.logger.warn('Invoice link payload missing', context.params.linkId);
      return null;
    }

    const merchantId = (link.merchantId || '').toString();
    const customerId = (link.customerId || '').toString();
    if (!merchantId || !customerId) {
      functions.logger.warn('Invoice link lacks merchantId or customerId', {
        merchantId,
        customerId,
        linkId: context.params.linkId,
      });
      return null;
    }

    const communitiesSnap = await db.collection('communities').where('merchantId', '==', merchantId).get();
    if (communitiesSnap.empty) {
      await createFallbackCommunity({merchantId, customerId});
      return null;
    }

    const batch = db.batch();
    communitiesSnap.forEach((doc) => {
      batch.update(doc.ref, {
        members: FieldValue.arrayUnion(customerId),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    try {
      await batch.commit();
      functions.logger.info('Synced community membership', {merchantId, customerId, linkId: context.params.linkId});
    } catch (error) {
      functions.logger.error('Failed to sync community membership', {
        merchantId,
        customerId,
        error,
      });
    }

    return null;
  });

export const aggregateBrandStorePerformance = functions
  .region('us-central1')
  .runWith({memory: '512MB', timeoutSeconds: 120})
  .firestore.document('invoices/{invoiceId}')
  .onCreate(async (snapshot, context) => {
    const invoice = snapshot.data();
    if (!invoice) {
      functions.logger.warn('Invoice payload missing', context.params.invoiceId);
      return null;
    }

    const merchantId = resolveMerchantId(invoice);
    if (!merchantId) {
      functions.logger.warn('Invoice missing merchantId', {invoiceId: context.params.invoiceId});
      return null;
    }

    const lineItems = resolveLineItems(invoice);
    const normalizedItems = normalizeInvoiceItems(lineItems);
    if (!normalizedItems.length) {
      functions.logger.info('Invoice contains no recognizable items; skip aggregation', {
        invoiceId: context.params.invoiceId,
        merchantId,
      });
      return null;
    }

    const merchantSnap = await db.collection('merchants').doc(merchantId).get();
    const merchantData = merchantSnap.data() ?? {};
    const storeName = merchantData.name || merchantData.storeName || `Store ${merchantId}`;
    const storeLocation = resolveLocation(merchantData.location) ?? DEFAULT_LOCATION;

    const catalog = await buildProductCatalog({merchantId, items: normalizedItems});
    const brandGroups = buildBrandGroups(normalizedItems, catalog);
    if (!brandGroups.size) {
      functions.logger.info('No branded products found for invoice', {
        invoiceId: context.params.invoiceId,
        merchantId,
      });
      return null;
    }

    const timestamp = resolveTimestamp(invoice);
    const invoiceDate = timestamp.toDate();
    const invoiceMeta = {
      timestamp,
      dayLabel: invoiceDate.toLocaleDateString('en-US', {weekday: 'long'}),
      hourLabel: `${invoiceDate.getHours().toString().padStart(2, '0')}:00`,
      customerId: resolveCustomerId(invoice),
    };

    for (const [brandId, group] of brandGroups.entries()) {
      try {
        await upsertStorePerformance({
          brandId,
          storeId: merchantId,
          storeName,
          location: storeLocation,
          group,
          invoiceMeta,
        });
      } catch (error) {
        functions.logger.error('Failed to aggregate store performance', {brandId, merchantId, error});
      }
    }

    return null;
  });

async function buildProductCatalog({merchantId, items}) {
  const catalog = {byId: new Map(), byName: new Map()};
  if (!Array.isArray(items) || !items.length) {
    return catalog;
  }

  const needsNameLookup = items.some((item) => !item.productId && item.productName);
  if (needsNameLookup) {
    const snap = await db.collection('products').where('merchantId', '==', merchantId).get();
    snap.forEach((doc) => addProductToCatalog(doc, catalog));
    return catalog;
  }

  const productIds = [...new Set(items.map((item) => item.productId).filter(Boolean))];
  if (!productIds.length) {
    return catalog;
  }

  const snapshots = await Promise.all(productIds.map((productId) => db.collection('products').doc(productId).get()));
  snapshots.forEach((snap) => {
    if (snap.exists) {
      addProductToCatalog(snap, catalog);
    }
  });
  return catalog;
}

function addProductToCatalog(doc, catalog) {
  const data = doc.data() ?? {};
  const record = {...data, id: doc.id};
  catalog.byId.set(doc.id, record);
  const normalizedName = normalizeName(record.name || record.title);
  if (normalizedName) {
    catalog.byName.set(normalizedName, record);
  }
}

function resolveCatalogProduct(item, catalog) {
  if (!catalog) {
    return null;
  }
  if (item.productId && catalog.byId.has(item.productId)) {
    return catalog.byId.get(item.productId);
  }
  const normalizedName = normalizeName(item.productName);
  if (normalizedName && catalog.byName.has(normalizedName)) {
    return catalog.byName.get(normalizedName);
  }
  return null;
}

function resolveLineItems(invoice) {
  const candidates = [
    invoice.items,
    invoice.lineItems,
    invoice.products,
    invoice.invoice_payload?.items,
    invoice.invoice_payload?.products,
    invoice.invoicePayload?.items,
    invoice.invoicePayload?.products,
    invoice.payload?.items,
    invoice.payload?.products,
    invoice.invoice_details?.items,
    invoice.invoice_details?.products,
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate) && candidate.length) {
      return candidate;
    }
  }
  return [];
}

function normalizeInvoiceItems(rawItems) {
  if (!Array.isArray(rawItems)) {
    return [];
  }
  return rawItems
    .map((item) => normalizeInvoiceItem(item))
    .filter(Boolean);
}

function normalizeInvoiceItem(raw) {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const productId = pickFirstString(raw, ['productId', 'product_id', 'productID', 'id', 'productCode', 'code', 'sku', 'barcode']);
  const productName = pickFirstString(raw, ['productName', 'product_name', 'name', 'title', 'description']);
  const quantity = pickFirstNumber(raw, ['quantity', 'qty', 'count', 'units', 'amount', 'qty_sold']);
  const price = pickFirstNumber(raw, ['price', 'unitPrice', 'unit_price', 'unitCost', 'total', 'lineTotal', 'amount', 'subtotal']);

  if (!productId && !productName) {
    return null;
  }

  const safeQuantity = Number.isFinite(quantity) && quantity > 0 ? quantity : 1;
  const safePrice = Number.isFinite(price) ? price : 0;
  return {
    productId: productId || '',
    productName: productName || '',
    quantity: safeQuantity,
    price: safePrice,
  };
}

function pickFirstString(source, keys) {
  for (const key of keys) {
    const value = source[key];
    if (value === undefined || value === null) {
      continue;
    }
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed.length) {
        return trimmed;
      }
    }
    if (typeof value === 'number' || typeof value === 'bigint') {
      return value.toString();
    }
  }
  return null;
}

function pickFirstNumber(source, keys) {
  for (const key of keys) {
    const value = source[key];
    if (value === undefined || value === null) {
      continue;
    }
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return null;
}

function normalizeName(value) {
  if (!value || typeof value !== 'string') {
    return '';
  }
  return value
    .toLowerCase()
    .replace(/[^\p{L}\p{Nd}\s]/gu, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function resolveMerchantId(invoice) {
  const candidate =
    invoice.merchantId ??
    invoice.merchant_id ??
    invoice.merchantID ??
    invoice.storeId ??
    invoice.store_id ??
    invoice.merchantUuid ??
    invoice.merchant_uuid ??
    invoice.merchant?.id ??
    invoice.invoice_payload?.merchantId ??
    invoice.invoice_payload?.merchant_id ??
    invoice.invoice_payload?.merchant_uuid ??
    invoice.invoicePayload?.merchantId ??
    invoice.invoicePayload?.merchant_id;
  return candidate ? candidate.toString() : '';
}

function resolveCustomerId(invoice) {
  const candidate =
    invoice.customerId ??
    invoice.customer_id ??
    invoice.customerID ??
    invoice.userId ??
    invoice.user_id ??
    invoice.customerUid ??
    invoice.customer_uid ??
    invoice.user?.id ??
    invoice.customer?.id ??
    invoice.invoice_payload?.customerId ??
    invoice.invoice_payload?.customer_id ??
    invoice.invoice_payload?.user_id ??
    invoice.invoicePayload?.customerId ??
    invoice.invoicePayload?.userId;
  return candidate ? candidate.toString() : '';
}

function resolveTimestamp(invoice) {
  const candidate =
    invoice.createdAt ??
    invoice.created_at ??
    invoice.timestamp ??
    invoice.date ??
    invoice.invoiceDate ??
    invoice.invoice_payload?.createdAt ??
    invoice.invoice_payload?.date ??
    invoice.invoicePayload?.createdAt;
  if (candidate instanceof Timestamp) {
    return candidate;
  }
  if (candidate instanceof Date) {
    return Timestamp.fromDate(candidate);
  }
  if (typeof candidate === 'number') {
    return Timestamp.fromMillis(candidate);
  }
  if (typeof candidate === 'string') {
    const parsed = Date.parse(candidate);
    if (!Number.isNaN(parsed)) {
      return Timestamp.fromDate(new Date(parsed));
    }
  }
  return Timestamp.now();
}

async function createFallbackCommunity({merchantId, customerId}) {
  const merchantSnap = await db.collection('merchants').doc(merchantId).get();
  const merchantData = merchantSnap.data() ?? {};
  const merchantName = merchantData.name || merchantData.storeName || `Community ${merchantId}`;

  await db.collection('communities').add({
    merchantId,
    name: merchantName,
    members: [merchantId, customerId],
    description: merchantData.description || null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  functions.logger.info('Created fallback community', {merchantId, customerId});
}

function buildBrandGroups(items, catalog) {
  const groups = new Map();
  items.forEach((item) => {
    const product = resolveCatalogProduct(item, catalog);
    if (!product?.brandId) {
      return;
    }

    const productKey = product.id || item.productId || normalizeName(item.productName) || product.brandId;
    const quantity = Number(item.quantity ?? 0);
    const price = Number(item.price ?? 0);
    const revenue = quantity > 0 ? quantity * price : price;
    const safeRevenue = Number.isFinite(revenue) ? revenue : 0;
    const safeQuantity = Number.isFinite(quantity) ? quantity : 0;

    if (!groups.has(product.brandId)) {
      groups.set(product.brandId, {
        revenue: 0,
        units: 0,
        products: new Map(),
      });
    }
    const group = groups.get(product.brandId);
    group.revenue += safeRevenue;
    group.units += safeQuantity;

    const perf = group.products.get(productKey) ?? createProductPerformance(productKey, product, item.productName);
    perf.unitsSold += safeQuantity;
    perf.revenue += safeRevenue;
    group.products.set(productKey, perf);
  });
  return groups;
}

function createProductPerformance(productId, product, fallbackName) {
  return {
    productId,
    productName: product?.name || product?.title || fallbackName || 'منتج',
    unitsSold: 0,
    revenue: 0,
    growthRate: 0,
    customerCount: 0,
    seasonality: product?.seasonality || 'evergreen',
    peakDays: [],
    peakHours: [],
  };
}

async function upsertStorePerformance({brandId, storeId, storeName, location, group, invoiceMeta}) {
  const docId = `${brandId}_${storeId}`;
  const ref = db.collection(PERFORMANCE_COLLECTION).doc(docId);

  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const existing = snapshot.exists ? snapshot.data() : {};
    const previousSales = Number(existing?.totalSales || 0);
    const previousTransactions = Number(existing?.totalTransactions || 0);

    const totalSales = previousSales + Number(group.revenue || 0);
    const totalTransactions = previousTransactions + 1;
    const storeAverage = totalTransactions > 0 ? totalSales / totalTransactions : 0;
    const growthRate = previousSales === 0 ? 100 : ((totalSales - previousSales) / Math.max(previousSales, 1)) * 100;

    const updatedProducts = mergeProductMaps(existing?.products ?? {}, group.products, invoiceMeta);
    const derivedIssues = deriveIssues(totalSales, growthRate);
    const issues = mergeUnique(existing?.issues ?? [], derivedIssues);

    const payload = {
      storeId,
      storeName,
      brandId,
      location,
      products: updatedProducts,
      totalSales: toNumber(totalSales),
      totalTransactions,
      growthRate: toNumber(growthRate),
      marketShare: existing?.marketShare ?? 0,
      lastSaleDate: invoiceMeta.timestamp,
      rating: selectRating(totalSales, growthRate),
      issues,
      recommendations: existing?.recommendations ?? [],
      storeAverage: toNumber(storeAverage),
      brandAverage: existing?.brandAverage ?? 0,
      difference: existing?.difference ?? 0,
    };

    tx.set(ref, payload, {merge: true});
  });

  await recomputeBrandStats(brandId);
}

function mergeProductMaps(existingProducts, incomingProducts, invoiceMeta) {
  const merged = {...existingProducts};
  incomingProducts.forEach((incoming, productId) => {
    const current = merged[productId] ?? {
      productId,
      productName: incoming.productName,
      unitsSold: 0,
      revenue: 0,
      growthRate: 0,
      customerCount: 0,
      seasonality: incoming.seasonality ?? 'evergreen',
      peakDays: [],
      peakHours: [],
    };

    const previousRevenue = Number(current.revenue || 0);
    current.unitsSold = Number(current.unitsSold || 0) + Number(incoming.unitsSold || 0);
    current.revenue = toNumber(previousRevenue + Number(incoming.revenue || 0));
    current.customerCount = Number(current.customerCount || 0) + 1;
    current.growthRate = previousRevenue === 0 ? 100 : toNumber(((current.revenue - previousRevenue) / Math.max(previousRevenue, 1)) * 100);
    current.peakDays = mergePeakValues(current.peakDays, invoiceMeta.dayLabel);
    current.peakHours = mergePeakValues(current.peakHours, invoiceMeta.hourLabel);

    merged[productId] = current;
  });
  return merged;
}

function mergePeakValues(existing = [], value) {
  if (!value) {
    return existing ?? [];
  }
  const next = new Set(existing ?? []);
  next.add(value);
  return Array.from(next).slice(0, 5);
}

async function recomputeBrandStats(brandId) {
  const snapshot = await db.collection(PERFORMANCE_COLLECTION).where('brandId', '==', brandId).get();
  if (snapshot.empty) {
    return;
  }

  let totalRevenue = 0;
  snapshot.forEach((doc) => {
    totalRevenue += Number(doc.data()?.totalSales || 0);
  });
  const average = snapshot.size > 0 ? totalRevenue / snapshot.size : 0;

  const batch = db.batch();
  snapshot.forEach((doc) => {
    const data = doc.data() ?? {};
    const sales = Number(data.totalSales || 0);
    const share = totalRevenue > 0 ? (sales / totalRevenue) * 100 : 0;
    batch.update(doc.ref, {
      marketShare: toNumber(share),
      brandAverage: toNumber(average),
      difference: toNumber(sales - average),
    });
  });

  await batch.commit();
}

function deriveIssues(totalSales, growthRate) {
  const issues = [];
  if (totalSales < 500) {
    issues.push('المبيعات أقل من 500 د.ل وتتطلب تنشيطاً.');
  }
  if (growthRate < -10) {
    issues.push('معدل النمو سلبي خلال آخر دورة مبيعات.');
  }
  return issues;
}

function mergeUnique(existing = [], additions = []) {
  const result = new Set([...(existing ?? []), ...(additions ?? [])].filter(Boolean));
  return Array.from(result);
}

function selectRating(totalSales, growthRate) {
  if (totalSales >= 10000 || growthRate >= 20) return 'excellent';
  if (totalSales >= 5000 || growthRate >= 5) return 'good';
  if (totalSales <= 800 && growthRate <= -15) return 'critical';
  if (totalSales <= 1500) return 'poor';
  return 'average';
}

function resolveLocation(rawLocation) {
  if (!rawLocation) {
    return null;
  }
  if (rawLocation instanceof GeoPoint) {
    return rawLocation;
  }
  const lat = typeof rawLocation.lat === 'number' ? rawLocation.lat : rawLocation.latitude;
  const lng = typeof rawLocation.lng === 'number' ? rawLocation.lng : rawLocation.longitude;
  if (typeof lat === 'number' && typeof lng === 'number') {
    return new GeoPoint(lat, lng);
  }
  return null;
}

function toNumber(value) {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Number(value.toFixed(2));
}
