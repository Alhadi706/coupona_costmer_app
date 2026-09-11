import 'dart:convert';
import 'dart:io';

import 'package:coupona_app/screens/admin_subscriptions_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final contents = await File(
      'assets/lang/$languageCode.json',
    ).readAsString();
    translations[languageCode] = (jsonDecode(contents) as Map)
        .cast<String, dynamic>();
  }

  Widget app(Widget child) => EasyLocalization(
    supportedLocales: const [Locale('ar'), Locale('en')],
    path: 'assets/lang',
    assetLoader: _MemoryAssetLoader(translations),
    startLocale: const Locale('ar'),
    fallbackLocale: const Locale('ar'),
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('admin subscription actions follow current lifecycle state', (
    tester,
  ) async {
    var status = 'trial';
    String? action;
    await tester.pumpWidget(
      app(
        AdminSubscriptionsScreen(
          loader: (_, __) async => [
            <String, dynamic>{
              'id': 'sub-1',
              'ownerLabel': 'Demo Store',
              'roleType': 'merchant',
              'status': status,
              'planType': 'basic',
            },
          ],
          expireTrial: (_) async {
            action = 'expire';
            status = 'grace_period';
            return {'ok': true};
          },
          endGrace: (_) async {
            action = 'end_grace';
            status = 'suspended';
            return {'ok': true};
          },
          activate: (_) async {
            action = 'activate';
            status = 'active';
            return {'ok': true};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Demo Store'), findsOneWidget);
    expect(find.textContaining('تاجر • تجريبي • أساسي'), findsOneWidget);
    await tester.tap(find.text('إنهاء الفترة التجريبية'));
    await tester.pumpAndSettle();
    expect(action, 'expire');
    expect(find.textContaining('تاجر • قيد التجديد • أساسي'), findsOneWidget);

    await tester
        .element(find.byType(AdminSubscriptionsScreen))
        .setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Merchant • Grace period • Basic'),
      findsOneWidget,
    );
  });
}
