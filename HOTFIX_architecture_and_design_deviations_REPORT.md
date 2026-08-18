# Architecture and Design Deviations Hotfix Report

## Scope and status

This is a standalone hotfix report. It is not a phase-completion claim and does not authorize work on a later phase.

The four mandatory corrections are implemented:

1. Cashier is no longer a self-activatable independent role.
2. Admin membership approval/rejection works end to end.
3. Customer home follows the required banner, three-tab, five-navigation-item structure.
4. Merchant, brand, and admin user-facing strings use localization keys.

## 1. My Roles and cashier architecture

### Exact screen description

`My Roles` renders Customer, Merchant, and Brand as role cards. It does not render a generic Cashier role card and exposes no cashier request or self-activation action.

Cashier appears in a separate read-only `Cashier association` section:

- With no assignment, it displays `Not assigned as cashier yet.`
- Existing assignments show merchant ID, branch ID, and localized active/inactive status.
- `Switch` is available only when the backend already returns an association with `isActive == true`.
- The customer cannot create or request that association from this screen.

Cashier creation/binding remains merchant-owned through `POST /api/merchant/cashiers/bind` and persisted in `cashier_profiles`.

### Reproducible checks

```powershell
Select-String -Path lib\screens\my_roles_screen.dart -Pattern "_buildCashierAssociationCard|role_cashier_not_assigned|isActive"

$pattern = 'activate_cashier|requestCashier|roles/cashier/request|cashier.*request|request.*cashier'
$matches = Get-ChildItem lib,backend -Recurse -File |
  Where-Object { $_.FullName -notmatch '\\node_modules\\' } |
  Select-String -Pattern $pattern
if ($matches) { $matches } else { 'NO MATCHES' }
```

Observed self-activation result:

```text
NO MATCHES
```

## 2. Admin membership approval end to end

### Reproduction steps

1. Start the backend used by the proof on port `3006`.
2. Run `backend\phase_merchant_onboarding_admin_panel_proof.ps1`.
3. Register a customer account.
4. Sign in as that customer and submit a Merchant request with business name, commercial registration, phone, location, and plan.
5. Sign in as the proof-run admin account:
   - Email: `admin.20260807151934763.655199@kupuna.test`
   - Password: `Test1234!`
6. Open Admin Dashboard, then Membership Requests.
7. Locate the `pending_admin_review` request and select Approve. Reject is available on the same list for other pending requests.
8. Return to the customer account and reload My Roles.
9. Confirm the Merchant request is approved/active, switch to Merchant, and enter the Merchant dashboard.

The credentials above belong to a generated proof-run test account, not a static production seed.

### Recorded proof

The deterministic output is stored in `backend/phase_merchant_onboarding_admin_panel_proof_output.txt`.

```text
FULL_REQUEST_STATUS=200
FULL_REQUEST_BODY={"ok":true,"requestId":"15eaeefa-ca9e-4737-96d4-cfe3023ee290","status":"pending_admin_review"}
APPROVE_STATUS=200
APPROVE_BODY={"ok":true,"status":"approved","subscriptionStatus":"trial"}
MY_REQUESTS_STATUS=200
MY_REQUESTS_BODY=[{"id":"15eaeefa-ca9e-4737-96d4-cfe3023ee290","roleType":"merchant","status":"approved",...}]
DB_VERIFICATION=[{"status":"approved","reviewed_at":"2026-08-07T15:19:38.326Z"}]
```

The approval endpoint runs in one database transaction. It marks the request `approved`, updates the corresponding merchant or brand profile to `active`, inserts a `trial` subscription, and commits. Reject marks both request and profile `rejected`.

## 3. Rebuilt customer home

The customer home now contains, in display order:

1. A teal brand banner with three messages, a next action, and `1/3` through `3/3` position text.
2. Search.
3. Exactly three top tabs: Discover, Offers, Peer Ads.
4. Offer cards with the existing Brand and Peer source badges.
5. Exactly five fixed bottom-navigation items: Home, Wallet, Communities, Reports, My Account.

The former category section and category navigation entry are absent.

### Executable UI evidence

`test/customer_home_hotfix_test.dart` verifies the exact five-item navigation order, the exact three-tab model, and banner advancement from `1/3` to `2/3`.

```powershell
flutter test test\customer_home_hotfix_test.dart --reporter compact
```

Observed result:

```text
00:07 +2: All tests passed!
```

The app was also launched successfully at `http://localhost:5051/`; the integrated-browser capture reached the live Flutter application. Authentication-dependent home capture is represented by the deterministic widget test above so the required composition is reproducible without relying on a retained browser session.

## 4. Violet audit

Command:

```powershell
$pattern = 'deepPurple|kViolet|0xFF(7C3AED|6D28D9|8B5CF6)|Colors\.purple'
Get-ChildItem lib -Recurse -File | Select-String -Pattern $pattern
```

Complete result:

```text
lib\theme\app_themes.dart:165:scaffold: kViolet,
lib\theme\app_themes.dart:166:surface: kViolet,
lib\theme\app_themes.dart:167:primary: kViolet,
lib\theme\design_tokens.dart:16:const Color kViolet = Color(0xFF6C3FA8);
lib\widgets\design_system\kupuna_cashier_mode_screen_wrapper.dart:22:backgroundColor: kViolet,
```

Conclusion: violet exists only as the shared token, the cashier theme mapping, and the cashier full-screen wrapper. No non-cashier screen uses violet.

## 5. Localization audit

Merchant, brand, and admin dashboard user-facing labels, validation messages, status text, actions, summaries, permission controls, offer/invoice labels, and product registry text now resolve through `easy_localization` keys in both `assets/lang/ar.json` and `assets/lang/en.json`.

Role request lifecycle values are mapped to localized display labels instead of exposing raw values such as `pending_admin_review`.

## 6. Final Flutter verification

Raw outputs are retained at:

- `flutter_analyze_hotfix_output.txt`
- `flutter_test_hotfix_output.txt`

Analyzer final output:

```text
Analyzing coupona_app...
No issues found! (ran in 6.2s)
```

Full test-suite final line after adding the two focused home tests:

```text
01:08 +64: All tests passed!
```

## Explicit close

All four hotfix correction areas are implemented and independently checked. This report closes only `HOTFIX_architecture_and_design_deviations`; it does not claim completion of any numbered phase, and no subsequent phase was started as part of this work.
