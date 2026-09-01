import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer direct gifting service exposes merchant trigger and gift dispatch APIs', () {
    final source = File('lib/services/company_server_service.dart').readAsStringSync();

    expect(source.contains('createMerchantGiftTrigger('), isTrue);
    expect(source.contains('dispatchDirectGift('), isTrue);
    expect(source.contains('getGiftVoucherOptions('), isTrue);
    expect(source.contains('showCoBrandedRewardDialog'), isTrue);
    expect(source.contains('showGiftSelectionDialog'), isTrue);
  });

  test('direct gifting screens exist for merchant triggers and customer thank-you modal', () {
    expect(File('lib/screens/merchant_gift_trigger.dart').existsSync(), isTrue);
    expect(File('lib/screens/co_branded_reward_dialog.dart').existsSync(), isTrue);
  });
}
