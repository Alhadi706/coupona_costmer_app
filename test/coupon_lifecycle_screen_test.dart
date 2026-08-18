import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coupon lifecycle screen uses status pill and no direct deep purple literals', () {
    final String source = File('lib/screens/coupon_lifecycle_screen.dart').readAsStringSync();

    expect(source, contains('KupunaStatusPill'));
    expect(source, isNot(contains('Colors.deepPurple')));
    expect(source, isNot(contains('Color(0xFF')));
  });
}
