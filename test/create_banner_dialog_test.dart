import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/dialogs/create_banner_dialog.dart';

void main() {
  Widget buildTestableDialog({
    required ValueChanged<Map<String, dynamic>> onAdd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CreateBannerDialog(onAdd: onAdd),
        ),
      ),
    );
  }

  testWidgets('CreateBannerDialog renders live preview card, image picker zone, and controls', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableDialog(onAdd: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('إضافة بانر إعلاني رئيسي جديد'), findsOneWidget);
    expect(find.textContaining('معاينة تفاعلية للإعلان'), findsOneWidget);
    expect(find.text('اختيار صورة البانر من الجهاز'), findsOneWidget);
    expect(find.byKey(const Key('banner-image-picker-btn')), findsOneWidget);
    expect(find.byKey(const Key('banner-title-field')), findsOneWidget);
    expect(find.byKey(const Key('banner-target-type-dropdown')), findsOneWidget);
    expect(find.byKey(const Key('submit-banner-btn')), findsOneWidget);
  });

  testWidgets('Live preview card updates text in real-time as user types title', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableDialog(onAdd: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('عنوان الإعلان المعاين'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('banner-title-field')), 'حملة الصيف الكبرى');
    await tester.pumpAndSettle();

    expect(find.text('حملة الصيف الكبرى'), findsWidgets);
  });

  testWidgets('Smart destination dropdown switches between category, offer, and external link', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestableDialog(onAdd: (_) {}));
    await tester.pumpAndSettle();

    // Default target type is category, category dropdown visible
    expect(find.byKey(const Key('banner-category-dropdown')), findsOneWidget);

    // Switch to offer
    await tester.tap(find.byKey(const Key('banner-target-type-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عرض / كوبون خاص (Specific Offer)').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner-offer-dropdown')), findsOneWidget);

    // Switch to external web link
    await tester.tap(find.byKey(const Key('banner-target-type-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رابط خارجي (External Web Link)').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner-link-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('banner-link-field')), 'https://example.com/promo');
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/promo'), findsWidgets);
  });

  testWidgets('Form submits successfully with title and selected target link', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? addedBanner;
    await tester.pumpWidget(buildTestableDialog(onAdd: (banner) {
      addedBanner = banner;
    }));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('banner-title-field')), 'خصم 50% نهاية الأسبوع');
    await tester.tap(find.byKey(const Key('submit-banner-btn')));
    await tester.pumpAndSettle();

    expect(addedBanner, isNotNull);
    expect(addedBanner!['title'], equals('خصم 50% نهاية الأسبوع'));
    expect(addedBanner!['targetLink'], equals('قسم العصائر'));
    expect(addedBanner!['campaign_type'], equals('BANNER'));
  });
}
