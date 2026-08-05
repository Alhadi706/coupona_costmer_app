import 'package:flutter_test/flutter_test.dart';

import 'package:coupona_app/foundation/app_logger.dart';

void main() {
  test('Logger handles error payloads without throwing', () {
    expect(() {
      try {
        throw StateError('phase1-audit-error-sample');
      } catch (error, stackTrace) {
        AppLogger.error('Captured exception during audit test', error, stackTrace);
      }
    }, returnsNormally);
  });
}
