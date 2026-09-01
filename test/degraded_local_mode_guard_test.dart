import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local mode fallback is modeled in the service contract', () {
    final source = File('lib/services/company_server_service.dart').readAsStringSync();

    expect(source.contains('checkMerchantTokenBalance('), isTrue);
    expect(source.contains('recordLocalOnlyPoints('), isTrue);
    expect(source.contains('redeemLocalOnlyPoints('), isTrue);
    expect(source.contains('rechargeMerchantTokens('), isTrue);
  });

  test('degraded guard screen exists for the merchant receipt/local mode banner', () {
    expect(File('lib/screens/degraded_local_mode_guard.dart').existsSync(), isTrue);
  });
}
