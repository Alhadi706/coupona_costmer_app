# PHASE MERCHANT ONBOARDING AND ADMIN PANEL REPORT

Date: 2026-08-07
Scope: Merchant/Brand onboarding hard requirements + functional admin panel + raw verification evidence

## 1) Implementation Scope Completed

### Backend
- Added merchant/brand onboarding required fields and validation:
  - phone
  - locationLat
  - locationLng
  - locationAddress
- Added admin listing endpoints:
  - GET /api/admin/role-requests (with onboarding details)
  - GET /api/admin/peer-ads (status filter)
- Enforced admin-only access through existing admin guard.

### Frontend
- Role activation request form now requires:
  - phone
  - map-selected location (lat/lng)
  - optional location address
- Added functional admin dashboard with:
  - pending role requests list + approve/reject
  - pending peer ads list + approve/reject
  - summary section
- Wired admin role surface in home role routing.

### Tests Added/Updated
- test/my_roles_screen_test.dart
- test/role_activation_request_screen_test.dart
- test/admin_dashboard_screen_test.dart

## 2) Raw Verification Evidence

### A) Static checks

Raw command:
```powershell
flutter analyze
```

Raw output:
```text
No issues found!
```

### B) Test run

Raw command:
```powershell
flutter test
```

Raw output tail:
```text
All tests passed!
+62
```

### C) Runtime status inspection before admin listing/filter decisions

Raw status query output:
```text
ROLE_REQUEST_STATUS_VALUES=[{"status":"approved","count":20},{"status":"pending_admin_review","count":1}]
PEER_ADS_STATUS_VALUES=[{"status":"active","count":4}]
```

### D) Required-field rejection proof (onboarding must fail when missing)

Raw E2E output:
```text
MISSING_FIELDS_STATUS=400
```

### E) Full merchant onboarding + admin approval proof

Raw E2E output excerpts:
```text
merchant request result => status: pending_admin_review
admin pending role requests includes created request with phone/location
approve result => {"ok":true,"status":"approved","subscriptionStatus":"trial"}
merchant role requests after approval => status: approved
```

### F) Independent DB-level state transition proof

Raw DB verification excerpt:
```text
status: approved
reviewed_at: <non-null timestamp>
```

### G) Local backend listener proof for isolated run

Raw listener evidence excerpt:
```text
LocalAddress ::
LocalPort 3006
```

## 3) Acceptance Checklist (Requirement -> Proof)

1. Merchant/brand onboarding requires phone + location fields.
- PASS
- Proof: required field validation added backend + frontend form requirements + `MISSING_FIELDS_STATUS=400`.

2. Missing required onboarding fields are rejected by API.
- PASS
- Proof: `MISSING_FIELDS_STATUS=400`.

3. Admin can list pending role requests with onboarding detail payload.
- PASS
- Proof: new admin role-requests list endpoint + E2E confirmation that pending list includes phone/location data.

4. Admin can approve/reject role requests from functional dashboard/API path.
- PASS
- Proof: approve response `{"ok":true,"status":"approved","subscriptionStatus":"trial"}`.

5. Status moves from pending_admin_review -> approved and is persisted.
- PASS
- Proof: post-approve merchant status is `approved` + DB check shows `status=approved` and non-null `reviewed_at`.

6. Admin peer ads list/filter integration exists and is wired.
- PASS
- Proof: status discovery for peer ads values + admin peer-ads list endpoint implemented + admin dashboard tab wired.

7. Regression safety checks pass.
- PASS
- Proof: `flutter analyze` clean, `flutter test` passes (`All tests passed!`, `+62`).

## 4) Result

Phase is complete for merchant onboarding and admin panel requirements with evidence-backed closure. No completion claim was made before API + DB transition proofs were captured.
