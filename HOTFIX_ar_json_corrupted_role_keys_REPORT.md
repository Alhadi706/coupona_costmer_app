# HOTFIX: Arabic Localization Corruption in Role Keys

Date: 2026-08-07
Scope: Emergency localization data fix only. This report is independent and does not mark any design phase as complete.

## 1) Surgical Fix Applied

Updated file:
- [assets/lang/ar.json](assets/lang/ar.json)

Only role-related corrupted values were replaced (same 30 keys requested by user, around lines 364-394).

## 2) Full ar.json Corruption Scan (post-fix)

Pattern used:
- Values matching repeated literal question marks, 2 or more: :\s*"\?{2,}[^"]*"

Result:
- [assets/lang/ar.json](assets/lang/ar.json): OK (no remaining matches)

## 3) Cross-Locale Scan Results (same pattern)

- [assets/lang/bn.json](assets/lang/bn.json): OK
- [assets/lang/de.json](assets/lang/de.json): OK
- [assets/lang/es.json](assets/lang/es.json): OK
- [assets/lang/fr.json](assets/lang/fr.json): OK
- [assets/lang/hi.json](assets/lang/hi.json): OK
- [assets/lang/id.json](assets/lang/id.json): OK
- [assets/lang/it.json](assets/lang/it.json): OK
- [assets/lang/ja.json](assets/lang/ja.json): OK
- [assets/lang/ko.json](assets/lang/ko.json): OK
- [assets/lang/pt.json](assets/lang/pt.json): OK
- [assets/lang/ru.json](assets/lang/ru.json): OK
- [assets/lang/tr.json](assets/lang/tr.json): OK
- [assets/lang/ur.json](assets/lang/ur.json): OK
- [assets/lang/zh.json](assets/lang/zh.json): OK

No additional corrupted values were found in these locale files.

## 4) Validation Commands

### flutter analyze (raw)

Analyzing coupona_app...
No issues found! (ran in 5.6s)

### flutter test

Last line:
- 00:52 +57: All tests passed!

Exact passed test count:
- 57

## 5) Manual Reproduction on localhost:5000

Scenario repeated:
1. Open app on localhost:5000
2. Switch language to Arabic
3. Check top action button that was previously showing ??????

Observed after fix:
- The button text now shows: أدواري
- It no longer shows: ??????

Evidence captured:
- Browser accessibility snapshot showed button label: أدواري
- Screenshot captured during Arabic UI state confirms visible Arabic interface and corrected role button context.
