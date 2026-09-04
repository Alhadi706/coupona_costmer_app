# خطة تنفيذ Phase 2 لنظام الهدايا والجوائز والعروض

تاريخ البدء: 2026-09-03

## قاعدة التنفيذ

لا يتم بناء Gift APIs أو واجهات التاجر/العميل/الكاشير قبل تثبيت نموذج البيانات التالي:

1. Assignment وClaim.
2. Token وScan وRedemption.
3. Inventory وFulfillment relational model.
4. Gift Definitions وContributors.
5. Transaction/RPC/Idempotency boundaries.
6. Business Events وAudit وNotifications.
7. Tests وConcurrency tests.

## PHASE 2A - Core Assignment + Claim Foundation

الحالة: DONE

الهدف:

- إنشاء `campaign_assignments` ككيان entitlement عام للحملات.
- إنشاء `gift_claims` ككيان منفصل عن assignment وعن redemption.
- تمديد `promo_campaigns` بمراجع source حقيقية تدريجيًا، بدون كسر الأعمدة القديمة `source_type/source_id`.

المخرجات:

- Migration: `backend/migrations/019_phase2a_assignment_claim_foundation.sql`.
- جداول: `campaign_assignments`, `gift_claims`.
- Indexes وpartial unique constraints لمنع duplicate active assignments وduplicate active gift claims.

ملاحظة مهمة:

- `gift_claims.gift_definition_id` لا يضاف في هذه المرحلة لأن `gift_definitions` مقصود إنشاؤه في PHASE 2D. سيتم ربط claim بالهدية عبر `campaign_assignments -> promo_campaigns -> gift_definition_id` بعد 2D.

بوابة التحقق:

- تطبيق migration على قاعدة التطوير بنجاح.
- التأكد من idempotency بإعادة تشغيل migration دون فشل.
- فحص constraints الأساسية عبر استعلامات catalog أو اختبارات Node لاحقة.

التحقق المنجز:

- `backend/migrations/019_phase2a_assignment_claim_foundation.sql` applied successfully.
- Re-applying migration is idempotent.

## PHASE 2B - Token + Scan + Redemption Foundation

الحالة: DONE

الهدف:

- إنشاء `redemption_tokens`.
- إنشاء `token_scans`.
- إنشاء `redemptions`.
- فرض exactly-one-parent بين `reward_claims`, `gift_claims`, `offer_uses` بعد إنشاء `offer_uses`.

المخرجات:

- Migration مستقلة.
- Unique active token per parent/purpose.
- Unique completed redemption per parent.

التحقق المنجز:

- `backend/migrations/020_phase2b_token_scan_redemption_foundation.sql` applied successfully.
- Re-applying migration is idempotent.

## PHASE 2C - Inventory + Fulfillment

الحالة: DONE

الهدف:

- إنشاء relational inventory وfulfillment locations للجوائز.
- إنشاء foundation لاستلام الائتلافات.
- منع JSON لعلاقات الفروع والائتلافات.

المخرجات:

- `reward_inventory`.
- `reward_fulfillment_locations`.
- `coalition_fulfillment_members`.
- Constraints تمنع الكميات السالبة وتدعم conditional update عند آخر وحدة.

ملاحظة اعتماد:

- `gift_inventory` و`gift_fulfillment_locations` ينشآن في PHASE 2D بعد إنشاء `gift_definitions` حتى تكون FK حقيقية وليست علاقة مؤجلة أو JSON.

التحقق المنجز:

- `backend/migrations/021_phase2c_reward_inventory_fulfillment.sql` applied successfully.
- Re-applying migration is idempotent.

## PHASE 2D - Gift Definitions + Contributors

الحالة: DONE

الهدف:

- إنشاء `gift_definitions` و`gift_contributors`.
- إنشاء `gift_inventory` و`gift_fulfillment_locations` بعد توفر FK إلى `gift_definitions`.
- تمديد `promo_campaigns` بربط FK إلى `gift_definitions`.
- تمديد `gift_claims` بربط FK نهائي إلى `gift_definitions` إن لزم.

المخرجات:

- Gift Definition مستقل عن Reward وOffer.
- Contributors للتاجر/العلامة/الائتلاف بعلاقات FK حقيقية.

التحقق المنجز:

- `backend/migrations/022_phase2d_gift_definitions_contributors.sql` applied successfully.
- Re-applying migration is idempotent.

## PHASE 2E - Transactions / RPC / Idempotency

الحالة: DONE

الهدف:

- تثبيت حدود المعاملات للجائزة والهدية والعرض.
- إضافة request idempotency/invariants المطلوبة للـ double click وHTTP retry وconcurrent redemption.

المخرجات:

- DB functions أو service-level transaction boundaries موحدة.
- Constraints نهائية على redemption/reversal/token.

التحقق المنجز:

- `backend/migrations/023_phase2e_transactions_idempotency_reversals.sql` applied successfully.
- Re-applying migration is idempotent.

## PHASE 2F - Events + Audit + Notifications

الحالة: DONE

الهدف:

- إنشاء `business_events` و`audit_logs`.
- ربط notifications كـ consumer وليس event store.

المخرجات:

- أحداث domain عامة.
- Audit generic لكل status/action حساس.

التحقق المنجز:

- `backend/migrations/024_phase2f_events_audit_notifications.sql` applied successfully.
- Re-applying migration is idempotent.

## PHASE 2G - Tests + Concurrency Tests

الحالة: DONE

الهدف:

- اختبار الحالات الطبيعية والحافة قبل أي UI.

المخرجات:

- Node tests للـ migrations والـ transaction invariants.
- اختبارات double redemption/concurrent redemption/reversal/idempotency.

التحقق المنجز:

- `node --test backend/phase2_schema_integrity_test.js` passed: 5/5.

## بعد Phase 2G

بعد تثبيت النموذج والاختبارات فقط يبدأ تنفيذ:

- Gift APIs.
- Merchant UI.
- Customer UI.
- Cashier UI.

## Gift APIs Foundation

الحالة: DONE - backend foundation

ما تم:

- إضافة route مستقل `backend/src/routes/gifts.js`.
- ربطه في `backend/server.js`.
- endpoints مبدئية لتعريف الهدايا، إطلاق حملة هدايا، عرض assignments للعميل، view/claim، verify/redeem للكاشير.
- مسار redemption للهدايا لا يخصم أي نقاط ولا يكتب points ledger.
- verification منفصل عن redemption: QR scan لا يعني الاستلام.
- إضافة idempotent replay لمسار redeem بنفس `idempotencyKey`.
- ربط `gift_inventory` عند redemption فقط، بدون حجز في claim.
- إضافة reversal للهدايا بدون points refund، مع restock عند وجود مخزون مرتبط.
- إضافة methods في `CompanyServerService` لكل Gift APIs الجديدة.

التحقق المنجز:

- `node --check backend/src/routes/gifts.js backend/server.js backend/src/schema-rewards-gifts-offers.js`.
- `node --test backend/gift_routes_registration_test.js backend/gift_flow_e2e_test.js backend/phase2_schema_integrity_test.js` passed: 8/8.
- `flutter analyze lib/services/company_server_service.dart` passed with no issues.

المتبقي قبل واجهات المستخدم:

- بناء واجهة التاجر لتعريف الهدايا وإطلاق الحملات.
- بناء واجهة العميل لعرض assignments وclaim/QR.
- بناء واجهة الكاشير للتحقق والاستلام وعكس الاستلام عند الحاجة.

## Gift UI Foundation

الحالة: DONE - initial merchant/brand/customer/cashier UI

ما تم:

- شاشة مشتركة `GiftManagementScreen` للتاجر والعلامة التجارية.
- ربط شاشة الهدايا من لوحة التاجر.
- ربط شاشة الهدايا من لوحة العلامة التجارية.
- شاشة `CustomerGiftsScreen` لعرض الهدايا المرسلة للعميل، تسجيل view، claim، وإظهار QR.
- ربط شاشة هدايا العميل من شاشة الجوائز/المحفظة.
- قسم في شاشة الكاشير للتحقق من QR الهدية ثم تأكيد التسليم، مع فصل verification عن redemption.
- طبقة `CompanyServerService` أصبحت تغطي كل Gift API calls اللازمة لهذه الواجهات.

التحقق المنجز:

- `flutter analyze lib/screens/gift_management_screen.dart lib/screens/customer_gifts_screen.dart lib/screens/cashier_dashboard_screen.dart lib/screens/my_rewards_screen.dart lib/screens/merchant_dashboard_screen.dart lib/screens/brand_dashboard_screen.dart lib/services/company_server_service.dart` passed with no new errors. بقيت تحذيرات قديمة في `brand_dashboard_screen.dart`.
- `flutter test test/cashier_dashboard_screen_test.dart test/brand_dashboard_screen_test.dart` passed.
- Backend focused tests still pass: `node --test backend/gift_flow_e2e_test.js backend/gift_routes_registration_test.js backend/phase2_schema_integrity_test.js`.

المتبقي:

- تحسين النصوص عبر مفاتيح localization بدل بعض النصوص العربية المباشرة.
- إضافة شاشة reversal history/تفاصيل الاسترداد بدل الاكتفاء باستدعاء endpoint من الكاشير عند الحاجة.

## Legacy Gift Cleanup

الحالة: DONE

ما تم:

- إزالة خيار إنشاء الهدايا من شاشة الحملات القديمة `MerchantCampaignScreen`.
- منع `/api/campaigns` من إنشاء `free_gift` مباشرة.
- منع `/api/campaigns/:id/launch` من إطلاق حملات هدايا مرتبطة بالنظام الجديد عبر المسار القديم.
- تصفية كوبونات `free_gift` القديمة من مكوّن كوبونات العميل.
- فصل نصوص الكاشير: الكوبونات الترويجية للخصم/السحب فقط، والهدايا المجانية في قسم مستقل.
- إعادة تسمية عرض الائتلاف في المحفظة إلى جوائز الائتلاف بالنقاط بدل هدايا.
- إضافة migration `025_remove_legacy_free_gift_campaigns.sql` لحذف حملات free_gift القديمة غير المرتبطة بـ `gift_definitions`.

التحقق المنجز:

- migration 025 applied على قاعدة التطوير: حذف 20 حملة قديمة و20 كوبون legacy، وإعادة التطبيق idempotent.
- `node --test backend/campaign_legacy_gift_guard_test.js backend/gift_flow_e2e_test.js backend/gift_routes_registration_test.js backend/phase2_schema_integrity_test.js` passed: 10/10.
- `flutter analyze` على ملفات الحملات/الكاشير/المحفظة/الخدمة passed دون أخطاء.
- `flutter test test/cashier_dashboard_screen_test.dart test/brand_dashboard_screen_test.dart` passed.

## Gift Analytics Foundation

الحالة: DONE

ما تم:

- إضافة endpoint `GET /api/gifts/analytics/mine` للتاجر/العلامة.
- عرض مؤشرات مختصرة في `GiftManagementScreen`: عدد الهدايا، الحملات، المستلمين، ونسبة الاستلام.
- تغطية التحليلات داخل اختبار E2E للهدايا.

التحقق المنجز:

- `node --test backend/gift_flow_e2e_test.js backend/gift_routes_registration_test.js backend/campaign_legacy_gift_guard_test.js backend/phase2_schema_integrity_test.js` passed: 10/10.
- `flutter analyze lib/screens/gift_management_screen.dart lib/services/company_server_service.dart` passed.

## Cash Value Redemption Foundation

الحالة: DONE

ما تم:

- الحفاظ على ميزة الاستبدال النقدي للعميل، لكن تحويلها إلى دورة آمنة: claim/token ثم verify ثم redeem.
- إنشاء `cash_voucher_claims` وربطها بـ `redemption_tokens` و`redemptions` ضمن النوع `CASH_VALUE`.
- إنشاء migration `026_cash_voucher_claims_canonical_redemption.sql`.
- إنشاء migration `027_cash_value_idempotency_type.sql` لفصل idempotency الخاص بالقيمة النقدية عن الجوائز.
- تعديل `/api/customer/redemptions/dynamic-voucher` حتى لا يخصم النقاط عند إنشاء QR.
- إضافة `/api/cashier/dynamic-voucher/verify` و`/api/cashier/dynamic-voucher/redeem`.
- خصم النقاط وتسجيل `ledger_entries` يتمان فقط عند تأكيد الكاشير.
- إضافة قسم في شاشة الكاشير للتحقق من القسيمة النقدية وتأكيد استخدامها.
- تعديل نص قسيمة العميل ليوضح أن النقاط ستخصم عند تأكيد الكاشير، وليس عند إنشاء QR.

التحقق المنجز:

- migrations 026 و027 applied وأعيد تطبيقهما بنجاح.
- `node --test backend/cash_voucher_flow_e2e_test.js backend/gift_flow_e2e_test.js backend/gift_routes_registration_test.js backend/campaign_legacy_gift_guard_test.js backend/phase2_schema_integrity_test.js` passed: 11/11.
- `flutter analyze lib/screens/cashier_dashboard_screen.dart lib/screens/my_rewards_screen.dart lib/services/company_server_service.dart` passed.
- `flutter test test/cashier_dashboard_screen_test.dart` passed.
