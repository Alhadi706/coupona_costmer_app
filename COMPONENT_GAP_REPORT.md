# Kupuna Component Gap Report

Date: 2026-07-22
Prepared by: GitHub Copilot
Scope: Component-first gap extraction for Flutter app in this repository

## 1) Executive Summary

- Total visible UI screen components in `lib/screens`: 43
- Service components in `lib/services`: 8
- Reusable widget components in `lib/widgets`: 7
- Current maturity: Prototype-to-beta, with customer flow partially implemented and merchant/agent/admin domains largely missing.
- Estimated product completion (feature-level from prior audit): ~20%

## 2) Component Inventory (By Domain)

### A) Core App Shell

| Component | Evidence | Status | Notes |
|---|---|---|---|
| App bootstrap + localization + Firebase init | lib/main.dart | Partial | Works, but route architecture is minimal and role-based app shell is not established. |
| Onboarding | lib/screens/onboarding_screen.dart | Partial | Present, needs completion criteria and analytics instrumentation. |
| Splash | lib/screens/splash_screen.dart | Partial | Exists, but not clearly integrated in full startup flow. |
| Settings | lib/screens/settings_screen.dart | Partial | Present with likely route mismatch to unnamed routes. |

### B) Customer Authentication and Profile

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Login | lib/screens/login_screen.dart | Partial | Basic auth present; hardened session/error handling missing. |
| Signup/Register | lib/screens/signup_screen.dart, lib/screens/register_screen.dart | Partial | Multiple entry screens indicate overlap/duplication risk. |
| Profile View | lib/screens/profile_screen.dart | Partial | Reads profile but limited validation/edit lifecycle. |
| Complete Profile | lib/screens/complete_profile_screen.dart | Partial | Saves profile fields, but standardization/rules still needed. |

### C) Offers, Coupons, Rewards, Points

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Offers feed | lib/screens/offers_screen.dart, lib/screens/offers_list_screen.dart | Partial | Feed exists; schema consistency and moderation flow missing. |
| Offer details | lib/screens/offer_detail_screen.dart, lib/screens/coupon_detail_screen.dart | Partial | Multiple detail screens suggest consolidation needed. |
| Add coupon | lib/screens/add_coupon_screen.dart, lib/screens/add_manual_coupon_screen.dart | Partial | Creation exists; approval and lifecycle controls missing. |
| Rewards | lib/screens/rewards_screen.dart, lib/screens/my_rewards_screen.dart | Partial | UX exists but redemption engine is incomplete. |
| Points | lib/screens/points_screen.dart, lib/screens/my_points_screen.dart, lib/screens/points_conversion_screen.dart | Partial | UI exists, but canonical points ledger/rules missing. |
| Reward QR | lib/screens/reward_qr_code_screen.dart | Partial | UI exists; verification/redeem backend missing. |

### D) Community and Social

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Community main | lib/screens/community_screen.dart | Partial | Group tab + private chat mock patterns coexist. |
| Group chat | lib/screens/community_screen.dart | Partial | Stream read exists; robust send/identity/moderation missing. |
| Private chat | lib/screens/community_screen.dart | Partial | Mostly static/demo-level content. |

### E) Maps and Location

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Full map | lib/screens/full_map_screen.dart | Partial | Firestore-driven map exists; production map governance missing. |
| Stores map | lib/screens/stores_map_screen.dart | Partial | Needs unified source and role-based management. |
| Map picker | lib/screens/map_picker_screen.dart | Partial | Utility exists; persistence flow standardization needed. |

### F) Reports, Notifications, Help/Legal

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Report issue | lib/screens/report_issue_screen.dart, lib/screens/report_screen.dart | Partial | Reporting UI exists; backend processing pipeline missing. |
| Notifications | lib/screens/notifications_screen.dart | Partial | UI placeholder tendencies; real push system missing. |
| About/Help | lib/screens/about_screen.dart, lib/screens/help_screen.dart | Partial | Mostly content-level and not operationally connected. |
| Privacy/Terms | lib/screens/privacy_screen.dart, lib/screens/terms_screen.dart | Partial | Present as static pages; policy/version workflow missing. |

### G) Home Composition and Navigation UI

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Home container | lib/screens/home_screen.dart | Partial | Rich composition exists; many hardcoded/demo values remain. |
| Home content module | lib/screens/home_content_screen.dart | Partial | Useful structure; needs data contracts and loading/error states. |
| Banner slider | lib/screens/ads_banner_slider.dart | Partial | UI present, ad source/targeting workflow missing. |
| Category offers | lib/screens/category_offers_screen.dart | Partial | Depends on static categories in current home architecture. |

### H) Services Layer

| Component | Evidence | Status | Notes |
|---|---|---|---|
| API service abstraction | lib/services/api_service.dart | Partial | Abstraction exists; not full production backend contract. |
| Badge helper | lib/services/badge_helper.dart | Partial | Useful local badge state, no server-side consistency. |
| Image upload (Imgur) | lib/services/imgur_service.dart | Risk/Partial | External key handling and security hardening required. |
| Supabase services | lib/services/supabase_service.dart and related files | Partial/Disabled | Present but disabled/inconsistent with Firebase-first runtime. |

### I) Reusable Widgets

| Component | Evidence | Status | Notes |
|---|---|---|---|
| Navigation shortcuts/icons | lib/widgets/menu_icon.dart, report_icon.dart, scan_invoice_icon.dart, add_invoice_icon.dart | Partial | UI helper widgets exist; role-awareness and states need completion. |
| Category/map bars | lib/widgets/category_bar.dart, category_shortcut.dart, map_bar.dart | Partial | Good base; needs canonical data source and responsiveness checks. |

## 3) Missing Components (High Impact)

| Missing Component | Status | Why Critical |
|---|---|---|
| Dedicated Merchant module (dashboard/branches/employees/offers/campaigns) | Missing | Core business actor is not implemented as a complete domain. |
| Dedicated Admin control plane | Missing | No full governance for users, categories, city, campaigns, subscriptions. |
| Dedicated Agent module | Missing | Onboarding and commission workflows absent. |
| Wallet and transaction ledger engine | Missing | Points/cashback/redeem cannot be trusted without ledger integrity. |
| Coupon redemption lifecycle + verification backend | Missing | Prevents safe production use of coupons and QR redemption. |
| Push notification pipeline (FCM + backend events) | Missing | Engagement and operational alerts are incomplete. |
| Rules/policies artifacts and hardened authorization model | Missing/Insufficient | Security and data access model remain high-risk. |
| Production test suite aligned with app architecture | Missing/Weak | Regression and release confidence are limited. |

## 4) Component-Level Priority Order

1. Core data integrity components: ledger, coupon lifecycle, redemption verification.
2. Merchant and admin domain components needed for platform operations.
3. Customer flow completion components: notifications, report processing, profile validation, consistent offers/rewards schema.
4. Security and compliance components: secrets policy, authorization rules, storage/firestore governance.
5. Quality components: tests, monitoring hooks, release gates.

## 5) Development Readiness Decision

- You can start development immediately on missing components.
- Recommended execution style: component-by-component vertical slices, starting with data integrity and merchant/admin foundations.
- Risk note: continuing feature work before finalizing canonical data contracts (offers/coupons/rewards/points) will increase rework.

## 6) Next Deliverable After This Report

If approved, next report will be:
- "Component Execution Plan v1" including for each missing component:
  - Exact target files
  - Required new files
  - Data contract changes
  - Acceptance criteria
  - Effort estimate by day
