# Kupuna API Security Matrix

Total endpoints: 142

- ADMIN ONLY: 25
- AUTHENTICATED: 1
- OWNER PROTECTED: 112
- PUBLIC: 3
- SYSTEM INTERNAL: 1

| Method | Path | Line | Class | Auth | Role | Owner Check | DB | File | External | Status |
|---|---|---:|---|---|---|---|---|---|---|---|
| GET | /api/health | 1822 | PUBLIC | NO | none | YES | YES | NO | NO | REVIEWED |
| POST | /api/auth/signup | 1831 | PUBLIC | NO | none | YES | YES | NO | NO | REVIEWED |
| POST | /api/auth/login | 1896 | PUBLIC | NO | none | YES | YES | NO | NO | REVIEWED |
| POST | /api/auth/logout | 1910 | OWNER PROTECTED | YES | authenticated | YES | YES | YES | NO | REVIEWED |
| PATCH | /api/auth/change-password | 1915 | OWNER PROTECTED | YES | authenticated | YES | YES | YES | NO | REVIEWED |
| PATCH | /api/auth/update-profile | 1938 | OWNER PROTECTED | YES | authenticated | YES | YES | YES | NO | REVIEWED |
| POST | /api/uploads/image | 1964 | OWNER PROTECTED | YES | authenticated | YES | YES | YES | NO | REVIEWED |
| GET | /api/uploads/:fileName | 2011 | OWNER PROTECTED | YES | authenticated | YES | YES | YES | NO | REVIEWED |
| GET | /api/roles/me | 2027 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/roles/merchant/request | 2102 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/roles/brand/request | 2165 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/roles/requests/me | 2225 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/admin/role-requests | 2249 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/admin/role-requests/:id/approve | 2308 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/admin/role-requests/:id/reject | 2407 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/subscriptions/run-transitions | 2443 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| GET | /api/admin/subscriptions | 2452 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/admin/subscriptions/:id/expire-trial-now | 2507 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/admin/subscriptions/:id/end-grace-now | 2533 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/subscriptions/:id/activate-now | 2559 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/profile | 2808 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| PATCH | /api/merchant/settings/point-value | 2838 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/brand/profile | 2867 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| PATCH | /api/brand/settings/point-value | 2897 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/merchant/branches | 2922 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/branches | 2971 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/merchant/branches/:id/managers | 2985 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/merchant/cashiers/bind | 3015 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| PATCH | /api/merchant/branches/:id/managers/:userId/permissions | 3068 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/manager/scope | 3115 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/manager/invoices/review-queue | 3169 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/brand/team-members | 3215 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/wallet/cashback-v2 | 3240 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/wallet/refund-deduction | 3299 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/points/expire/run | 3321 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/cashier/grant-points | 3351 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/scan-v2 | 3444 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/data-retention/run | 3518 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/brand/products | 3527 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/:id/line-items | 3546 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/:id/brand-matches | 3576 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/:id/state-transition | 3607 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/:id/disputes | 3692 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/invoices/disputes | 3743 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/merchant/invoices/disputes/:id/resolve | 3792 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/reports/eligible-stores | 3893 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/reports | 3917 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/reports/inbox | 4005 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/merchant/reports/:id/accept | 4079 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/reports/:id/transition | 4186 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/escrow/accounts | 4219 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/escrow/settlements | 4233 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| POST | /api/admin/exchange-rates | 4250 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/admin/exchange-rates | 4328 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/points/exchange | 4350 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/reward-claims/create | 4412 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/reward-claims/my | 4456 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/cashier/redeem-claim | 4485 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/reward-claims/refund-expired/run | 4560 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/reward-claims/:id/expire-now | 4586 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/escrow/summary | 4598 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/peer-ads | 4654 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/peer-ads/:id/approve | 4685 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/peer-ads/:id/reject | 4690 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/admin/peer-ads | 4696 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/peer-ads/feed | 4726 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/sourcing/inquiries | 4787 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/sourcing/inquiries/my | 4882 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/payments/webhook | 4913 | SYSTEM INTERNAL | NO | none | YES | YES | NO | NO | REVIEWED |
| POST | /api/predictive/recommend | 4942 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/loyalty-health | 4950 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/admin/edge-cases/run-catalog | 4974 | ADMIN ONLY | YES | admin | NO | YES | NO | NO | REVIEWED |
| GET | /api/admin/dashboard/summary | 4978 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/admin/fraud-flags | 5005 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/e2e/simulate | 5032 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| POST | /api/notifications/push-token/register | 5036 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/notifications/push-token/unregister | 5051 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/notifications/push-test | 5065 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/notifications/my | 5073 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/notifications/badge | 5095 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/notifications/:id/read | 5118 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/community/groups/my | 5130 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/community/badge | 5159 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/community/groups/:id/messages | 5174 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/community/groups/:id/messages | 5212 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/community/groups/:id/messages/:messageId/pin | 5258 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| DELETE | /api/community/groups/:id/messages/:messageId | 5273 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/community/groups/:id/members/:userId/ban | 5288 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/offers/targeted | 5305 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/offers/targeted/feed | 5439 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/offers | 5495 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/offers | 5585 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/stores | 5605 | AUTHENTICATED | YES | authenticated | NO | YES | NO | NO | REVIEWED |
| GET | /api/groups | 5694 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/groups | 5699 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/groups/:id/messages | 5719 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/groups/:id/messages | 5746 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/groups/:id/messages/:messageId/replies | 5757 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/groups/:id/messages/:messageId/replies | 5770 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/groups/:id/messages/:messageId/reactions | 5789 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/private-chats | 5804 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats | 5852 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/private-chats/:id/messages | 5915 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/messages | 5924 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/hide | 5958 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/unhide | 5973 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/delete | 5988 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/restore | 6003 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/mute | 6018 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/unmute | 6033 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/pin | 6048 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/unpin | 6063 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/private-chats/:id/read | 6078 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/blocks | 6093 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/users/:id/block | 6109 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/users/:id/unblock | 6128 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/users | 6140 | ADMIN ONLY | YES | admin | YES | YES | NO | NO | REVIEWED |
| GET | /api/users/:id | 6158 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/customer/location/me | 6180 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/customer/location/me | 6202 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/users/:id/profile | 6227 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/rewards | 6239 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/activity-logs | 6244 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/scan | 6251 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/invoices/analyze-ai | 6379 | OWNER PROTECTED | YES | authenticated | YES | YES | YES | YES | REVIEWED |
| GET | /api/invoices/my | 6401 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/analytics | 6493 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/brand/analytics | 6785 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/merchant/customers/top | 6979 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/wallet/ensure | 7023 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/wallet | 7030 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/wallet/points | 7037 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/wallet/points-breakdown | 7044 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/wallet/points/sources | 7088 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/wallet/ledger | 7134 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/wallet/cashback | 7148 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/wallet/redeem | 7177 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/offers/:id/lifecycle | 7206 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/offers/:id/lifecycle/ensure-defaults | 7220 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/offers/:id/lifecycle/transition | 7234 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| POST | /api/offers/:id/lifecycle/sync-temporal | 7256 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
| GET | /api/stats/counts | 7271 | OWNER PROTECTED | YES | authenticated | YES | YES | NO | NO | REVIEWED |
