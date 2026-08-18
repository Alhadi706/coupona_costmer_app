# PHASE 0 BASELINE REPORT

## الحالة
- الحالة: FAILED (غير مكتملة)
- السبب: شرط التحقق الإلزامي للفازة 0 لم يتحقق بالكامل لأن `flutter analyze` و `flutter test` فشلا.

## ما تم تنفيذه
1. إنشاء فرع العمل المطلوب:
   - `feature/kupuna-master-spec`
2. أخذ نسخة احتياطية من قاعدة البيانات على السيرفر البعيد:
   - المسار: `/opt/projects/kupuna/backups/kupuna_db_2026-08-06_235829.dump`
3. تنفيذ تحقق صحة الخادم:
   - `Invoke-RestMethod -Uri 'http://154.12.117.175:3002/api/health' | ConvertTo-Json -Compress`

## نتيجة أمر التحقق الفعلية (منسوخة)

### 1) flutter analyze
```text
Analyzing coupona_app...

   info - The file name 'about_screen copy.dart' isn't a
          lower_case_with_underscores identifier - lib\screens\about_screen
          copy.dart:1:1 - file_names
warning - Unused import: 'home_screen.dart' -
       lib\screens\add_coupon_screen.dart:10:8 - unused_import
   info - Parameter 'key' could be a super parameter -
          lib\screens\add_coupon_screen.dart:14:9 - use_super_parameters
   info - Parameter 'key' could be a super parameter -
          lib\screens\ads_banner_slider.dart:8:9 - use_super_parameters
warning - Unused import: 'dart:ui' - lib\screens\home_screen.dart:1:8 -
       unused_import
warning - The value of the local variable 'langKey' isn't used -
       lib\screens\home_screen.dart:378:11 - unused_local_variable
warning - The declaration '_buildSpeedDial' isn't referenced -
       lib\screens\home_screen.dart:497:13 - unused_element
   info - The imported package 'intl' isn't a dependency of the importing
          package - lib\screens\offer_detail_screen.dart:9:8 -
          depend_on_referenced_packages
warning - Unused import: 'package:intl/intl.dart' -
       lib\screens\offer_detail_screen.dart:9:8 - unused_import
warning - Unused import: 'dart:ui' - lib\screens\report_screen.dart:4:8 -
       unused_import
warning - The value of the field '_pickedImage' isn't used -
       lib\screens\report_screen.dart:21:10 - unused_field
warning - The value of the field '_storeId' isn't used -
       lib\screens\report_screen.dart:50:11 - unused_field
warning - The declaration '_pickImage' isn't referenced -
       lib\screens\report_screen.dart:52:16 - unused_element
warning - The declaration '_pickBirthDate' isn't referenced -
       lib\screens\signup_screen.dart:56:8 - unused_element
   info - The imported package 'supabase_flutter' isn't a dependency of the
          importing package - lib\services\supabase_invoice_service.dart:1:8 -
          depend_on_referenced_packages
  error - Target of URI doesn't exist:
         'package:supabase_flutter/supabase_flutter.dart' -
         lib\services\supabase_invoice_service.dart:1:8 - uri_does_not_exist
  error - Target of URI doesn't exist: 'supabase_service.dart' -
         lib\services\supabase_invoice_service.dart:2:8 - uri_does_not_exist
   info - The imported package 'cloud_firestore' isn't a dependency of the
          importing package - lib\services\supabase_invoice_service.dart:3:8 -
          depend_on_referenced_packages
  error - Target of URI doesn't exist:
         'package:cloud_firestore/cloud_firestore.dart' -
         lib\services\supabase_invoice_service.dart:3:8 - uri_does_not_exist
  error - Undefined name 'SupabaseService' -
         lib\services\supabase_invoice_service.dart:16:11 - undefined_identifier
  error - Undefined name 'FirebaseFirestore' -
         lib\services\supabase_invoice_service.dart:30:26 - undefined_identifier
   info - Parameter 'key' could be a super parameter -
          lib\widgets\category_shortcut.dart:11:9 - use_super_parameters

22 issues found. (ran in 125.4s)
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

00:13 +17 -1: C:/Users/test/coupona_app/test/invoice_real_receipts_patterns_test.dart: Parses item-table receipt and detects bottom total [E]
  Expected: 'شـنـابو'
    Actual: 'شنابو'
     Which: is different.
            Expected: شـنـابو
              Actual: شنابو
                       ^
             Differ at offset 1

To run this test again: C:\flutter3\flutter_windows_3.32.0-stable\flutter\bin\cache\dart-sdk\bin\dart.exe test C:/Users/test/coupona_app/test/invoice_real_receipts_patterns_test.dart -p vm --plain-name "Parses item-table receipt and detects bottom total"
00:16 +20 -1: Some tests failed.

Command exited with code 1
```

### 3) backend health
```text
{"ok":true}
```

## أي انحراف عن الخطة مع السبب
- الانحراف: الفازة 0 تشترط نجاحًا كاملًا لـ `flutter analyze` و `flutter test` قبل الانتقال.
- الواقع: كلاهما فشل على خط الأساس الحالي قبل أي تطوير جديد.
- السبب: يوجد تعارض واضح بين شرط الخطة الصارم وبين الحالة الحالية للمستودع (Baseline غير نظيف).

## قرار التنفيذ
- التوقف عند الفازة 0 وعدم الانتقال للفازة 1 حتى تصحيح فشل `analyze/test` إلى نجاح كامل 100%.

## تثبيت الأساس (Baseline Stabilization)

تم تنفيذ خطوة تثبيت ضمن نفس الفرع `feature/kupuna-master-spec` بدون الرجوع لأي نقطة مرجعية سابقة.

### 1) التحقق من الملف اليتيم وحذفه
- الملف: `lib/services/supabase_invoice_service.dart`
- التحقق: لا توجد أي استخدامات فعلية للكلاس `SupabaseInvoiceService` أو للاستيراد المرتبط به في كامل المشروع.
- الإجراء: حذف الملف بالكامل لأنه كود ميت (orphaned).

### 2) تصنيف مشاكل `flutter analyze` الأصلية (22)
- أخطاء حقيقية (Errors) كانت تمنع البناء:
       - URI غير موجود لـ `supabase_flutter`.
       - URI غير موجود لـ `supabase_service.dart`.
       - URI غير موجود لـ `cloud_firestore`.
       - معرفات غير معرّفة `SupabaseService` و`FirebaseFirestore`.
- تحذيرات/ملاحظات أسلوبية (Warnings/Infos):
       - Unused imports/fields/elements.
       - اقتراحات `use_super_parameters`.
       - اسم ملف غير مطابق للـ lint.

تم إصلاح الأخطاء الحقيقية فورًا عبر حذف الملف اليتيم، ثم تنظيف التحذيرات الأسلوبية المتبقية إلى أن أصبح `flutter analyze` نظيفًا بالكامل.

### 3) إصلاح خلل اختبار `invoice_real_receipts_patterns_test.dart`
- الملف المُصحَّح: `lib/modules/invoice/services/invoice_text_parser.dart`
- أصل الخلل:
       - الـ parser كان يطبع/يوحّد اسم المتجر مبكرًا إلى القيمة المعيارية `شنابو` ويفقد صيغة النص الأصلية في الإيصال (`شـنـابو`).
- الإصلاح المنطقي:
       - الحفاظ على صيغة اسم المتجر كما تظهر في النص (عدم حذف tatweel أثناء التطبيع العام للنص).
       - جعل مرشح اسم المتجر المستخرج من سطر الإيصال أعلى أولوية من الاسم المعياري (canonical alias) عند الإرجاع النهائي.
- النتيجة:
       - الحالة الفاشلة سابقًا أصبحت تمر بدون تعديل التوقعات في الاختبار.

### 4) نتائج التحقق النهائية بعد التثبيت

#### flutter analyze
```text
Analyzing coupona_app...
No issues found! (ran in 4.7s)
```

#### flutter test
```text
00:09 +14: C:/Users/test/coupona_app/test/invoice_parser_accuracy_20_samples_test.dart: Invoice parser accuracy report on 20 OCR-like samples
Invoice parser accuracy (20 samples):
total: 100.00% (20/20)
invoiceNumber: 100.00% (20/20)
storeName: 100.00% (20/20)
invoiceDate: 100.00% (20/20)
category: 100.00% (20/20)
overall field accuracy: 100.00% (100/100)

00:12 +21: All tests passed!
```

### 5) حالة الفازة 0 بعد التثبيت
- الحالة النهائية: PASSED
- شرط القبول تحقق بالكامل: الفرع موجود + النسخة الاحتياطية موجودة + `flutter analyze` نظيف + `flutter test` ناجح + فحص Health للخادم ناجح.
