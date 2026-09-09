import 'dart:convert';
import 'dart:io';

import 'package:coupona_app/screens/store_details_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAssetLoader extends AssetLoader {
  final Map<String, Map<String, dynamic>> translations;
  const _TestAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations[locale.languageCode] ?? <String, dynamic>{};
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

  Widget buildApp(Widget child, {Locale locale = const Locale('ar')}) {
    return EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/lang',
      assetLoader: _TestAssetLoader(translations),
      startLocale: locale,
      fallbackLocale: const Locale('ar'),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(body: child),
          );
        },
      ),
    );
  }

  testWidgets('store page respects Arabic localization', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const StoreDetailsScreen(
          store: <String, dynamic>{
            'name': 'مخبز نور',
            'category': 'مخابز',
            'pointValue': 0.1,
            'pointTier': 'bronze',
            'lat': 32.88,
            'lng': 13.19,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مخبز نور'), findsWidgets);
    expect(find.text('نظرة عامة'), findsOneWidget);
    expect(find.text('المنتجات'), findsWidgets);
    expect(find.text('العروض'), findsWidgets);
    expect(find.text('الجوائز'), findsWidgets);
    expect(find.text('التحالفات'), findsOneWidget);
    expect(find.text('نقاطك في المتجر'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'المنتجات'));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد منتجات متاحة لهذا المتجر حاليًا.'), findsOneWidget);
  });
}
