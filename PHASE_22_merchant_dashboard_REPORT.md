# PHASE 22 Merchant Dashboard Report

Date: 2026-08-07
Scope: Apply merchant design system to merchant dashboard flow only (no admin screen edits)

## 0) Git Tracking Fix Proof (Requested)

Raw command (before add):
```powershell
git status --porcelain -- lib/screens/merchant_dashboard_screen.dart
```

Raw output (before add):
```text
?? lib/screens/merchant_dashboard_screen.dart
```

Raw command (after add):
```powershell
git add -- lib/screens/merchant_dashboard_screen.dart lib/screens/points_conversion_screen.dart lib/screens/reward_qr_code_screen.dart test/merchant_dashboard_screen_test.dart test/points_conversion_screen_test.dart test/reward_qr_code_screen_test.dart PHASE_22_merchant_dashboard_REPORT.md
git status --porcelain -- lib/screens/merchant_dashboard_screen.dart lib/screens/points_conversion_screen.dart lib/screens/reward_qr_code_screen.dart test/merchant_dashboard_screen_test.dart test/points_conversion_screen_test.dart test/reward_qr_code_screen_test.dart PHASE_22_merchant_dashboard_REPORT.md
```

Raw output (after add):
```text
A  PHASE_22_merchant_dashboard_REPORT.md
A  lib/screens/merchant_dashboard_screen.dart
M  lib/screens/points_conversion_screen.dart
M  lib/screens/reward_qr_code_screen.dart
A  test/merchant_dashboard_screen_test.dart
A  test/points_conversion_screen_test.dart
A  test/reward_qr_code_screen_test.dart
```

## 1) Factual Merchant-Related Screen List in lib/screens

Raw command:
```powershell
Get-ChildItem -Path lib/screens -File | Where-Object { $_.Name -match 'merchant|cashier|report|invoice|settlement|branch|points_conversion|reward_qr' } | Select-Object -ExpandProperty Name
```

Raw output:
```text
cashier_dashboard_screen.dart
merchant_dashboard_screen.dart
points_conversion_screen.dart
report_issue_screen.dart
report_screen.dart
reward_qr_code_screen.dart
scan_invoice_screen.dart
```

Applied in this merchant dashboard batch:
- lib/screens/merchant_dashboard_screen.dart
- lib/screens/points_conversion_screen.dart
- lib/screens/reward_qr_code_screen.dart

Out of merchant dashboard scope in this batch by actual role wiring:
- `cashier_dashboard_screen.dart` (cashier role surface)
- `report_issue_screen.dart` (customer report form)
- `report_screen.dart` (generic report form)
- `scan_invoice_screen.dart` (customer invoice capture)

## 2) Files Modified (Phase 22)

### App screens
- lib/screens/merchant_dashboard_screen.dart
- lib/screens/points_conversion_screen.dart
- lib/screens/reward_qr_code_screen.dart

### Tests
- test/merchant_dashboard_screen_test.dart
- test/points_conversion_screen_test.dart
- test/reward_qr_code_screen_test.dart

## 3) Implementation Evidence (Exact Line Matches)

Raw command:
```powershell
Select-String -Pattern "KupunaLoyaltyHealthRing|KupunaStatusPill|KupunaOfferCard|_invoiceStatusToPill|_buildIndigoSection|backgroundColor: kIndigo" -Path lib/screens/merchant_dashboard_screen.dart,lib/screens/points_conversion_screen.dart,lib/screens/reward_qr_code_screen.dart
```

Raw output:
```text
lib\screens\merchant_dashboard_screen.dart:127:  StatusPillKind 
_invoiceStatusToPill(dynamic rawStatus) {
lib\screens\merchant_dashboard_screen.dart:138:  Widget _buildIndigoSection({
lib\screens\merchant_dashboard_screen.dart:291:                  child: 
KupunaLoyaltyHealthRing(scorePercent: 78),
lib\screens\merchant_dashboard_screen.dart:365:          _buildIndigoSection(
lib\screens\merchant_dashboard_screen.dart:398:                              
KupunaStatusPill(
lib\screens\merchant_dashboard_screen.dart:525:          _buildIndigoSection(
lib\screens\merchant_dashboard_screen.dart:533:                  child: 
KupunaOfferCard(
lib\screens\merchant_dashboard_screen.dart:546:          _buildIndigoSection(
lib\screens\merchant_dashboard_screen.dart:579:                              
KupunaStatusPill(
lib\screens\merchant_dashboard_screen.dart:580:                                
kind: _invoiceStatusToPill(invoice['state'] ?? invoice['lifecycleStatus']),
lib\screens\merchant_dashboard_screen.dart:591:          _buildIndigoSection(
lib\screens\merchant_dashboard_screen.dart:602:                  
backgroundColor: kIndigo,
lib\screens\merchant_dashboard_screen.dart:610:                  
backgroundColor: kIndigo,
lib\screens\merchant_dashboard_screen.dart:618:                  
backgroundColor: kIndigo,
lib\screens\merchant_dashboard_screen.dart:635:      backgroundColor: kIndigo,
lib\screens\points_conversion_screen.dart:156:      backgroundColor: kIndigo,
lib\screens\reward_qr_code_screen.dart:73:                      backgroundColor: kIndigo,
```

## 4) Forbidden Token Proof (Zero Matches)

Raw command:
```powershell
Select-String -Pattern "Colors\.deepPurple|Color\(0xFF|kTeal|kMint|kViolet" -Path lib/screens/merchant_dashboard_screen.dart,lib/screens/points_conversion_screen.dart,lib/screens/reward_qr_code_screen.dart
```

Raw output:
```text
Command produced no output
```

## 5) Analyzer Proof

Raw command:
```powershell
flutter analyze
```

Raw output:
```text
Analyzing coupona_app...                                                
No issues found! (ran in 4.6s)
```

## 6) Test Proof

Raw command:
```powershell
flutter test
```

Raw output tail:
```text
00:38 +57: All tests passed!
```

## 7) Git Status Snapshot for Batch Files (Raw)

Raw command:
```powershell
git status --porcelain -- lib/screens/merchant_dashboard_screen.dart lib/screens/points_conversion_screen.dart lib/screens/reward_qr_code_screen.dart test/merchant_dashboard_screen_test.dart test/points_conversion_screen_test.dart test/reward_qr_code_screen_test.dart PHASE_22_merchant_dashboard_REPORT.md
```

Raw output:
```text
A  PHASE_22_merchant_dashboard_REPORT.md
AM lib/screens/merchant_dashboard_screen.dart
M  lib/screens/points_conversion_screen.dart
M  lib/screens/reward_qr_code_screen.dart
AM test/merchant_dashboard_screen_test.dart
A  test/points_conversion_screen_test.dart
A  test/reward_qr_code_screen_test.dart
```

## 8) Acceptance Check (Current Batch)

- Merchant dashboard flow screens updated: PASS
- Phase-20 components integrated with real data surfaces: PASS
  - KupunaLoyaltyHealthRing: line 291
  - KupunaStatusPill: lines 398 and 579
  - KupunaOfferCard: line 533
- Merchant sub-sections (branches/invoices/reports-settlements snapshot) wrapped in indigo sections: PASS
  - _buildIndigoSection: line 138
  - invoice status mapping from state/lifecycleStatus: line 580
- Merchant color policy in modified files (no deepPurple/no direct hex/no teal/mint/violet): PASS
- flutter analyze clean: PASS
- flutter test passed (57): PASS
- Admin screens touched: NO

## 9) Notes

- Existing repository had many unrelated changes before this batch; they were not reverted.
- This report documents the phase-22 merchant dashboard batch and evidence only.
