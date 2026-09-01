import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merchant coalition service exposes the coalition API contract', () {
    final source = File('lib/services/company_server_service.dart').readAsStringSync();

    expect(source.contains('getMerchantCoalitions('), isTrue);
    expect(source.contains('getMerchantCoalitionsMine('), isTrue);
    expect(source.contains('getMerchantCoalitionInvitations('), isTrue);
    expect(source.contains('createMerchantCoalition('), isTrue);
    expect(source.contains('getMerchantCoalitionLedger('), isTrue);
    expect(source.contains('getMerchantCoalitionClearinghouse('), isTrue);
  });

  test('coalition screens exist with the expected dashboard and settling views', () {
    expect(File('lib/screens/coalitions/coalition_dashboard_screen.dart').existsSync(), isTrue);
    expect(File('lib/screens/coalitions/create_private_coalition_dialog.dart').existsSync(), isTrue);
    expect(File('lib/screens/coalitions/coalition_clearinghouse_screen.dart').existsSync(), isTrue);
  });
}
