import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/screens/my_rewards_screen.dart';

void main() {
  testWidgets('MyRewardsScreen renders top banner, dynamic cash card, and category filter chips', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MyRewardsScreen.embedded(),
          ),
        ),
      ),
    );

    // Pump past timeouts
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify presence of Dynamic Cash Calculator banner text
    expect(find.text('تحويل النقاط إلى خصم مالي مباشر'), findsOneWidget);

    // Verify category filter chips are present
    expect(find.text('الكل'), findsOneWidget);
    expect(find.text('مطاعم'), findsOneWidget);
    expect(find.text('مواد غذائية'), findsOneWidget);
    expect(find.text('غسيل سيارات'), findsOneWidget);
    expect(find.text('صيدليات'), findsOneWidget);
    expect(find.text('ملابس'), findsOneWidget);
  });
}
