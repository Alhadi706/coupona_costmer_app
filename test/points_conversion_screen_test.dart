import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('points_conversion_screen avoids forbidden direct colors', () {
    final source = File('lib/screens/points_conversion_screen.dart').readAsStringSync();

    expect(source.contains('Colors.deepPurple'), isFalse);
    expect(source.contains('Color(0xFF'), isFalse);
  });

  test('points_conversion_screen has no mixed role palette', () {
    final source = File('lib/screens/points_conversion_screen.dart').readAsStringSync();

    expect(source.contains('kTeal'), isFalse);
    expect(source.contains('kMint'), isFalse);
    expect(source.contains('kViolet'), isFalse);
  });
}
