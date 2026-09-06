import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/screens/merchant_ads_screen.dart';

void main() {
  Widget buildTestableWidget({
    Future<List<Map<String, dynamic>>> Function()? adsLoader,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MerchantAdsTab(adsLoader: adsLoader),
      ),
    );
  }

  testWidgets('MerchantAdsTab renders Light Theme headers and action buttons', (tester) async {
    await tester.pumpWidget(buildTestableWidget(
      adsLoader: () async => [],
    ));
    await tester.pumpAndSettle();

    expect(find.text('📢 مركز إدارة الحملات والإعلانات'), findsOneWidget);
    expect(find.byKey(const Key('add-banner-btn')), findsOneWidget);
    expect(find.byKey(const Key('launch-campaign-btn')), findsOneWidget);
  });

  testWidgets('MerchantAdsTab displays interactive phone preview container', (tester) async {
    await tester.pumpWidget(buildTestableWidget(
      adsLoader: () async => [
        {
          'id': 'ad-test-1',
          'title': 'عرض خصم 20%',
          'targetLink': 'قسم العصائر',
          'campaign_type': 'BANNER',
          'status': 'active',
          'issued_count': 100,
          'redeemed_count': 10,
          'ends_at': '2026-12-31',
          'audience': 'كافة الزبائن',
        },
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('معاينة تفاعلية للإعلان'), findsOneWidget);
    expect(find.textContaining('عرض خصم 20%'), findsWidgets);
    expect(find.textContaining('قسم العصائر'), findsWidgets);
    expect(find.textContaining('2026-12-31'), findsWidgets);
  });

  testWidgets('MerchantAdsTab renders campaign table with CTR calculation and status toggle', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget(
      adsLoader: () async => [
        {
          'id': 'ad-active',
          'title': 'حملة العيد الفعالة',
          'targetLink': 'الرئيسية',
          'campaign_type': 'BANNER',
          'status': 'active',
          'issued_count': 500,
          'redeemed_count': 25,
          'ends_at': '2026-10-10',
          'audience': 'كافة الزبائن',
        },
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('حملة العيد الفعالة'), findsOneWidget);
    expect(find.text('5.0%'), findsOneWidget); // CTR = (25/500)*100 = 5.0%
    expect(find.text('🟢 نشط'), findsOneWidget);

    // Tap toggle button to pause
    await tester.tap(find.byIcon(Icons.pause_circle_filled));
    await tester.pumpAndSettle();

    expect(find.text('🔴 متوقف'), findsOneWidget);
  });

  testWidgets('Banner modal validates form fields before adding a banner', (tester) async {
    await tester.pumpWidget(buildTestableWidget(
      adsLoader: () async => [],
    ));
    await tester.pumpAndSettle();

    // Open add banner modal
    await tester.tap(find.byKey(const Key('add-banner-btn')));
    await tester.pumpAndSettle();

    expect(find.text('إضافة بانر إعلاني رئيسي جديد'), findsOneWidget);

    // Tap submit without entering title
    await tester.tap(find.byKey(const Key('submit-banner-btn')));
    await tester.pumpAndSettle();

    expect(find.text('يرجى إدخال عنوان الإعلان'), findsOneWidget);

    // Enter title and submit
    await tester.enterText(find.byKey(const Key('banner-title-field')), 'بانر رمضان المبارك');
    await tester.tap(find.byKey(const Key('submit-banner-btn')));
    await tester.pumpAndSettle();

    // Modal closed and new banner added to table
    expect(find.text('بانر رمضان المبارك'), findsWidgets);
  });

  testWidgets('Delete campaign triggers confirmation modal', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableWidget(
      adsLoader: () async => [
        {
          'id': 'ad-delete-me',
          'title': 'حملة مؤقتة للحذف',
          'campaign_type': 'BANNER',
          'status': 'active',
          'issued_count': 10,
          'redeemed_count': 1,
        },
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('حملة مؤقتة للحذف'), findsWidgets);

    // Tap delete icon
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد الحذف'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(find.text('حملة مؤقتة للحذف'), findsNothing);
  });
}
