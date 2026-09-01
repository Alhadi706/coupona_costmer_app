# Backend module map (فهرسة الملفات)

`server.js` (8700 سطر) تم تقسيمه إلى الوحدات التالية تحت `backend/src/`، كل ملف لا يتجاوز 600 سطر.
النسخة الأصلية محفوظة في `backend/server.js.pre-split.bak` للمرجعية فقط (غير مستخدمة في التشغيل).

## البنية التحتية (Infra)

| الملف | المحتوى | أسطر |
|---|---|---|
| `src/app.js` | إنشاء تطبيق Express، متغيرات البيئة/الإعدادات، `corsGuard`، محددات معدل الطلبات (rate limiters) | 203 |
| `src/db.js` | اتصال قاعدة البيانات (`pool`) وقائمة الأدوار `CANONICAL_ROLES` | 12 |
| `src/helpers.js` | دوال مساعدة عامة: توليد المعرّفات، JWT، owner MFA، بصمة الفواتير، تحليل الفواتير عبر Gemini AI | 490 |
| `src/access-control.js` | middleware المصادقة `auth`/`requireAdmin`، صلاحيات الوصول للفواتير والملف الشخصي للعميل | 121 |
| `src/schema-core.js` | إنشاء الجداول الأساسية (users, offers, stores, wallet...) | 447 |
| `src/schema-extra.js` | إنشاء بقية الجداول (community, disputes, escrow, rewards...) | 435 |
| `src/services-social.js` | إدارة الاشتراكات، الحظر، المحادثات الخاصة، الإشعارات (FCM)، مجموعات المجتمع | 537 |
| `src/services-matching.js` | مكافآت اعتماد الفواتير، مطابقة العروض/الماركات، دوال التحليلات (analytics) | 461 |

## المسارات (Routes) — كل ملف يصدّر `function(app, deps)`

| الملف | يغطي endpoints تحت |
|---|---|
| `src/routes/auth.js` | `/api/health`, `/api/auth/*`, `/api/uploads/*` |
| `src/routes/roles-subscriptions.js` | `/api/roles/*`, `/api/admin/role-requests/*`, `/api/admin/subscriptions/*` |
| `src/routes/merchant.js` | `/api/merchant/profile|settings|branches|cashiers|manager/*`, `/api/brand/profile|settings|team-members`, `/api/brand/team-members` |
| `src/routes/wallet-actions.js` | `/api/wallet/cashback-v2`, `/api/wallet/refund-deduction`, `/api/admin/points/expire/run`, `/api/customer/pos-qr-token`, `/api/cashier/grant-points` |
| `src/routes/invoices.js` | `/api/invoices/scan-v2`, `/api/invoices/:id/*` (line-items, brand-matches, state-transition, disputes), `/api/merchant/invoices/disputes/*` |
| `src/routes/reports.js` | `/api/reports/*`, `/api/merchant|brand/reports/*`, `/api/escrow/*` |
| `src/routes/exchange-rewards.js` | `/api/admin/exchange-rates`, `/api/points/exchange`, `/api/reward-claims/*`, `/api/cashier/redeem-claim`, `/api/merchant/escrow/summary` |
| `src/routes/peerads-sourcing-admin.js` | `/api/peer-ads/*`, `/api/sourcing/inquiries/*`, `/api/payments/webhook`, `/api/predictive/recommend`, `/api/merchant/loyalty-health`, `/api/admin/dashboard/summary`, `/api/admin/operations/queue`, `/api/admin/fraud-flags`, `/api/e2e/simulate` |
| `src/routes/notifications-community.js` | `/api/notifications/*`, `/api/community/*` |
| `src/routes/offers-billboard.js` | `/api/offers/targeted*`, `/api/offers` (list/create), `/api/billboard-ads/*`, `/api/admin/billboard-ads/*` |
| `src/routes/legacy-groups-chat.js` | `/api/stores`, `/api/groups/*` (القديم) |
| `src/routes/users.js` | `/api/private-chats/*`, `/api/blocks`, `/api/users/*`, `/api/customer/location/me` |
| `src/routes/rewards.js` | `/api/rewards`, `/api/merchant|brand/rewards`, `/api/admin/rewards/*`, `/api/activity-logs` |
| `src/routes/invoices-legacy-scan.js` | `/api/invoices/scan` (القديم), `/api/invoices/analyze-ai`, `/api/invoices/my` |
| `src/routes/analytics.js` | `/api/merchant/analytics`, `/api/brand/analytics`, `/api/merchant/customers/top` |
| `src/routes/wallet-core.js` | `/api/wallet/*` (ensure, points, ledger, cashback, redeem...) |
| `src/routes/offers-lifecycle-stats.js` | `/api/offers/:id/lifecycle/*`, `/api/stats/counts` |

## نقطة التشغيل

`server.js` (الجديد، ~65 سطر) يجمّع كل الوحدات أعلاه في كائن `deps` واحد، يسجّل كل ملفات المسارات، وينفذ `initSchema()` ثم `app.listen(...)`.

## ملاحظات للصيانة
- كل ملف route يستقبل نفس القائمة الكاملة من `deps` (استخراج زائد غير مستخدم غير ضار في JS)، لتفادي أخطاء نسيان تمرير اعتمادية معينة.
- عند إضافة endpoint جديد: أضفه لأقرب ملف route منطقي له، فإن تجاوز 600 سطر أنشئ ملفاً جديداً وسجّله في `server.js` وهنا في `INDEX.md`.
- عند إضافة جدول جديد: أضفه إلى `schema-extra.js` (أو أنشئ `schema-extra-2.js` إذا اقترب من 600 سطر).
