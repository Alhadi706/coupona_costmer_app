import 'package:coupona_app/screens/my_rewards_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claim timeline entry is skipped when unified ledger reference exists', () {
    const claim = <String, dynamic>{
      'id': 'claim-1',
      'reference': 'reward_claim:claim-1',
      'pointsCost': 100,
    };
    const ledger = <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'rewardClaimCreated',
        'points': -100,
        'reference': 'reward_claim:claim-1',
      },
    ];

    expect(shouldAddClaimTransaction(claim, ledger), isFalse);
  });

  test('legacy claim remains visible when no unified ledger reference exists', () {
    const claim = <String, dynamic>{'id': 'legacy-claim', 'pointsCost': 50};
    const ledger = <Map<String, dynamic>>[];

    expect(shouldAddClaimTransaction(claim, ledger), isTrue);
  });
}