import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category offers screen uses offer card and no direct deep purple literals', () {
    final String source = File('lib/screens/category_offers_screen.dart').readAsStringSync();

    expect(source, contains('KupunaOfferCard'));
    expect(source, isNot(contains('Colors.deepPurple')));
    expect(source, isNot(contains('Color(0xFF')));
  });
}
