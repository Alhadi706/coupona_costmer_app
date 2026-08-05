import 'package:flutter_test/flutter_test.dart';

import 'package:coupona_app/foundation/foundation_verifier.dart';

void main() {
  test('Foundation report is stable when required checks pass', () {
    final FoundationVerificationReport report = FoundationVerificationReport(
      serverOnlyMode: true,
      localizationAssetsReady: true,
      preferencesReady: true,
    );

    expect(report.isStable, isTrue);
  });

  test('Foundation report is unstable when required checks fail', () {
    final FoundationVerificationReport report = FoundationVerificationReport(
      serverOnlyMode: true,
      localizationAssetsReady: false,
      preferencesReady: true,
    );

    expect(report.isStable, isFalse);
  });
}
