# Phase 19 Report - Design System Infrastructure

## Scope Implemented
- Created centralized design tokens file with section 18-a color/radius/spacing/shadow values.
- Created role-based app themes file with 4 themes: customer, merchant/brand, admin, cashier.
- Wired main app theme selection by active role from `AppSession.role()`.
- Added typography helpers for Cairo/IBM Plex Sans Arabic and points-number style.
- Added `test/design_tokens_test.dart` to validate role theme color mapping.

## Files Changed
- `pubspec.yaml`
- `lib/main.dart`
- `lib/theme/design_tokens.dart` (new)
- `lib/theme/app_themes.dart` (new)
- `test/design_tokens_test.dart` (new)

## Decision Log (Required)
- **Typography integration decision:** configured typography through centralized helpers using `fontFamily` mapping (`Cairo`, `IBM Plex Sans Arabic`) inside `design_tokens.dart`.
- **Reason:** direct runtime fetching from Google Fonts caused deterministic CI/test failures in this environment (network/font fetch failures during `flutter test`).
- **Compatibility:** `google_fonts` dependency was still added in `pubspec.yaml` for optional runtime/font evolution in later phases, while current phase keeps tests stable and app build clean.

## Verification Evidence

### 1) flutter analyze
Command:
```powershell
flutter analyze
```
Raw output:
```text
Analyzing coupona_app...
No issues found! (ran in 6.2s)
```

### 2) flutter test
Command:
```powershell
flutter test
```
Raw output (tail):
```text
00:21 +30: All tests passed!
```

### 3) Required token presence check (`lib/theme/*.dart`)
Command:
```powershell
Select-String -Path lib/theme/*.dart -Pattern "kInk|kSand|kWhite|kGold|kTeal|kTealDark|kMint|kIndigo|kIndigoLight|kViolet|kLine|kLineDark" | Out-String
```
Raw output (excerpt):
```text
lib\theme\design_tokens.dart:7:const Color kInk = Color(0xFF16241F);
lib\theme\design_tokens.dart:8:const Color kSand = Color(0xFFF3F1E8);
lib\theme\design_tokens.dart:9:const Color kWhite = Color(0xFFFFFEFB);
lib\theme\design_tokens.dart:10:const Color kGold = Color(0xFFD9A441);
lib\theme\design_tokens.dart:11:const Color kTeal = Color(0xFF1B7A6B);
lib\theme\design_tokens.dart:12:const Color kTealDark = Color(0xFF12594E);
lib\theme\design_tokens.dart:13:const Color kMint = Color(0xFF7FD9C4);
lib\theme\design_tokens.dart:14:const Color kIndigo = Color(0xFF263859);
lib\theme\design_tokens.dart:15:const Color kIndigoLight = Color(0xFF34496E);
lib\theme\design_tokens.dart:16:const Color kViolet = Color(0xFF6C3FA8);
lib\theme\design_tokens.dart:17:const Color kLine = Color.fromRGBO(22, 36, 31, 0.12);
lib\theme\design_tokens.dart:18:const Color kLineDark = Color.fromRGBO(255, 255, 255, 0.12);
```

### 4) Required exact value check (`lib/theme/*.dart`)
Command:
```powershell
Select-String -Path lib/theme/*.dart -Pattern "0xFF16241F|0xFFF3F1E8|0xFFFFFEFB|0xFFD9A441|0xFF1B7A6B|0xFF12594E|0xFF7FD9C4|0xFF263859|0xFF34496E|0xFF6C3FA8|fromRGBO\(22, 36, 31, 0.12\)|fromRGBO\(255, 255, 255, 0.12\)" | Out-String
```
Raw output:
```text
lib\theme\design_tokens.dart:7:const Color kInk = Color(0xFF16241F);
lib\theme\design_tokens.dart:8:const Color kSand = Color(0xFFF3F1E8);
lib\theme\design_tokens.dart:9:const Color kWhite = Color(0xFFFFFEFB);
lib\theme\design_tokens.dart:10:const Color kGold = Color(0xFFD9A441);
lib\theme\design_tokens.dart:11:const Color kTeal = Color(0xFF1B7A6B);
lib\theme\design_tokens.dart:12:const Color kTealDark = Color(0xFF12594E);
lib\theme\design_tokens.dart:13:const Color kMint = Color(0xFF7FD9C4);
lib\theme\design_tokens.dart:14:const Color kIndigo = Color(0xFF263859);
lib\theme\design_tokens.dart:15:const Color kIndigoLight = Color(0xFF34496E);
lib\theme\design_tokens.dart:16:const Color kViolet = Color(0xFF6C3FA8);
lib\theme\design_tokens.dart:17:const Color kLine = Color.fromRGBO(22, 36, 31, 0.12);
lib\theme\design_tokens.dart:18:const Color kLineDark = Color.fromRGBO(255, 255, 255, 0.12);
```

### 5) Main theme wiring check
Command:
```powershell
Select-String -Path lib/main.dart -Pattern "themeForRole|customerTheme|adminTheme|Colors.deepPurple|primarySwatch" | Out-String
```
Raw output:
```text
lib\main.dart:103:      theme: customerTheme,
lib\main.dart:104:      darkTheme: adminTheme,
lib\main.dart:119:          final roleTheme = themeForRole(activeRole);
```

## Phase 19 Status
- Completed and verified with clean analyzer/test runs.
- No backend/state-management/endpoint logic was modified.
- No screen-level redesign outside infrastructure was done in this phase.

## Hotfix: Local Font Asset Registration (Phase 19 Approval Blocker)
- Added local font files under `assets/fonts/` and registered them in `pubspec.yaml` using exact family names already referenced by Dart code:
	- `Cairo` (700/800/900)
	- `IBM Plex Sans Arabic` (300/400/500/600)
- Kept `google_fonts` dependency unchanged as requested, and did not add any `GoogleFonts.*` calls.

Verification snippets:

```text
pubspec.yaml:79:  fonts:
pubspec.yaml:80:    - family: Cairo
pubspec.yaml:82:        - asset: assets/fonts/Cairo-Bold.ttf
pubspec.yaml:84:        - asset: assets/fonts/Cairo-ExtraBold.ttf
pubspec.yaml:86:        - asset: assets/fonts/Cairo-Black.ttf
pubspec.yaml:88:    - family: IBM Plex Sans Arabic
pubspec.yaml:90:        - asset: assets/fonts/IBMPlexSansArabic-Light.ttf
pubspec.yaml:92:        - asset: assets/fonts/IBMPlexSansArabic-Regular.ttf
pubspec.yaml:94:        - asset: assets/fonts/IBMPlexSansArabic-Medium.ttf
pubspec.yaml:96:        - asset: assets/fonts/IBMPlexSansArabic-SemiBold.ttf
```

```text
Name                           Length
----                           ------
Cairo-Black.ttf                 91720
Cairo-Bold.ttf                  91640
Cairo-ExtraBold.ttf             91724
IBMPlexSansArabic-Light.ttf    238564
IBMPlexSansArabic-Medium.ttf   242100
IBMPlexSansArabic-Regular.ttf  235924
IBMPlexSansArabic-SemiBold.ttf 244616
```

```text
flutter analyze -> No issues found! (ran in 6.0s)
flutter test -> 00:18 +30: All tests passed!
```
