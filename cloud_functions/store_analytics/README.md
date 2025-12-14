# Store Analytics Cloud Function

Aggregates every invoice into the `brand_store_performance` collection so the Flutter dashboards can stream live KPIs instead of mock data.

## What the function does
- Listens to `invoices/{invoiceId}` document creations.
- Fetches related `merchants/{merchantId}` and `products/{productId}` documents.
- Groups all line items by `brandId` and updates `brand_store_performance/{brandId}_{merchantId}` with:
  - Total sales, transactions, store average, growth rate, latest sale timestamp.
  - Per-product units, revenue, growth snapshots, and light seasonality hints.
  - Auto-generated issues (e.g., low sales or negative growth) ready for the recommendation engine.
- Recomputes brand-level market share and averages after each write.

## Local development
1. `cd cloud_functions/store_analytics`
2. `npm install`
3. Run the Firebase emulator suite: `firebase emulators:start --only functions,firestore`
4. Create sample invoices (e.g., via the Flutter app or a script) and watch `brand_store_performance` populate in the emulator UI.

## Deployment
The function targets `us-central1` with 512 MB RAM by default. Deploy with Firebase CLI (preferred):

```bash
cd cloud_functions/store_analytics
npm install
firebase deploy --only functions:aggregateBrandStorePerformance
```

If you use `gcloud`, map the trigger to Firestore document creation events:

```bash
gcloud functions deploy aggregateBrandStorePerformance \
  --gen2 --runtime=nodejs20 --region=us-central1 \
  --source=. --entry-point=aggregateBrandStorePerformance \
  --trigger-event-filters="type=google.cloud.firestore.document.v1.created" \
  --trigger-event-filters="document=projects/${PROJECT_ID}/databases/(default)/documents/invoices/{invoiceId}"
```

## Firestore expectations
- `merchants/{merchantId}` should contain `name` and an optional `location` (`GeoPoint` or `{lat,lng}` object).
- `products/{productId}` need a `brandId` so invoices can be attributed to brands.
- Each invoice item should include `productId`, `price`, and `quantity` for accurate revenue math.
- The UI already consumes `brand_store_performance` via `StorePerformanceRepository`, so no Flutter changes are required once data exists.
