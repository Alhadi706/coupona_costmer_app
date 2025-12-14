# Store Performance & Geo Analytics

## Vision
Build a professional-grade analytics layer that empowers brands to monitor store-level KPIs, visualize geographic distribution, and trigger intelligent interventions (recommendations, offers, action plans) per store.

## Modules Overview
| Module | Purpose | Key Files |
| --- | --- | --- |
| Models | Typed representation of performance data, recommendations, enums | `lib/models/store_performance.dart` |
| Repository | Firestore bridge (CRUD, streams) | `lib/services/analytics/store_performance_repository.dart` |
| Services | High-level orchestration + recommendation engine | `lib/services/analytics/store_analytics_service.dart`, `store_recommendation_engine.dart` |
| Screens | Dashboards, detail views, geographic map | `lib/screens/store_performance_analysis_screen.dart` |
| Reports | TBD: PDF/export generation via Cloud Functions | `/cloud_functions` (future) |

## Data Flow
1. **Ingestion**: The `cloud_functions/store_analytics` trigger (`aggregateBrandStorePerformance`) now listens to `invoices/{invoiceId}` and rolls every line item into `brand_store_performance/{brandId}_{storeId}`. It fans out across brands, updates totals/last sale timestamps, regenerates per-product stats, and recomputes brand-level market share after each write.
2. **Repository Layer**: `StorePerformanceRepository` exposes `watchBrandStores` + `fetchStore` for UI/services.
3. **Analytics Service**: `StoreAnalyticsService` refreshes recommendations, persists results, and acts as single entry point for UI.
4. **UI Layer**:
   - `StorePerformanceAnalysisScreen` shows filters, overview KPIs, table, mini map.
   - `StoreDetailAnalysisScreen` offers tabs (performance, products, history, recommendations).
   - `GeographicDistributionScreen` renders Google Map markers, overlays, quick stats.
5. **Action Layer** (future): Recommendation cards drive offer creation, notifications, and report exports.

## Firestore Collections
- `brand_store_performance/{brandId}_{storeId}`
  - Aggregated KPIs, product sub-map, rating, comparison values, issues, recommendations.
- `store_analytics_daily/{storeId}_{date}`
  - Daily totals, top products, customer count to support trend charts.
- `geographic_distribution/{regionId}`
  - Precomputed region stats for heatmaps + density analysis.
- `store_recommendations/{storeId}`
  - Audit trail of generated recommendations + action plans.

### Security snapshot
Firestore rules now expose the collection behind a strict gate:

```text
match /brand_store_performance/{docId} {
  allow read: if signedIn() && (data.brandId == uid() || data.storeId == uid() || isAdmin());
  allow create, update, delete: if isAdmin();
}
```

Brand accounts (uid == brandId) can stream their portfolio, merchants (uid == storeId) can only see their own entry, and only privileged service accounts/Admin SDK jobs are allowed to write.

## Feature Roadmap
| Sprint | Focus | Deliverables |
| --- | --- | --- |
| 1-2 | Data models & ingestion | Cloud Function aggregators, Firestore security, tests |
| 3-4 | Core dashboards | Store list, filters, KPI widgets wired to live data |
| 5-6 | Geographic system | Google Maps overlays, density cards, filters |
| 7-8 | Recommendation engine | Rule-based + ML hooks, action plan templates |
| 9-10 | Reports & exports | PDF generator, CSV exports, scheduled emails |
| 11-12 | QA & optimization | Performance tuning, caching, UX polish |

## Technical Notes
- **Packages**: `google_maps_flutter`, consider `fl_chart`, `data_table_2`, `pdf`, `firebase_cloud_functions`.
- **State Management**: Current scaffolding is vanilla `StatefulWidget`; integrate Provider/Riverpod later for production.
- **Testing**: Add unit tests for recommendation logic + repository + UI golden tests.
- **Security**: Firestore rules must ensure brands only access their stores; geo queries must honor indexes.

## Next Steps
1. Deploy `aggregateBrandStorePerformance` (see below) so the Flutter stream serves live data.
2. Expand `StoreRecommendationEngine` rules + connect to scheduled Cloud Function.
3. Implement export layer (PDF/CSV) + share flow with admin portal.
4. Finalize Google Maps interactions (heatmap overlays, clustering) once datasets available.

## Deployment & Testing Checklist
1. **Install & deploy the Cloud Function**
  ```bash
  cd cloud_functions/store_analytics
  npm install
  firebase deploy --only functions:aggregateBrandStorePerformance
  ```
2. **Seed reference data**
  - Create/verify `merchants/{merchantId}` docs with `name` and `location`.
  - Ensure `products/{productId}` that belong to a merchant include `brandId`.
  - Insert or scan at least one `invoices/{invoiceId}` document per store. Each line item should include `productId`, `quantity`, and `price` (or at minimum a `productName` that matches a product in the merchant catalog).
3. **Verify output**
  - Watch the `brand_store_performance` collection (emulator UI or Firestore console). Documents are keyed as `{brandId}_{merchantId}`.
  - Open the brand dashboard → Analytics tab → “تحليل أداء المحلات” to confirm the UI reflects the live snapshots instead of mock data.
4. **Troubleshooting tips**
  - Missing `brandId` on products ⇒ invoice is ignored for that brand.
  - Missing `location` on merchants ⇒ fallback coordinates (Tripoli) are used until the profile is updated.
  - If growth/market-share look stale, run `firebase functions:log` to ensure the trigger executed after the latest invoice.
