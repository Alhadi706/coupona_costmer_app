import 'package:coupona_app/widgets/reward_funding_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand moves wallet balance into reward escrow', (tester) async {
    String? fundedType;
    int? fundedAmount;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RewardFundingCard(
      sourceType: 'brand',
      loader: (_) async => <String, dynamic>{'walletBalance': 250, 'escrowBalance': 40},
      funder: (sourceType, amount) async {
        fundedType = sourceType;
        fundedAmount = amount;
        return <String, dynamic>{'walletBalance': 150, 'escrowBalance': 140, 'reference': 'reward_funding:1'};
      },
    ))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wallet: 250'), findsOneWidget);
    expect(find.textContaining('Escrow: 40'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reward-funding-open-brand')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reward-funding-amount')), '100');
    await tester.tap(find.byKey(const Key('reward-funding-confirm')));
    await tester.pumpAndSettle();

    expect(fundedType, 'brand');
    expect(fundedAmount, 100);
    expect(find.textContaining('Wallet: 150'), findsOneWidget);
    expect(find.textContaining('Escrow: 140'), findsOneWidget);
  });

  testWidgets('funding failure preserves displayed balances', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RewardFundingCard(
      sourceType: 'merchant',
      loader: (_) async => <String, dynamic>{'walletBalance': 20, 'escrowBalance': 5},
      funder: (_, __) async => throw StateError('insufficient_reward_funding_balance'),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reward-funding-open-merchant')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reward-funding-amount')), '100');
    await tester.tap(find.byKey(const Key('reward-funding-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wallet: 20'), findsOneWidget);
    expect(find.textContaining('Escrow: 5'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}