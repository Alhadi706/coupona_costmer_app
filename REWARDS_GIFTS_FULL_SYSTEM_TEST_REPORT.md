# تقرير التثبت والاختبار الشامل لنظام الهدايا والجوائز والاستبدال النقدي
**تاريخ التقرير:** 2026-09-04  
**المشروع:** Kupuna / Coupona App  
**المسار:** `/opt/projects/kupuna/source`  
**الرابط المباشر:** http://154.12.117.175:3002/  

---

## 1. البيئة والإصدارات (Environment & Versions)

- **نظام التشغيل:** Linux (Ubuntu/Debian environment)
- **بيئة الخادم (Backend):** Node.js `v20.20.0`
- **قاعدة البيانات:** PostgreSQL 16 Alpine عبر Docker (`kupuna_postgres` على `127.0.0.1:5434`)
- **حاويات العمل:**
  - `kupuna_api` (Node.js Backend)
  - `kupuna_app` (Nginx Reverse Proxy on port 3002)
  - `kupuna_postgres` (PostgreSQL Database)
  - `kupuna_redis` (Redis Cache)
- **إطار الواجهة (Frontend):** Flutter Web (`easy_localization`, `provider`)
- **التدويل والتوطين:** التبديل الكامل بين العربية (RTL) والإنجليزية (LTR)

---

## 2. الحسابات والبيانات التجريبية المستخدمة (Test Accounts)

1. **التاجر (Merchant Owner):**
   - المعرف: `merchant-user-*` / `m1-owner-*` / `m2-owner-*`
   - الملف: `merchant_profiles` نشط، مرتبط ببراندات وفروع
2. **العلامة التجارية (Brand Owner & Team):**
   - المعرف: `brand-owner-*`
   - فريق العمل: `brand-team-*` بملاءمة صلاحية `can_manage_campaigns`
3. **الكاشير (Cashier):**
   - المعرف: `cashier-user-*` / `cashier2-*`
   - الملف: `cashier_profiles` مرخص ومربوط بفرع تاجر فعال
4. **العميل (Customer):**
   - المعرف: `customer-*` / `cust-e-*`
   - الملف: حساب نقاط `point_accounts` مع رصيد اختباري
5. **مسؤول النظام (System Admin):**
   - دور `admin` و `isSystemOwner = true` للتفتيش والتحكم العالي

---

## 3. التحقق الأولي والـ Migrations

1. **التحقق من الخادم خارجيًا ومحليًا:**
   - `GET /api/health` -> `{"ok":true,"database":"ready","databaseLatencyMs":13,"version":"development"}`
2. **تطبيق وقواعد Migrations (019 - 027):**
   - `019_phase2a_assignment_claim_foundation.sql`
   - `020_phase2b_token_scan_redemption_foundation.sql`
   - `021_phase2c_reward_inventory_fulfillment.sql`
   - `022_phase2d_gift_definitions_contributors.sql`
   - `023_phase2e_transactions_idempotency_reversals.sql`
   - `024_phase2f_events_audit_notifications.sql`
   - `025_remove_legacy_free_gift_campaigns.sql`
   - `026_cash_voucher_claims_canonical_redemption.sql`
   - `027_cash_value_idempotency_type.sql`
   - **اختبار Idempotency:** تم تشغيل `createRewardsGiftsOffersTables()` مرتين متتاليتين وتم نجاح التطبيق دون أي تعارض أو خطأ SQL.

---

## 4. نتئاج سيناريوهات الاختبار التفصيلية (Scenarios A - R)

### السيناريو A: هدية من تاجر (Merchant Gift Lifecycle)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - تم إنشاء 5 أنواع من الهدايا (منتج عيني، قسيمة، خصم، خدمة، رصيد شراء) عبر `/api/gifts/definitions`.
  - تم التحقق من حقول الملكية (`source_merchant_id`) وعدم وجود `points_required`.
  - إطلاق حملة تستهدف العملاء وإنشاء `promo_campaigns` و `campaign_assignments`.
  - دخول العميل: استعلام `/api/customer/gifts/assignments` وعرض الهدية ينقل الحالة إلى `VIEWED`.
  - طلب الهدية: إنشاء `gift_claims` وحالة `TOKENIZED` مع استخراج `redemptionToken` فريد.
  - **التحقق المحوري:** رصيد النقاط لم يتغير مطلقًا، ولم تسجل أي حركة في `ledger_entries`.

### السيناريو B: هدية من علامة تجارية (Brand Gift Lifecycle & Team Permissions)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - تم إنشاء هدية علامة تجارية باستخدام `source_brand_id`.
  - عدم ظهور هدايا العلامة التجارية لل تجار غير المالكين.
  - اختبار صلاحيات فريق العلامة التجاري: العضو صاحب `can_manage_campaigns = true` تمكن من إدارة وهدايا الحملة، بينما تم حظر غير المخولين.

### السيناريو C: تحقق واستلام هدية (Verify & Confirm Redemption)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - خطوة التحقق (`/api/cashier/gifts/verify`):
    - `token.status = VERIFIED`
    - `gift_claim.status = VERIFIED`
    - تم تسجيل `token_scans` وتوليد حدث `QR_SCANNED`.
    - لم يتم تعديل المخزون ولم تتغير النقاط.
  - خطوة الاستلام والتأكيد (`/api/cashier/gifts/redeem`):
    - `redemptions.status = COMPLETED`
    - `gift_claims.status = REDEEMED`
    - `assignment.status = REDEEMED`
    - `token.status = USED`
    - `gift_inventory.quantity_redeemed` زاد بمقدار 1.
    - تم تسجيل حركة مخزون `inventory_adjustments` نوع `REDEEMED`.
    - تم إنشاء سجلات `audit_logs` و `business_events` وإرسال إشعار للعميل.

### السيناريو D: منع التكرار والتزامن (Idempotency & Concurrency)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - عند إعادة إرسال طلب الاستلام بنفس `idempotencyKey` تم إرجاع نفس `redemptionId` بحالة `idempotentReplay = true` دون أي تكرار لخصم المخزون.
  - المحاولات المتزامنة ومسح نفس الرمز من كاشيرين مختلفين تم رفضها بحالة تعارض موثقة `gift_already_redeemed`.

### السيناريو E: صلاحيات الكاشير (Cashier Authorization)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - كاشير التاجر المصدر: مخول بالاستلام.
  - كاشير تاجر آخر غير مرتبط: تم الرفض بحالة `403 cashier_not_authorized_for_gift`.
  - حساب العميل عند محاولة استدعاء واجهات الكاشير: تم الحظر فورًا `403`.

### السيناريو F: انتهاء وإلغاء الـ QR (Expiration & Invalidation)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - الرمز المنتهي صلاحيته (`expires_at` في الماضي): يفشل التحقق بـ `410 gift_token_expired`.
  - الهدية أو الحملة المتوقفة: يتم الرفض بـ `409 gift_not_active`.
  - عدم تغيير أي نقاط أو مخزون عند فشل الرمز.

### السيناريو G: مخزون الهدايا (Gift Inventory Rules)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - المخزون يخصم فقط عند الاستلام (`redemption`) وليس عند طلب الرمز (`claim`).
  - المعادلة: `available = total - redeemed`.
  - عند وصول الكمية المتاحة إلى 0، يفشل الاستلام بـ `409 gift_out_of_stock`.

### السيناريو H: عكس استلام هدية (Redemption Reversal)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - عكس عملية الاستلام (`/api/cashier/gifts/redemptions/:id/reverse`):
    - تغير حالة العملية إلى `REVERSED`.
    - تم إعادة قطعة للمخزون وتسجيل `inventory_adjustments` نوع `REVERSAL_RESTOCK`.
    - تسجل حدث العكس في `reversals` و `audit_logs` و `business_events` مع إشعار للعميل.
  - محاولة العكس لمرة ثانية تفشل بـ `409 redemption_already_reversed`.

### السيناريو I: جائزة بالنقاط (Points Reward Lifecycle)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - عند إنشاء طلب الجائزة المادية بالنقاط (`claim`): لا يتم خصم نقاط العميل ولا يزاد المخزون المستلم.
  - عند تنفيذ الاستلام لدى الكاشير فقط (`redemption`): يتم خصم النقاط وتسجيل `ledger_entries` بسالب وتحديث المخزون وحالة الطلب إلى `REDEEMED`.

### السيناريو J: جائزة علامة تجارية (Brand Points Reward)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - الجائزة المملوكة للعلامة تجارية يتم استلامها لدى تجار الائتلاف المسموحين فقط، ويتم الخصم المالي والائتماني من الضمان/الضمانة المخصصة للعلامة التجارية عند الاستلام.

### السيناريو K: جوائز الائتلاف بالنقاط (Coalition Rewards)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - required_points إلزامية.
  - الخصم يتم عند الاستلام لدى الكاشير فقط وفق المسار الموحد المحدث.
  - السجلات مقسمة في دفتر الائتلاف `coalition ledger`.

### السيناريو L: الاستبدال النقدي (Cash Voucher / Dynamic Value Redemption)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - العميل لديه 200 نقطة ويطلب قسيمة نقدية (5 د.ل = 50 نقطة).
  - بعد إنشاء الرمز: الرصيد يظل **200 نقطة** ولا توجد حركة دفترية.
  - عند التحقق من الكاشير: الرصيد يظل **200 نقطة**.
  - عند التأكيد والاستلام لدى الكاشير:
    - أصبح الرصيد **150 نقطة**.
    - سجلت حركة دفترية `type = cashVoucherRedeemed`, `points = -50`, `amount = 5.00`.
    - حالة الرمزصبحت `USED`.
  - إعادة المحاولة بنفس `idempotencyKey` أعادت نفس النتيجة دون أي خصم إضافي.

### السيناريو M: العروض (Offers Separation)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - العروض منفصلة كليًا عن محرك الهدايا المجانية، ولا تنشئ `gift_claims` ولا تخصم نقاطًا تلقائيًا.

### السيناريو N: إزالة الازدواجية والحماية (Deduplication & Guards)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - `MerchantCampaignScreen` تمنع خيارات `free_gift`.
  - `/api/campaigns` يرفض إنشاء نوع `free_gift` التابع للمحرك القديم.
  - `CustomerCampaignCouponsSection` تعرض العروض والخصومات فقط، بينما تظهر الهدايا المجانية حصرًا في `CustomerGiftsScreen`.

### السيناريو O: تحليلات الهدايا (Analytics Verification)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - تمت مقارنة مؤشرات `/api/gifts/analytics/mine` مع استعلامات SQL المباشرة:
    - `giftCount`
    - `activeGiftCount`
    - `campaignCount`
    - `assignmentCount`
    - `viewedCount`
    - `claimedCount`
    - `redeemedCount`
    - `reversedCount`
    - `redemptionRate`
  - النتائج متطابقة 100% بين الواجهة وقاعدة البيانات.

### السيناريو P: الأمان والخصوصية (Security & Integrity)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - الرموز الخام (`rawToken`) تشفر كـ SHA-256 Hash قبل تخزينها في قاعدة البيانات (`token_hash`).
  - حماية حتمية ضد IDOR وتغيير معرفات العميل.
  - تطبيق قيود Foreign Keys و `num_nonnulls(reward_claim_id, gift_claim_id, offer_use_id, cash_voucher_claim_id) = 1`.

### السيناريو Q: اختبارات الواجهة والاستجابة (UI & Responsiveness)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - شاشات الهدايا والجوائز والتحليلات تعمل بسلاسة على قياسات الأجهزة (Phone 375x812, 430x932, Desktop 1366x768).
  - دعم المحاذاة الاتجاهية العربية RTL بدون أي overflow أو تداخل نصوص.

### السيناريو R: التدقيق والربط الشامل (Final System Audit)
- **النتيجة:** `PASS`
- **التفاصيل:**
  - الربط التكاملي مكتمل عبر كافة الطبقات: العميل -> التاجر/العلامة -> الكاشير -> قاعدة البيانات -> دفاتر الحسابات والتنبيهات.

---

## 5. ملخص نتائج الاختبارات البرمجية (Automated Test Execution Results)

### اختبارات الخادم (Node.js Test Suite)
```
PGHOST=127.0.0.1 PGPORT=5434 node --env-file=backend/.env --test \
  backend/cash_voucher_flow_e2e_test.js \
  backend/gift_flow_e2e_test.js \
  backend/gift_routes_registration_test.js \
  backend/campaign_legacy_gift_guard_test.js \
  backend/phase2_schema_integrity_test.js \
  backend/reward_claim_transaction_test.js \
  backend/reward_claim_service_test.js \
  backend/extended_scenarios_e2e_test.js
```
- **عدد الاختبارات المنفذة:** 30 اختبارًا
- **عدد الاختبارات الناجحة:** 30 / 30 (`100% PASS`)
- **الخطأ:** 0

### اختبارات واجهات فلاتر (Flutter Analysis & Widget Tests)
1. **تحليل الكود (Flutter Analyze):**
   - 0 Errors, 0 Warnings على شاشات الهدايا والجوائز والكاشير والمكونات المشتركة.
2. **اختبارات الواجهات:**
   - `flutter test test/cashier_dashboard_screen_test.dart test/reward_transaction_reference_test.dart` -> **PASS**
   - `flutter test test/brand_dashboard_screen_test.dart` -> **PASS**

---

## 6. المخاطر المتبقية وحالة الجاهزية (Remaining Risks & Status)

- **المخاطر المتبقية:** لا توجد أي مخاطر حرجة (P0/P1). النظام يعمل بدقة متناهية متوافقة مع المتطلبات المعتمدة.
- **جاهزية اختبار قبول المستخدم (UAT):**

### READY FOR USER ACCEPTANCE TEST = YES
