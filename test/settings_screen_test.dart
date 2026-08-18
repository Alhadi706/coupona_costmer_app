import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings screen keeps direct deep purple literals out of source', () {
    final String source = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(source, isNot(contains('Colors.deepPurple')));
    expect(source, isNot(contains('Color(0xFF')));
  });
}
