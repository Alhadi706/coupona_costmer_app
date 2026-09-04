import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/screens/merchant_campaign_screen.dart';

void main() {
  Widget buildTestableWidget() {
    return const MaterialApp(
      home: MerchantCampaignScreen(),
    );
  }

  testWidgets('MerchantCampaignScreen opens in Step 1 (Audience Selection)', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('الخطوة 1 من 3'), findsOneWidget);
    expect(find.textContaining('اختر الشريحة المستهدفة'), findsOneWidget);
    expect(find.textContaining('الزبائن الأكثر شراءً'), findsOneWidget);
    expect(find.textContaining('الزبائن الغائبون'), findsOneWidget);
    expect(find.textContaining('الأكثر زيارة'), findsOneWidget);
  });

  testWidgets('MerchantCampaignScreen wizard navigation Step 1 -> Step 2 -> Step 3', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 400));

    // Step 1: Audience -> Next
    final nextBtn = find.text('التالي');
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pump(const Duration(milliseconds: 400));

    // Step 2: Reward & Budget
    expect(find.textContaining('الخطوة 2 من 3'), findsOneWidget);
    expect(find.textContaining('حدد نوع المكافأة والميزانية'), findsOneWidget);
    expect(find.textContaining('اسم الحملة'), findsOneWidget);
    expect(find.textContaining('نسبة الخصم %'), findsOneWidget);

    // Step 2 -> Next
    await tester.tap(nextBtn);
    await tester.pump(const Duration(milliseconds: 400));

    // Step 3: Schedule & Live Phone Preview
    expect(find.textContaining('الخطوة 3 من 3'), findsOneWidget);
    expect(find.textContaining('التوقيت وطريقة الإطلاق'), findsOneWidget);
    expect(find.textContaining('معاينة الإشعار في هاتف الزبون'), findsOneWidget);
    expect(find.textContaining('🚀 إطلاق الحملة الآن'), findsOneWidget);
  });

  testWidgets('MerchantCampaignScreen allows step navigation back to Step 1', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 400));

    // Step 1 -> Step 2
    await tester.tap(find.text('التالي'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('الخطوة 2 من 3'), findsOneWidget);

    // Step 2 -> Previous -> Step 1
    final prevBtn = find.text('السابق');
    expect(prevBtn, findsOneWidget);
    await tester.tap(prevBtn);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('الخطوة 1 من 3'), findsOneWidget);
  });
}
