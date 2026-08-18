import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full map screen keeps direct deep purple literals out of source', () {
    final String source = File('lib/screens/full_map_screen.dart').readAsStringSync();

    expect(source, isNot(contains('Colors.deepPurple')));
    expect(source, isNot(contains('Color(0xFF')));
  });
}
