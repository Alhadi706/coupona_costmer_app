import 'package:coupona_app/screens/cashier_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cashier dashboard uses cashier mode wrapper surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CashierDashboardScreen(),
      ),
    );

    expect(find.text('⚡ وضع الكاشير'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
