import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/screens/my_rewards_screen.dart';

void main() {
  testWidgets('Tapping Tier badges opens corresponding Modal BottomSheets', (WidgetTester tester) async {
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

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // 1. Find and tap Bronze Tier badge
    final bronzeFinder = find.text('rewards_tier_bronze_short');
    expect(bronzeFinder, findsOneWidget);
    await tester.tap(bronzeFinder);
    await tester.pumpAndSettle();

    // Verify Bronze BottomSheet title and description
    expect(find.text('تفاصيل النقاط البرونزية (حسب المحل)'), findsOneWidget);
    expect(find.textContaining('النقاط البرونزية محلية وتُستبدل حصراً'), findsOneWidget);

    // Dismiss sheet
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 2. Find and tap Silver Tier badge
    final silverFinder = find.text('rewards_tier_silver_short');
    expect(silverFinder, findsOneWidget);
    await tester.tap(silverFinder);
    await tester.pumpAndSettle();

    // Verify Silver BottomSheet title and description
    expect(find.text('تفاصيل النقاط الفضية (حسب الائتلاف)'), findsOneWidget);
    expect(find.textContaining('النقاط الفضية قابلة للاستبدال لدى جميع المتاجر'), findsOneWidget);

    // Dismiss sheet
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 3. Find and tap Gold Tier badge
    final goldFinder = find.text('rewards_tier_gold_short');
    expect(goldFinder, findsOneWidget);
    await tester.tap(goldFinder);
    await tester.pumpAndSettle();

    // Verify Gold BottomSheet title and conversion action button
    expect(find.text('النقاط الذهبية الشاملة'), findsOneWidget);
    expect(find.text('⚡ استخدام الحاسبة وإنشاء قسيمة نقدية'), findsOneWidget);
  });
}
