import 'package:flutter_test/flutter_test.dart';

import 'package:coupona_app/modules/accounting/accounting_rules.dart';

void main() {
  group('AccountingRules', () {
    test('normalizeAmount returns two decimal precision', () {
      expect(AccountingRules.normalizeAmount(120.127), 120.13);
    });

    test('calculateCashback returns 5 percent', () {
      expect(AccountingRules.calculateCashback(200), 10.0);
    });

    test('calculatePoints floors to integer points', () {
      expect(AccountingRules.calculatePoints(99.9), 99);
    });

    test('normalizeAmount throws on non-positive values', () {
      expect(() => AccountingRules.normalizeAmount(0), throwsFormatException);
      expect(() => AccountingRules.normalizeAmount(-2), throwsFormatException);
    });

    test('validateRedemption enforces available points', () {
      expect(
        () => AccountingRules.validateRedemption(
          requestedPoints: 50,
          availablePoints: 30,
        ),
        throwsFormatException,
      );
    });

    test('validateRedemption passes on valid request', () {
      expect(
        () => AccountingRules.validateRedemption(
          requestedPoints: 10,
          availablePoints: 30,
        ),
        returnsNormally,
      );
    });
  });
}
