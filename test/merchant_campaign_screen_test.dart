import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/screens/merchant_campaign_screen.dart';

void main() {
  Widget buildTestableWidget({
    String? partnerMerchantId,
    String? partnerMerchantName,
  }) {
    return MaterialApp(
      home: MerchantCampaignScreen(
        partnerMerchantId: partnerMerchantId,
        partnerMerchantName: partnerMerchantName,
      ),
    );
  }

  testWidgets('MerchantCampaignScreen renders 3-Step Wizard layout and Step 1 initially', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Wizard Stepper Header
    expect(find.text('معالج إطلاق الحملات المستهدفة'), findsOneWidget);
    expect(find.text('1. الجمهور المستهدف'), findsOneWidget);
    expect(find.text('2. الهدية والخصم'), findsOneWidget);
    expect(find.text('3. التوقيت والمعاينة'), findsOneWidget);

    // Verify Step 1 Content
    expect(find.text('👥 الخطوة 1: اختر الزبائن المستهدفين'), findsOneWidget);
    expect(find.textContaining('الزبائن الأكثر شراءً'), findsOneWidget);
    expect(find.textContaining('الزبائن الغائبون'), findsOneWidget);
    expect(find.textContaining('الزبائن الأكثر زيارة'), findsOneWidget);
    expect(find.textContaining('جميع عملاء المتجر'), findsOneWidget);
    expect(find.textContaining('عملاء محددون يدويًا'), findsOneWidget);

    // Verify Bottom Navigation Next button
    expect(find.text('التالي'), findsOneWidget);
  });

  testWidgets('MerchantCampaignScreen navigates through Steps 1, 2, and 3', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 500));

    // Move to Step 2
    await tester.tap(find.text('التالي'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('🎁 الخطوة 2: حدد الخصم أو الهدية'), findsOneWidget);
    expect(find.text('اسم الحملة'), findsOneWidget);
    expect(find.text('خصم VIP %'), findsOneWidget);
    expect(find.text('تذاكر سحب مؤهلة'), findsOneWidget);
    expect(find.text('السابق'), findsOneWidget);

    // Move to Step 3
    await tester.tap(find.text('التالي'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('📱 الخطوة 3: التوقيت ومعاينة الإشعار'), findsOneWidget);
    expect(find.text('📱 معاينة هاتف الزبون'), findsOneWidget);
    expect(find.text('🚀 إطلاق الحملة الآن'), findsOneWidget);

    // Move back to Step 2
    await tester.tap(find.text('السابق'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('🎁 الخطوة 2: حدد الخصم أو الهدية'), findsOneWidget);
  });

  testWidgets('MerchantCampaignScreen switches live mobile preview between Notification and In-App Voucher', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pump(const Duration(milliseconds: 500));

    // Jump directly to Step 3
    await tester.tap(find.text('3. التوقيت والمعاينة'));
    await tester.pump(const Duration(milliseconds: 300));

    // Initially on Notification tab
    expect(find.textContaining('كوبونا • الآن'), findsOneWidget);
    expect(find.textContaining('🔔 مكافأة خاصة حصرياً لك!'), findsOneWidget);

    // Switch to Voucher Card tab
    await tester.tap(find.text('كارت الهدية'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('VIP EXCLUSIVE'), findsOneWidget);
    expect(find.text('استخدام العرض'), findsOneWidget);
  });

  testWidgets('MerchantCampaignScreen opens Launch Summary dialog before sending', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget(partnerMerchantName: 'متجر الياسمين'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify support campaign banner
    expect(find.text('حملة دعم مشتركة'), findsOneWidget);
    expect(find.textContaining('متجر الياسمين'), findsOneWidget);

    // Navigate to Step 3
    await tester.tap(find.text('3. التوقيت والمعاينة'));
    await tester.pump(const Duration(milliseconds: 300));

    // Click Launch
    await tester.tap(find.text('🚀 إطلاق الحملة الآن'));
    await tester.pump(const Duration(milliseconds: 300));

    // Confirmation dialog should pop up
    expect(find.text('تأكيد إطلاق الحملة'), findsOneWidget);
    expect(find.text('تأكيد الإطلاق الآن'), findsOneWidget);
    expect(find.text('تعديل الإعدادات'), findsOneWidget);
  });
}
