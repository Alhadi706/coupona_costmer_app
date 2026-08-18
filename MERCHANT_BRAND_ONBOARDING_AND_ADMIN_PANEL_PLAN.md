# خطة: تحسين تسجيل التاجر/العلامة التجارية + بناء لوحة إدارة كوبونا الوظيفية

**الحالة:** مسودة معتمدة من المستخدم، بانتظار التنفيذ.
**السبب:** اكتُشفت هذه الفجوات أثناء اختبار يدوي فعلي من المستخدم على `localhost:5050` بتاريخ 2026-08-07،
وتم التحقق من كل بند أدناه مباشرة بقراءة الكود (لا افتراضات).

---

## الفجوة 1: نموذج طلب تفعيل دور التاجر/العلامة التجارية ناقص حقليًا

### الوضع الحالي (مؤكَّد بالكود)
`lib/screens/role_activation_request_screen.dart` يطلب فقط 3 حقول:
- اسم النشاط (`businessName`)
- السجل التجاري (`commercialRegistration`)
- نوع الخطة (`planType`: basic/pro)

`backend/server.js` جدولا `merchant_profiles` و`brand_profiles` (الأسطر 343-361) يحتويان فقط:
`id, user_id, business_name, commercial_registration, point_value, status, created_at`
— **لا يوجد أي عمود لرقم الهاتف/وسيلة تواصل، ولا لموقع النشاط الجغرافي (lat/lng/address).**

### المطلوب (الشكل الصحيح المتفق عليه)
عند طلب تفعيل دور تاجر أو علامة تجارية، يجب أن يمر المستخدم بثلاث خطوات إلزامية قبل الإرسال:
1. **بيانات النشاط:** اسم النشاط + السجل التجاري (موجود حاليًا).
2. **وسيلة التواصل:** رقم هاتف إلزامي (`phone`)، ويمكن إضافة بريد إلكتروني اختياري لاحقًا.
3. **موقع النشاط على الخريطة:** اختيار نقطة جغرافية إلزامية عبر `MapPickerScreen` الموجودة فعلًا
   في `lib/screens/map_picker_screen.dart` (يُعاد استخدامها كما هي، لا تُبنى من جديد) — تُخزَّن كـ
   `location_lat`, `location_lng`, وحقل نصي اختياري `location_address`.

فقط بعد إكمال الخطوات الثلاث يُفعَّل زر "إرسال الطلب"، ويُنشأ سجل بحالة `pending_admin_review` كما هو معمول به حاليًا.

### التغييرات المطلوبة تحديدًا

**Backend (`backend/server.js`):**
1. إضافة أعمدة جديدة عبر `ALTER TABLE IF NOT EXISTS` (بنفس نمط الأعمدة الأخرى في الملف):
   ```sql
   ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS phone TEXT;
   ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION;
   ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION;
   ALTER TABLE merchant_profiles ADD COLUMN IF NOT EXISTS location_address TEXT;
   -- نفس الأربعة أعمدة لـ brand_profiles
   ```
2. تعديل `POST /api/roles/merchant/request` و`POST /api/roles/brand/request` (الأسطر ~1512-1584):
   - قبول `phone`, `locationLat`, `locationLng`, `locationAddress` من `req.body`.
   - رفض الطلب بـ `400` ورسالة `missing_required_fields` إذا كان أي من `phone`/`locationLat`/`locationLng` فارغًا.
   - تخزينها في `INSERT`/`ON CONFLICT DO UPDATE` بجانب `business_name`/`commercial_registration`.

**Frontend:**
1. `lib/services/company_server_service.dart`: تحديث توقيع `requestMerchantRole`/`requestBrandRole` لقبول
   `phone`, `locationLat`, `locationLng`, `locationAddress` وإرسالها ضمن جسم الطلب.
2. `lib/screens/role_activation_request_screen.dart`:
   - إضافة `TextFormField` لرقم الهاتف مع تحقق إلزامي.
   - إضافة زر "تحديد موقع النشاط على الخريطة" يفتح `MapPickerScreen` وينتظر نتيجة `LatLng`،
     ويعرض بعدها ملخصًا (الإحداثيات أو عنوان مختصر) مع إمكانية التعديل.
   - منع الإرسال (`_submit`) ما لم يكن الهاتف والموقع محددين، مع رسالة خطأ واضحة إن حاول المستخدم
     الإرسال بدونهما.
3. إضافة اختبار شاشة (`role_activation_request_screen_test.dart` أو تحديث الموجود إن وُجد) يتحقق أن
   زر الإرسال معطَّل/يمنع الإرسال دون هاتف وموقع.

---

## الفجوة 2: لا توجد لوحة إدارة كوبونا وظيفية (Admin Dashboard) إطلاقًا

### الوضع الحالي (مؤكَّد بالكود)
- لا يوجد أي ملف `admin_dashboard_screen.dart` أو مكافئ في `lib/screens/` (تحقَّق منه مسبقًا بالبحث الشامل).
- لا يوجد أي استدعاء لأي endpoint من `/api/admin/*` في `lib/services/company_server_service.dart`.
- **الأخطر:** حتى على مستوى الـ Backend، لا يوجد أي endpoint لعرض قائمة الطلبات/الإعلانات المعلَّقة:
  - يوجد فقط `POST /api/admin/role-requests/:id/approve|reject` (يحتاج `id` جاهزًا مسبقًا — لا توجد
    طريقة لمعرفة الـ `id` أصلًا بدون استعلام قاعدة بيانات يدوي).
  - يوجد فقط `POST /api/admin/peer-ads/:id/approve|reject` لنفس السبب.
  - يوجد `GET /api/roles/requests/me` لكنه يعرض طلبات المستخدم نفسه فقط، وليس كل الطلبات المعلَّقة لكل المستخدمين.
  - يوجد `GET /api/admin/dashboard/summary` فقط (تحليلات عامة، بدون قوائم قابلة للتنفيذ).

بمعنى آخر: **الأدمن حاليًا لا يملك طريقة عملية للتعرّف على الطلبات المعلَّقة أصلًا، لا في الواجهة ولا حتى
عبر API جاهز** — هذه فجوة أعمق من مجرد "تصميم بصري ناقص" كما افترضنا سابقًا في فازة 24.

### المطلوب (الحد الأدنى الوظيفي لهذه الجولة)

**Backend — إضافة نقاط نهاية قوائم جديدة (Read endpoints)، كل واحدة محمية بـ `requireAdmin`:**
```
GET /api/admin/role-requests?status=pending_admin_review
  → يعيد كل صفوف role_requests بهذه الحالة (id, user_id, role_type, business_name,
    commercial_registration, phone, location_lat/lng, plan_type, created_at)
    (JOIN مع merchant_profiles/brand_profiles حسب role_type للحصول على تفاصيل النشاط).

GET /api/admin/peer-ads?status=pending_review
  → يعيد كل صفوف peer_ads بحالة الانتظار.
```
(أسماء الحالات يجب تأكيدها من enum الفعلي الموجود في الجداول قبل التنفيذ — لا تخمين، افحص القيم
الفعلية المخزَّنة في العمود `status` لكل جدول أولًا.)

**Frontend — شاشة أدمن حقيقية وظيفية (وليست تصميمًا فارغًا):**
1. ملف جديد: `lib/screens/admin_dashboard_screen.dart` يحتوي (على الأقل) ثلاثة أقسام/تبويبات:
   - **طلبات الأدوار المعلَّقة:** قائمة من `GET /api/admin/role-requests`، كل عنصر يعرض اسم النشاط/
     الهاتف/الموقع (رابط خريطة أو إحداثيات)/نوع الخطة، مع زرَي "موافقة"/"رفض" مربوطين فعليًا بـ
     `POST /api/admin/role-requests/:id/approve|reject`.
   - **إعلانات الأفراد المعلَّقة:** قائمة من `GET /api/admin/peer-ads`، مع نفس منطق موافقة/رفض
     مربوط بـ `/api/admin/peer-ads/:id/approve|reject`.
   - **ملخص/تحليلات:** عرض بيانات `GET /api/admin/dashboard/summary` (أرقام حية، لا زخرفة).
2. نقطة الدخول: في نقطة تحديد الشاشة الرئيسية بعد تسجيل الدخول (على الأرجح في `main.dart` أو
   `home_screen.dart` حيث يُحسَب `activeRole`)، إن كان `role == 'admin'` أو كان `roles.admin == true`
   للمستخدم، اعرض زر/مسار دخول صريح إلى `AdminDashboardScreen` (لا تُلغِ تسجيل الدخول العادي — نفس
   حساب المستخدم، فقط يظهر مسار إضافي إن كان دوره أدمن).
3. طبّق `adminTheme` (من `lib/theme/app_themes.dart`، الفازة 19) على هذه الشاشة تحديدًا — لا تخترع
   ألوانًا جديدة.
4. أضف اختبار شاشة (`admin_dashboard_screen_test.dart`) يتحقق من: عرض القوائم، واستدعاء endpoint
   الموافقة/الرفض الصحيح عند الضغط على الأزرار (mock للـ service).

### خارج نطاق هذه الجولة (تأجيل صريح)
- لوحة إدارة متقدمة لكل الوظائف الإدارية الأخرى (الاشتراكات، انتهاء النقاط، سجلات الاحتيال، تقارير
  الدعم) — هذه تبقى ضمن الفازة 24 الأصلية في `KUPUNA_MASTER_EXECUTION_PLAN.md`، ولا تُبنى الآن.
- هذه الجولة تغطي فقط: **(أ) قوائم + موافقة/رفض طلبات الأدوار، (ب) قوائم + موافقة/رفض إعلانات الأفراد،
  (ج) عرض ملخص التحليلات الموجود مسبقًا.**

---

## معيار القبول الإجمالي لهذه الخطة (لا إعلان اكتمال بدون كل بند)
1. `flutter analyze`: "No issues found!" (ناتج خام كامل).
2. `flutter test`: "All tests passed!" (السطر الأخير + العدد الدقيق).
3. دليل خام يثبت رفض الخادم لطلب تفعيل دور بدون هاتف/موقع (طلب curl تجريبي بدون هذين الحقلين يعيد 400).
4. دليل خام (لقطة شاشة أو وصف من accessibility snapshot) يثبت: تسجيل حساب أدمن اختباري، الدخول إلى
   `AdminDashboardScreen`، رؤية طلب دور حقيقي بالقائمة، الضغط على "موافقة"، ثم التأكد عبر استعلام
   قاعدة البيانات أو `GET /api/roles/requests/me` (بحساب التاجر نفسه) أن الحالة تحوَّلت فعليًا إلى
   `approved`.
5. تقرير جديد: `PHASE_MERCHANT_ONBOARDING_AND_ADMIN_PANEL_REPORT.md` بنفس تنسيق الأدلة الخام المتبع
   في كل الفازات السابقة (لا سرد وصفي).
