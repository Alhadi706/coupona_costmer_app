import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/dialogs/create_banner_dialog.dart';

void main() {
  Uint8List testPngBytes() => Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  Widget buildTestableDialog({
    required ValueChanged<Map<String, dynamic>> onAdd,
    BannerAdSubmitter? submitter,
    BannerImagePicker? imagePicker,
    BannerImageUploader? imageUploader,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CreateBannerDialog(
            onAdd: onAdd,
            submitter: submitter,
            imagePicker: imagePicker,
            imageUploader: imageUploader,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'CreateBannerDialog renders live preview card, image picker zone, and controls',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableDialog(onAdd: (_) {}, submitter: (_) async {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة بانر إعلاني رئيسي جديد'), findsOneWidget);
      expect(find.textContaining('معاينة تفاعلية للإعلان'), findsOneWidget);
      expect(find.text('اختيار صورة البانر من الجهاز'), findsOneWidget);
      expect(find.byKey(const Key('banner-image-picker-btn')), findsOneWidget);
      expect(find.byKey(const Key('banner-title-field')), findsOneWidget);
      expect(
        find.byKey(const Key('banner-target-type-dropdown')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('submit-banner-btn')), findsOneWidget);
    },
  );

  testWidgets(
    'Live preview card updates text in real-time as user types title',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableDialog(onAdd: (_) {}, submitter: (_) async {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('عنوان الإعلان المعاين'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('banner-title-field')),
        'حملة الصيف الكبرى',
      );
      await tester.pumpAndSettle();

      expect(find.text('حملة الصيف الكبرى'), findsWidgets);
    },
  );

  testWidgets(
    'Smart destination dropdown switches between category, offer, and external link',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableDialog(onAdd: (_) {}, submitter: (_) async {}),
      );
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
      await tester.enterText(
        find.byKey(const Key('banner-link-field')),
        'https://example.com/promo',
      );
      await tester.pumpAndSettle();
      expect(find.text('https://example.com/promo'), findsWidgets);
    },
  );

  testWidgets('Form rejects a billboard without an image', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? addedBanner;
    Map<String, dynamic>? submittedPayload;
    await tester.pumpWidget(
      buildTestableDialog(
        onAdd: (banner) {
          addedBanner = banner;
        },
        submitter: (payload) async {
          submittedPayload = payload;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('banner-title-field')),
      'خصم 50% نهاية الأسبوع',
    );
    await tester.tap(find.byKey(const Key('submit-banner-btn')));
    await tester.pumpAndSettle();

    expect(find.text('يرجى اختيار صورة البانر أولاً'), findsOneWidget);
    expect(addedBanner, isNull);
    expect(submittedPayload, isNull);
  });

  testWidgets('Picked image bytes render immediately in the live preview', (
    tester,
  ) async {
    final pngBytes = testPngBytes();
    await tester.pumpWidget(
      buildTestableDialog(
        onAdd: (_) {},
        imagePicker: () async => BannerImageSelection(
          pngBytes,
          mimeType: 'image/png',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('banner-image-picker-btn')));
    await tester.pump();

    final preview = tester.widget<Image>(
      find.byKey(const Key('banner-live-preview-image')),
    );
    expect(preview.image, isA<MemoryImage>());
  });

  testWidgets('Successful launch shows confirmation and pending review item', (
    tester,
  ) async {
    Map<String, dynamic>? addedBanner;
    Map<String, dynamic>? submittedPayload;
    await tester.pumpWidget(
      buildTestableDialog(
        onAdd: (banner) => addedBanner = banner,
        imagePicker: () async => BannerImageSelection(
          testPngBytes(),
          mimeType: 'image/png',
        ),
        imageUploader: (_, __) async => '/api/uploads/banner.jpg',
        submitter: (payload) async => submittedPayload = payload,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('banner-title-field')),
      'بانر جديد',
    );
    await tester.tap(find.byKey(const Key('banner-image-picker-btn')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('submit-banner-btn')));
    await tester.tap(find.byKey(const Key('submit-banner-btn')));
    await tester.pumpAndSettle();

    expect(submittedPayload?['imageUrl'], '/api/uploads/banner.jpg');
    expect(addedBanner?['status'], 'pending_review');
    expect(find.text('تم إرسال الإعلان بنجاح!'), findsOneWidget);
    expect(
      find.text(
        'تم خصم نقاط الإعلان وحفظ الطلب، وهو الآن قيد مراجعة وتفعيل إدارة المنصة.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Insufficient gold balance shows the required warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestableDialog(
        onAdd: (_) {},
        imagePicker: () async => BannerImageSelection(
          testPngBytes(),
          mimeType: 'image/png',
        ),
        imageUploader: (_, __) async => '/api/uploads/banner.jpg',
        submitter: (_) async => throw StateError('insufficient_gold_points'),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('banner-title-field')),
      'بانر جديد',
    );
    await tester.tap(find.byKey(const Key('banner-image-picker-btn')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('submit-banner-btn')));
    await tester.tap(find.byKey(const Key('submit-banner-btn')));
    await tester.pumpAndSettle();

    expect(find.text('رصيدك الذهبي غير كافٍ لإطلاق البانر'), findsOneWidget);
  });
}
