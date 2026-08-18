# PHASE 1 UNIFIED USER REPORT

## ما تم تنفيذه
- تنفيذ جداول ملفات الأدوار في backend:
  - `customer_profiles`
  - `merchant_profiles`
  - `brand_profiles`
  - `cashier_profiles`
- إنشاء ملف migration إلزامي:
  - `backend/migrations/001_role_profiles.sql` (idempotent)
- تحديث `backend/server.js`:
  - إضافة إنشاء الجداول والفهارس بشكل آمن في `initSchema`.
  - إضافة دالة `ensureCustomerProfile`.
  - تعديل `/api/auth/signup` ليُنشئ `customer_profiles` تلقائيًا داخل Transaction.
  - إضافة endpoint جديد `GET /api/roles/me` يرجع:
    - `customer`
    - `merchant`
    - `brand`
    - `cashier` (قائمة ربطات الكاشير)
- تحديث Flutter service:
  - إضافة `CompanyServerService.getMyRoles()` في `lib/services/company_server_service.dart`.

## نتيجة أمر التحقق الفعلية

### 1) flutter analyze
```text
Analyzing coupona_app...
No issues found! (ran in 6.8s)
```

### 2) flutter test
```text
00:12 +14: C:/Users/test/coupona_app/test/invoice_parser_accuracy_20_samples_test.dart: Invoice parser accuracy report on 20 OCR-like samples
Invoice parser accuracy (20 samples):
total: 100.00% (20/20)
invoiceNumber: 100.00% (20/20)
storeName: 100.00% (20/20)
invoiceDate: 100.00% (20/20)
category: 100.00% (20/20)
overall field accuracy: 100.00% (100/100)

00:16 +21: All tests passed!
```

### 3) تحقق SQL للجداول
```text
List of relations
 Schema |       Name        | Type  |    Owner
--------+-------------------+-------+-------------
 public | brand_profiles    | table | kupuna_user
 public | cashier_profiles  | table | kupuna_user
 public | customer_profiles | table | kupuna_user
 public | merchant_profiles | table | kupuna_user
(4 rows)
```

### 4) تحقق endpoint `/api/roles/me` مع Token فعلي
```text
ROLES={"customer":true,"merchant":false,"brand":false,"cashier":[]}
```

### 5) تحقق الإنشاء التلقائي لـ `customer_profiles` بعد signup
```text
SELECT user_id FROM customer_profiles WHERE user_id = '<new_user_id>' LIMIT 1;
-- returned the same user_id
```

## أي انحراف عن الخطة مع السبب
- انحراف تشغيلي أثناء النشر:
  - فشل أول تشغيل للـ API بسبب صيغة فهرس PostgreSQL قديمة غير immutable في `ux_invoice_scans_dedupe`.
  - تم التصحيح إلى صيغة immutable آمنة:
    - `COALESCE(invoice_date, DATE '1970-01-01')`
    - `COALESCE(total_amount, -1)`
- انحراف بيئة:
  - بوابة `:3002` لم تكشف endpoint الجديد فورًا أثناء تحقق خارجي؛ تم تنفيذ تحقق endpoint مباشرة على backend الفعلي `:3005` محليًا على السيرفر (localhost) وتأكيد النجاح.

## الحالة
- الحالة النهائية للفازة 1: PASSED
