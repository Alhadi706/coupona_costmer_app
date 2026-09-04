# تقرير Discovery وArchitecture لنظام الهدايا والجوائز والعروض

تاريخ التنفيذ: 2026-09-03

## 1. نتيجة الاكتشاف

المشروع يحتوي على أساس قابل لإعادة الاستخدام، لذلك لا يجب بناء نظام مواز. أهم الأجزاء الموجودة:

- العملاء والحسابات: `users`, `customer_profiles`, `point_accounts`.
- التجار والعلامات: `merchant_profiles`, `brand_profiles`, مع `point_value` لسياسة قيمة النقطة.
- الفروع والكاشير: `branches`, `cashier_profiles`, `branch_manager_permissions`.
- النقاط والسجل: `point_accounts`, `ledger_entries`, بالإضافة إلى ledgers متخصصة للتاجر/العلامة والائتلاف.
- المنتجات: `product_registry` و `invoice_line_items` و `brand_matches` لربط مشتريات العميل بالعلامات.
- الجوائز الحالية: `rewards`, `reward_claims`, ومسارات `/api/rewards`, `/api/reward-claims/create`, `/api/cashier/redeem-claim`.
- هدايا الائتلاف الحالية: `coalition_gift_catalog`, `coalition_gift_triggers`, ومسارات داخل `backend/src/routes/coalition.js`.
- العروض الحالية: `offers`, `offer_targeting_rules`, ومسارات offer billboard/targeting.
- الإشعارات: `notifications`, `user_push_tokens`, ومساعدات إرسال FCM موجودة.
- الصلاحيات: auth middleware و `canRedeemClaim` تتحقق من صلاحية الكاشير/التاجر/الائتلاف.

## 2. الفجوات الرئيسية مقابل المواصفة

- مسار الجائزة المادية كان يخصم النقاط ويزيد المخزون عند إنشاء claim، وهذا يخالف القاعدة: VIEW != CLAIM != REDEMPTION.
- لا يوجد حتى الآن فصل كامل لكيانات Gift Campaign وGift Assignment وGift Redemption خارج هدايا الائتلاف الحالية.
- Offers موجودة، لكن لا تزال تحتاج دورة campaign/use/conversion analytics أكثر وضوحًا.
- الإشعارات غير مربوطة بالكامل بأحداث reward/gift/offer.
- audit timeline موحد لكل عملية غير مكتمل ككيان مستقل.
- واجهات التاجر/العميل/الكاشير موجودة جزئيًا، لكنها لا تغطي wizard الكامل للجوائز والهدايا والعروض.

## 3. قرار معماري

يتم اعتماد ثلاثة engines منفصلة في المنطق التجاري، لكنها تشترك في الكيانات الأساسية:

- Rewards Engine: `rewards` -> `reward_claims` -> cashier verification -> `ledger_entries` -> fulfillment/settlement.
- Gifts Engine: gift definition/campaign/segment/assignment/claim/redemption، ويفضل أن يمتد من نظام campaigns الموجود بدل نسخه.
- Offers Engine: `offers` + targeting + usage/conversion analytics.

المبدأ الحاكم: أي قرار يمس الرصيد، الأهلية، QR، المخزون، صلاحية الكاشير، أو عضوية الائتلاف يجب أن يحسمه backend/database داخل transaction.

## 4. ما نُفذ في هذه المرحلة

تم تنفيذ أول شريحة backend لجذر المشكلة في Rewards Engine:

- إنشاء claim لجائزة مادية لم يعد يخصم النقاط.
- إنشاء claim لجائزة مادية لم يعد يزيد `quantity_redeemed`.
- تأكيد الكاشير للجائزة المادية ينفذ داخل transaction واحدة:
  - قفل حساب نقاط العميل.
  - التحقق من الرصيد وقت الاستلام.
  - تحديث مخزون الجائزة بشرط التوفر وعدم الانتهاء.
  - خصم النقاط من `point_accounts`.
  - تسجيل ledger موحد بنوع `rewardRedeemed` وقيمة نقاط سالبة.
  - تحديث claim إلى `redeemed` وتسجيل `redeemed_at`, `redeemed_by`, `points_deducted_at`.
  - متابعة escrow/settlement وledger الائتلاف/merchant wallet الموجودة.
- claims القديمة التي خُصمت قبل هذا التعديل ما زالت تُرد عند انتهاء صلاحيتها.
- claims الجديدة غير المخصومة تنتهي بحالة `expired` بدون إضافة نقاط أو ledger refund وهمي.

## 5. حدود المعاملة الحالية

مسار `/api/cashier/redeem-claim` أصبح boundary الأساسي للجائزة المادية:

1. `reward_claims` locked by QR.
2. authorization via `canRedeemClaim`.
3. customer `point_accounts` locked.
4. reward inventory updated conditionally.
5. points ledger inserted.
6. claim status updated.
7. settlement and coalition accounting continue in the same transaction.

هذا يمنع الخصم عند مجرد عرض QR، ويقلل race conditions على آخر كمية متاحة.

## 6. خطة التنفيذ التالية

Phase 2 - Gifts Engine backend:

- إضافة `gift_definitions`, `gift_campaigns`, `gift_segments`, `gift_assignments`, `gift_claims`, `gift_redemptions`, `gift_contributors` أو ربطها بكيانات campaigns الموجودة حيث ينطبق.
- QR/token مخصص للهدية بدون خصم نقاط.
- حالات gift campaign وassignment كما في المواصفة.

Phase 3 - Notifications + Audit:

- ربط أحداث reward claimed/redeemed/expired وgift assigned/redeemed وoffer available بالـ notifications الموجود.
- إضافة timeline/audit موحد أو توسيع audit logs القائمة إن وجدت في المسار النهائي.

Phase 4 - Merchant UI:

- Wizard إدارة الجوائز.
- Wizard حملات الهدايا.
- إدارة العروض والاستهداف.
- صفحات analytics مختصرة لكل engine.

Phase 5 - Customer UI:

- شاشة موحدة "الهدايا والجوائز" بثلاثة أقسام: جوائز، هدايا، عروض.
- فلاتر points/status/category/source.
- تفاصيل وQR وحالة redemption/history.

Phase 6 - Cashier UI:

- توحيد scanner للجائزة والهدية.
- شاشة تحقق تعرض نوع الاستحقاق، العميل، المصدر، شروط الاستلام، وأخطاء backend.

Phase 7 - Tests:

- تغطية الحالات المذكورة في المواصفة، خصوصًا double redemption, expired QR, insufficient points at redemption, unauthorized cashier, coalition member validation, last inventory race, reversal.

## 7. التحقق المنجز

- `node --check backend/src/routes/exchange-rewards.js`
- `node --check backend/src/schema-extra.js`
- `node --check backend/src/reward-claim-service.js`
- `node --test backend/reward_claim_transaction_test.js backend/reward_claim_service_test.js`
- `flutter test test/reward_transaction_reference_test.dart`
