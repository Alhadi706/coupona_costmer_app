import 'package:coupona_app/widgets/design_system/kupuna_dual_wallet_rings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dual wallet rings renders center number and legend', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KupunaDualWalletRings(
            merchantPoints: 300,
            brandPoints: 100,
          ),
        ),
      ),
    );

    expect(find.text('400'), findsOneWidget);
    expect(find.textContaining('تجار'), findsOneWidget);
    expect(find.textContaining('علامات'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KupunaDualWalletRings),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
