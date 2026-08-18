# PHASE 3 SUBSCRIPTIONS REPORT

## ما تم تنفيذه
- إضافة طبقة بيانات الفازة 3 في backend (`backend/server.js`):
  - جداول:
    - `role_requests`
    - `subscriptions`
    - `notifications`
    - `app_settings`
  - فهارس مساعدة للحالة والبحث.
  - إعدادات افتراضية:
    - `trial_duration_days_default = 30`
    - `grace_period_days_default = 7`
- إضافة منطق آلة حالة الاشتراك الأساسية:
  - دالة `runSubscriptionTransitions()`:
    - `trial -> grace_period` عند انتهاء `trial_end_date`
    - `grace_period -> suspended` عند تجاوز `next_billing_date`
    - إنشاء تنبيهات قبل الانتهاء عند 7 أيام و1 يوم.
- إضافة Endpoints الفازة 3:
  - `POST /api/roles/merchant/request`
  - `POST /api/roles/brand/request`
  - `GET /api/roles/requests/me`
  - `POST /api/admin/role-requests/:id/approve`
  - `POST /api/admin/role-requests/:id/reject`
  - `POST /api/subscriptions/run-transitions` (admin)
- تحديث `/api/roles/me` لإرجاع `subscriptions` المرتبطة.
- إضافة Scheduler كل ساعة لتشغيل انتقالات الاشتراك.
- Flutter:
  - إضافة خدمة API:
    - `requestMerchantRole`
    - `requestBrandRole`
    - `getMyRoleRequests`
  - إضافة شاشات:
    - `lib/screens/role_activation_request_screen.dart`
    - `lib/screens/role_requests_status_screen.dart`
  - تحديث `lib/screens/my_roles_screen.dart` لعرض حالة الاشتراك وطلبات التفعيل.
- اختبار آلة الحالة (Dart):
  - `lib/modules/subscription/subscription_state_machine.dart`
  - `test/subscription_state_machine_test.dart`

## نتيجة أمر التحقق الفعلية

### 1) flutter analyze
```text
Analyzing coupona_app...
No issues found! (ran in 8.6s)
```

### 2) flutter test
```text
00:11 +14: C:/Users/test/coupona_app/test/invoice_parser_accuracy_20_samples_test.dart: Invoice parser accuracy report on 20 OCR-like samples
Invoice parser accuracy (20 samples):
total: 100.00% (20/20)
invoiceNumber: 100.00% (20/20)
storeName: 100.00% (20/20)
invoiceDate: 100.00% (20/20)
category: 100.00% (20/20)
overall field accuracy: 100.00% (100/100)

00:19 +25: All tests passed!
```

### 3) تحقق Backend فعلي (سيناريو حي على نسخة معزولة 3006 من نفس الكود المرفوع)
```text
MERCHANT_REQUEST={"ok":true,"requestId":"4639ff81-4a98-4ae6-8dc1-03f6d9ec4e76","status":"pending_admin_review"}
APPROVE={"ok":true,"status":"approved","subscriptionStatus":"trial"}
ROLES_AFTER_APPROVE={"customer":true,"merchant":true,"brand":false,"cashier":[],"subscriptions":[{"roleType":"merchant","status":"trial",...}]}
TRANSITION_RUN={"ok":true}
ROLES_AFTER_TRANSITION={"customer":true,"merchant":true,"brand":false,"cashier":[],"subscriptions":[{"roleType":"merchant","status":"grace_period",...}]}
```

التحقق يثبت:
- إنشاء طلب تفعيل التاجر.
- موافقة أدمن وتحويل الاشتراك إلى `trial`.
- الانتقال إلى `grace_period` بعد انتهاء `trial_end_date`.
- بقاء `customer=true` دون تأثر (تحقيق قاعدة عزل دور العميل).

## أي انحراف عن الخطة مع السبب
- انحراف تشغيلي بيئي:
  - عملية API العاملة على `3005` في السيرفر لم تكن قابلة للاستبدال المباشر (عملية قديمة + قيود إنهاء العملية)، لذلك تحقق الفازة 3 الوظيفي تم عبر نسخة معزولة على `3006` من نفس ملفات الكود المرفوعة.
  - هذا لا يغيّر من صحة التنفيذ البرمجي، لكنه يؤثر على نشر التغييرات مباشرة على الخدمة الحية حتى حل إذن إدارة العملية.

## الحالة
- الحالة النهائية للفازة 3: PASSED (وظيفيًا وكوديًا)
