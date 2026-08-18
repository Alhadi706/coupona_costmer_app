import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_cashier_mode_screen_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cashier mode wrapper uses violet full-screen background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KupunaCashierModeScreenWrapper(
          storeName: 'Store X',
          onGrantPoints: () {},
          onRedeemReward: () {},
        ),
      ),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, kViolet);
    expect(find.text('⚡ وضع الكاشير'), findsOneWidget);
    expect(find.text('منح نقاط'), findsOneWidget);
    expect(find.text('تسليم مكافأة'), findsOneWidget);
  });
}
