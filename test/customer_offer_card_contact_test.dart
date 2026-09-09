import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coupona_app/screens/community/customer_offer_card.dart';

class _MemoryAssetLoader extends AssetLoader {
  final Map<String, Map<String, dynamic>> translations;

  const _MemoryAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    return translations[locale.languageCode];
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await EasyLocalization.ensureInitialized();

  final translations = <String, Map<String, dynamic>>{};
  for (final languageCode in <String>['ar', 'en']) {
    final contents = await File('assets/lang/$languageCode.json').readAsString();
    translations[languageCode] = (jsonDecode(contents) as Map).cast<String, dynamic>();
  }

  Widget buildTestCard({
    required Map<String, dynamic> offer,
    void Function(Map<String, dynamic>)? onContactSeller,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/lang',
      assetLoader: _MemoryAssetLoader(translations),
      startLocale: const Locale('ar'),
      fallbackLocale: const Locale('ar'),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(
              body: CustomerOfferCard(
                offer: offer,
                onStatusChanged: (_, __) async {},
                onContactSeller: onContactSeller,
              ),
            ),
          );
        },
      ),
    );
  }

  testWidgets('renders offer card with contact action toolbar and phone/whatsapp buttons', (tester) async {
    final offer = {
      'id': 'offer-1',
      'title': 'سيارة للبيع',
      'description': 'سيارة حالة ممتازة موديل 2020',
      'category': 'RENTALS',
      'price_lyd': 25000.0,
      'seller_name': 'أحمد علي',
      'seller_phone': '+218911234567',
      'is_owner': false,
      'status': 'ACTIVE',
    };

    await tester.pumpWidget(buildTestCard(offer: offer));
    await tester.pumpAndSettle();

    expect(find.text('سيارة للبيع'), findsOneWidget);
    expect(find.text('سيارة حالة ممتازة موديل 2020'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('مراسلة العارض'), findsOneWidget);
    expect(find.text('اتصال مباشر'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
  });

  testWidgets('disables chat button for self-offers and shows own offer notice', (tester) async {
    final selfOffer = {
      'id': 'offer-2',
      'title': 'عقاري الخاص',
      'description': 'شقة للبيع',
      'category': 'REAL_ESTATE',
      'price_lyd': 150000.0,
      'seller_name': 'أنا',
      'is_owner': true,
      'status': 'ACTIVE',
    };

    await tester.pumpWidget(buildTestCard(offer: selfOffer));
    await tester.pumpAndSettle();

    expect(find.text('هذا عرضك الخاص'), findsOneWidget);

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'هذا عرضك الخاص'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping offer card opens expanded offer detail sheet modal', (tester) async {
    final offer = {
      'id': 'offer-3',
      'title': 'خدمة برمجة',
      'description': 'تطوير تطبيقات جوال باستخدام فلاتر بشكل احترافي',
      'category': 'SERVICES',
      'price_lyd': 500.0,
      'seller_name': 'عمر خالد',
      'seller_phone': '+218921112233',
      'created_at': '2026-09-01T10:00:00Z',
      'is_owner': false,
      'status': 'ACTIVE',
    };

    await tester.pumpWidget(buildTestCard(offer: offer));
    await tester.pumpAndSettle();

    // Tap card to open bottom sheet
    await tester.tap(find.text('خدمة برمجة'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل العرض'), findsOneWidget);
    expect(find.text('عمر خالد'), findsWidgets);
    expect(find.text('تواصل مع العارض الآن'), findsOneWidget);
  });

  testWidgets('calls custom onContactSeller callback when chat button is pressed', (tester) async {
    bool contacted = false;
    final offer = {
      'id': 'offer-4',
      'title': 'وجبة طعام',
      'description': 'وجبة عائلية فاخرة',
      'category': 'FOOD',
      'price_lyd': 80.0,
      'seller_name': 'مطعم الفخامة',
      'is_owner': false,
      'status': 'ACTIVE',
    };

    await tester.pumpWidget(
      buildTestCard(
        offer: offer,
        onContactSeller: (o) {
          contacted = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('مراسلة العارض'));
    await tester.pumpAndSettle();

    expect(contacted, isTrue);
  });
}