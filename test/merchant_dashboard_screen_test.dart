import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merchant_dashboard_screen uses phase-20 merchant components', () {
    final source = File('lib/screens/merchant_dashboard_screen.dart').readAsStringSync();

    expect(source.contains('KupunaLoyaltyHealthRing'), isTrue);
    expect(source.contains('KupunaStatusPill'), isTrue);
    expect(source.contains('KupunaOfferCard'), isTrue);
    expect(source.contains('_invoiceStatusToPill'), isTrue);
  });

  test('merchant_dashboard_screen has no direct color literals', () {
    final source = File('lib/screens/merchant_dashboard_screen.dart').readAsStringSync();

    expect(source.contains('Colors.'), isFalse);
    expect(source.contains('Color(0xFF'), isFalse);
  });

  test('merchant_dashboard_screen has no customer role colors', () {
    final source = File('lib/screens/merchant_dashboard_screen.dart').readAsStringSync();

    expect(source.contains('kTeal'), isFalse);
    expect(source.contains('kMint'), isFalse);
    expect(source.contains('kViolet'), isFalse);
  });

  test('merchant_dashboard_screen styles sub-sections with merchant indigo only', () {
    final source = File('lib/screens/merchant_dashboard_screen.dart').readAsStringSync();

    expect(source.contains('_buildIndigoSection'), isTrue);
    expect(source.contains('kIndigoLight'), isTrue);
  });
}
