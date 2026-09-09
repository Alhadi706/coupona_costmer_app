import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full map screen keeps direct deep purple literals out of source', () {
    final String source = File('lib/screens/full_map_screen.dart').readAsStringSync();

    expect(source, isNot(contains('Colors.deepPurple')));
    expect(source, isNot(contains('Color(0xFF')));
  });

  test('map store details localization keys exist in ar and en lang files', () {
    final arJson = jsonDecode(File('assets/lang/ar.json').readAsStringSync()) as Map<String, dynamic>;
    final enJson = jsonDecode(File('assets/lang/en.json').readAsStringSync()) as Map<String, dynamic>;

    const requiredKeys = [
      'store_offers_count',
      'store_rewards_count',
      'store_products_count',
      'store_directions',
      'store_open_page',
    ];

    for (final key in requiredKeys) {
      expect(arJson.containsKey(key), isTrue, reason: 'ar.json should contain $key');
      expect(enJson.containsKey(key), isTrue, reason: 'en.json should contain $key');
    }

    expect(arJson['store_offers_count'], contains('{count}'));
    expect(arJson['store_rewards_count'], contains('{count}'));
    expect(arJson['store_products_count'], contains('{count}'));
    expect(arJson['store_directions'], 'الاتجاهات');
    expect(arJson['store_open_page'], 'زيارة المتجر');
  });
}
