# HOTFIX Correction Directive v1 Report

## Scope

This report closes the five items in `Kupuna Correction Directive v1` and is independent from phase progression.

## 1) Discover tab map/category regression fixed

Implemented in `lib/screens/home_content_screen.dart`:

- Kept the existing 3-tab structure and 5-item bottom navigation unchanged.
- Rebuilt content inside existing `Discover` tab only.
- Added horizontal category filters (`ChoiceChip`) with `All categories` support.
- Added list/map display switch (`SegmentedButton`):
  - `List` mode: nearby stores cards with category + distance.
  - `Map` mode: live map with store pins.
- Added nearest-first sorting by customer profile location:
  - Reads persisted coordinates from `/api/customer/location/me`.
  - Updates location with current device location when available.

Supporting backend/client additions:

- `GET /api/customer/location/me`
- `POST /api/customer/location/me`
- `CompanyServerService.getMyCustomerLocation()`
- `CompanyServerService.updateMyCustomerLocation()`

## 2) Branch manager 404 (`branches//managers`) fixed

Backend hardening in `backend/server.js`:

- `POST /api/merchant/branches` now validates:
  - `name` required.
  - `latitude` + `longitude` required.
- Branch creation now returns `201 Created` with branch ID and coordinates.
- `POST /api/merchant/branches/:id/managers` now rejects empty `branchId` with explicit `400 branchId_required`.

Branch schema/migrations in bootstrap:

- Added branch geolocation fields:
  - `branches.latitude DOUBLE PRECISION`
  - `branches.longitude DOUBLE PRECISION`

Merchant UI flow in `lib/screens/merchant_dashboard_screen.dart`:

- Branch creation requires location selection before save.
- Map picker integration blocks progression until successful save.
- On success, returned `branchId` is injected into manager/cashier forms.
- Manager assignment validates branch/user IDs before calling API.

Map search + manual pin support in `lib/screens/map_picker_screen.dart`:

- Manual pin selection kept.
- Added address search (Nominatim lookup) for typed location picking.

## 3) Cashier localization expanded

Localized cashier surfaces:

- `lib/screens/cashier_dashboard_screen.dart`
- `lib/widgets/design_system/kupuna_cashier_mode_screen_wrapper.dart`

All visible cashier text now routes through localization keys with fallback-safe behavior for tests.

Added cashier keys in both:

- `assets/lang/ar.json`
- `assets/lang/en.json`

## 4) Analytics screen expanded beyond loyalty-only

Extended merchant analytics in `lib/screens/merchant_dashboard_screen.dart` to include the requested coverage blocks:

- Sales/points metrics.
- Customer metrics (unique/new/returning/retention/churn).
- Offer metrics.
- Peak times (hour/day).
- Group metrics.
- Top brand-product signal (category signal from available data).
- Financial summary snapshot.
- Branch/time filtering and export actions (PDF/Excel trigger flow).

Data sources used from existing stack:

- invoices, offers, branches, groups, top customers, loyalty/profile point values.

## 5) Central notifications + community badge

Backend notification model/path updates in `backend/server.js`:

- Added `target_screen` column support in `notifications`.
- Exposed `targetScreen` in `/api/notifications/my` payload.
- Normalized community message type to `group_message` for badge filtering.

Client updates:

- Added notification APIs in `lib/services/company_server_service.dart`:
  - `getMyNotifications()`
  - `markNotificationRead()`

Home shell updates in `lib/screens/home_screen.dart`:

- Added top app-bar bell icon for all role surfaces rendered through HomeScreen.
- Red unread indicator shown when at least one unread notification exists.
- Bottom-nav Communities icon now shows unread numeric badge for unread `group_message` notifications.
- Bell opens a notification list sorted by server time order and marks entries as read on open/tap.

## Validation

Static checks:

```text
flutter analyze
No issues found! (ran in 12.7s)
```

Full tests:

```text
flutter test --reporter compact
01:03 +64: All tests passed!
```

Focused checks run during implementation:

- `test/customer_home_hotfix_test.dart` passed.
- `test/cashier_dashboard_screen_test.dart` passed.
- `test/design_system/kupuna_cashier_mode_screen_wrapper_test.dart` passed.

## Notes

- Existing test logs still show expected EasyLocalization warnings in widget tests that mount bare `MaterialApp` without full localization bootstrap; this behavior is unchanged and non-blocking.
- No new tab was added and no new bottom-navigation item was added; all Discover enhancements were implemented inside the existing Discover tab as required.
