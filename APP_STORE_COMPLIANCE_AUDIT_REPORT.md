# تقرير تدقيق امتثال متاجر التطبيقات - Kupuna

**التاريخ:** 2026-09-01  
**النطاق:** شاشات وميزات التاجر/البراند/الأدمن المرتبطة بالجوائز، القرعات، النقاط القابلة للتحويل، الاستهداف، الخصوصية، وSDKs الخارجية.  
**الخلاصة:** تم تعديل المخالفات الواضحة مباشرة. لا أعتبر التطبيق جاهزاً للتقديم للمتاجر قبل تنفيذ UAT الكامل 0-12 وفحص P0 الأمني المطلوبين في المعيار 5.

---

## المعيار 1: القرعة الترويجية الآمنة مقابل القمار المحظور

**الحالة:** عُدّل.

### الدليل والتعديل

1. لم أجد Wheel of Fortune فعلية في المصدر. البحث عن `Wheel|fortune|spin|عجلة|دوران` لم يجد إلا `isPinned` في الدردشة، لذلك لا توجد شاشة عجلة تحتاج فصل شرط شراء عنها حالياً.

2. محرك حملات `raffle` كان يربط إصدار التذكرة باعتماد فاتورة جديدة مؤهلة. عُدّل ليصدر التذاكر من شريحة تاريخية مؤهلة عند إطلاق الحملة، لا عند شراء/فاتورة جديدة:

```js
// backend/src/promotion-campaign-service.js
if (campaign.campaign_type === 'raffle') {
  const tickets = await issueRaffleTicketsForCustomers(client, campaign, customerIds, insertNotification, sourceName);
  return { campaign, dispatched: [], tickets, segmentSize: customerIds.length, note: 'raffle_tickets_issued_from_historical_eligibility' };
}

// Retained for compatibility; new raffle entries are issued only from historical eligibility at campaign launch.
async function issueRaffleTicketsForInvoice(client, sourceType, sourceId, customerId, invoiceId, invoiceAmount) {
  return [];
}
```

3. أضيف إفصاح عدم الشراء الإضافي في رسائل السحب:

```js
// backend/src/targeted-dispatch-service.js
const noPurchaseDisclosure = 'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك أو نشاطك المكتسب من مشترياتك العادية.';
```

4. أضيف الإفصاح في شاشة إطلاق حملة مستهدفة:

```dart
// lib/screens/merchant_campaign_screen.dart
return 'السحب مخصص لعملاء مؤهلين بناءً على نشاطهم السابق. لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطهم أو مشترياتهم العادية.';
```

5. أضيف الإفصاح في حقل السحب داخل شاشة إضافة جائزة البراند، مع إلزام تاريخ انتهاء:

```dart
// lib/screens/brand_dashboard_screen.dart
'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاط العميل المكتسبة من مشترياته العادية. يجب تحديد تاريخ انتهاء قبل تنفيذ السحب.'
```

```js
// backend/src/routes/rewards.js
if (drawEnabled && !p.expiresAt) return res.status(400).json({ error: 'draw_expiry_required' });
```

6. مُنع العميل من إنشاء أكثر من مطالبة لنفس جائزة السحب، حتى لا تتحول النقاط إلى شراء فرص إضافية:

```js
// backend/src/routes/exchange-rewards.js
if (existingDrawClaim) { await client.query('ROLLBACK'); return res.status(409).json({ error: 'draw_entry_already_exists' }); }
```

### تحقق منفذ

- `node live_promotional_campaigns_e2e.js` نجح: **16/16 PASS**.
- تحقق مباشر لسحب جوائز البراند نجح:

```json
{
  "rewardCreated": true,
  "disclosurePresent": true,
  "drawExpiryStored": true,
  "firstClaimStatus": 200,
  "secondClaimStatus": 409,
  "secondClaimError": "draw_entry_already_exists",
  "pass": true
}
```

---

## المعيار 2: من يحسب مقابل من يحول المال فعلياً

**الحالة:** عُدّل.

### الدليل والتعديل

وجدت endpoints مرتبطة بالتسوية/المقاصة:

- `POST /api/merchant/coalitions/clearinghouse/settle`
- `POST /api/escrow/settlements`
- `POST /api/cashier/redeem-claim`

لا يوجد SDK دفع خارجي أو تكامل A2B/G-Pay فعلي في الكود. لتجنب أي إيحاء بتنفيذ تحويل مالي، أضيفت حالة صريحة إلى جدول `settlements`:

```js
// backend/src/schema-extra.js
await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'internal_accounting_only'");
await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS execution_provider TEXT");
await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS external_transfer_reference TEXT");
await pool.query("ALTER TABLE settlements ADD COLUMN IF NOT EXISTS is_external_transfer_executed BOOLEAN NOT NULL DEFAULT FALSE");
```

وأصبحت الردود تؤكد عدم تنفيذ تحويل خارجي:

```js
// backend/src/routes/coalition.js
res.json({ ok: true, updated: rowCount, execution: 'internal_accounting_only', externalTransferExecuted: false });

// backend/src/routes/reports.js
return res.json({ ok: true, id: settlementId, execution: 'internal_accounting_only', externalTransferExecuted: false });

// backend/src/routes/exchange-rewards.js
return res.json({ ok: true, status: 'redeemed', settlementId, execution: 'internal_accounting_only', externalTransferExecuted: false });
```

واجهة المقاصة أيضاً عُدلت لغوياً:

```json
// assets/lang/ar.json
"clearinghouse_settle": "إغلاق محاسبي",
"clearinghouse_internal_only_disclosure": "كوبونا لا ينفّذ أي تحويل مالي خارجي هنا؛ هذه أداة احتساب وإغلاق محاسبي داخلي فقط."
```

---

## المعيار 3: دقة الإفصاح عن البيانات والخصوصية

**الحالة:** عُدّل، مع بند يحتاج قرارك للصياغة القانونية النهائية.

### الدليل والتعديل

كانت شاشة الخصوصية فارغة تقريباً. تم إنشاء شاشة خصوصية داخل التطبيق تصرح بالبيانات الفعلية:

```dart
// lib/screens/privacy_screen.dart
body: 'نجمع بيانات الحساب مثل الاسم والبريد، تاريخ الميلاد، الجنس، الموقع الجغرافي عند السماح به، صور/نصوص الفواتير، سجل الشراء، النقاط، الكوبونات، وتفاعلات الرسائل داخل التطبيق.',
```

وأضيف إفصاح الموقع الجغرافي والتخصيص الترويجي:

```dart
// lib/screens/privacy_screen.dart
body: 'نستخدم موقعك لعرض أقرب العروض والتجار، وقد يُستخدم لتخصيص عروض ترويجية داخل التطبيق. لا نستخدم الموقع لتتبعك خارج كوبونا.',
```

كما تم تحديث نص طلب صلاحية الموقع في شاشة التسجيل والترجمات حتى يظهر النص الصحيح فعلياً:

```dart
// lib/screens/signup_screen.dart
'We use your location to show nearby offers and merchants, improve offer relevance, verify role requests, and personalize promotional offers.'
```

```json
// assets/lang/ar.json
"location_rationale_body": "نستخدم موقعك لعرض أقرب العروض والتجار، وتحسين ملاءمة العروض، والتحقق من طلبات الأدوار، وقد يُستخدم لتخصيص عروض ترويجية داخل التطبيق."
```

**يحتاج قرارك:** النص الحالي تشغيلي وواضح، لكن الصياغة القانونية النهائية لسياسة الخصوصية قبل الرفع للمتاجر تحتاج اعتمادك/اعتماد مستشار قانوني، خصوصاً إن تغيّر نطاق مشاركة البيانات مستقبلاً.

---

## المعيار 4: الاستهداف الداخلي وعدم إضافة SDK إعلانات/تتبع خارجي

**الحالة:** مطابق.

### الدليل

تم فحص `pubspec.yaml` ومجلد `lib/**` بحثاً عن حزم/استدعاءات تتبع وإعلانات خارجية:

```text
google_mobile_ads | firebase_analytics | facebook_app_events | appsflyer | adjust_sdk |
amplitude_flutter | mixpanel_flutter | segment_analytics | app_tracking_transparency
```

النتيجة: لا توجد أي مطابقة في `pubspec.yaml` أو `lib/**`. الموجود في المشروع مثل `google_maps_flutter`, `google_mlkit_text_recognition`, `geolocator`, `http`, `dio` ليس SDK إعلانات أو تتبع طرف ثالث.

الدليل من `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.4.3+1
  qr_flutter: ^4.1.0
  google_mlkit_text_recognition: ^0.15.0
  google_maps_flutter: ^2.5.0
  geolocator: ^11.0.0
  mobile_scanner: ^7.4.0
```

---

## المعيار 5: جودة التطبيق الأساسية قبل أي تقديم للمتاجر

**الحالة:** يحتاج إغلاق منفصل قبل التقديم.

### ما تحقق الآن

1. ملفات الواجهة والـ backend المرتبطة بتدقيق الامتثال لا تحتوي أخطاء في لوحة المشاكل.
2. `node --check` مر على ملفات backend المعدلة.
3. `node live_promotional_campaigns_e2e.js` نجح **16/16**.
4. فحص سحب جائزة البراند المباشر نجح.
5. `flutter analyze` على ملفات التدقيق لم يظهر أخطاء، لكن بقيت 7 ملاحظات lint قديمة غير حاجبة:
   - حقول/دوال غير مستخدمة في `brand_dashboard_screen.dart`.
   - تحذيرات `BuildContext` عبر async gaps في `signup_screen.dart`.
   - استخدام `value` deprecated في موضع قديم من `signup_screen.dart`.

### لا أقول إن التطبيق جاهز للتقديم

حسب توجيهك، لا يجوز اعتبار التطبيق جاهزاً للمتاجر قبل:

- تنفيذ `kupuna-uat-full-script.md` للمراحل 0-12 بدليل فعلي.
- إغلاق فحص P0 الأمني: `signup role=admin`, وIDOR، وQR الحي.

هذه البنود لم تُنفذ ضمن هذا التدقيق الحالي، لذلك حالتها: **تحتاج تنفيذ UAT/P0 منفصل قبل التقديم**.

---

## الملفات الرئيسية المعدلة في هذا التدقيق

- `backend/src/promotion-campaign-service.js`
- `backend/src/targeted-dispatch-service.js`
- `backend/src/customer-segmentation-service.js`
- `backend/src/routes/campaigns.js`
- `backend/src/routes/rewards.js`
- `backend/src/routes/exchange-rewards.js`
- `backend/src/routes/reports.js`
- `backend/src/routes/coalition.js`
- `backend/src/schema-extra.js`
- `lib/screens/merchant_campaign_screen.dart`
- `lib/screens/brand_dashboard_screen.dart`
- `lib/screens/my_rewards_screen.dart`
- `lib/widgets/customer_campaign_coupons_section.dart`
- `lib/screens/privacy_screen.dart`
- `lib/screens/signup_screen.dart`
- `lib/screens/coalitions/coalition_clearinghouse_screen.dart`
- `assets/lang/ar.json`
- `assets/lang/en.json`

---

## القرار النهائي للتدقيق الحالي

**نتيجة التدقيق:** تم إغلاق المخالفات الواضحة في المعايير 1-4.  
**المتبقي قبل التقديم:** اعتماد النص القانوني النهائي للخصوصية، ثم تشغيل UAT الكامل وإغلاق P0 الأمني وفق معيار 5.