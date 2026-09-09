import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coupona_app/screens/coalitions/coalition_clearinghouse_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryAssetLoader extends AssetLoader {
  final Map<String, Map<String, dynamic>> translations;
  const _MemoryAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      translations[locale.languageCode];
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await EasyLocalization.ensureInitialized();
  final translations = <String, Map<String, dynamic>>{};
  for (final languageCode in <String>['ar', 'en']) {
    translations[languageCode] = (jsonDecode(
      await File('assets/lang/$languageCode.json').readAsString(),
    ) as Map).cast<String, dynamic>();
  }

  Widget app({
    required ClearinghouseLoader clearinghouseLoader,
    ClearinghouseSettler? settler,
    Duration timeout = const Duration(seconds: 1),
  }) => EasyLocalization(
        supportedLocales: const [Locale('ar'), Locale('en')],
        path: 'assets/lang',
        assetLoader: _MemoryAssetLoader(translations),
        startLocale: const Locale('ar'),
        fallbackLocale: const Locale('ar'),
        child: Builder(builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: CoalitionClearinghouseScreen(
            clearinghouseLoader: clearinghouseLoader,
            ledgerLoader: () async => <String, dynamic>{'ledger': <dynamic>[]},
            settler: settler,
            requestTimeout: timeout,
          ),
        )),
      );

  testWidgets('request timeout leaves spinner and shows retry state', (tester) async {
    await tester.pumpWidget(app(
      clearinghouseLoader: () => Completer<Map<String, dynamic>>().future,
      timeout: const Duration(milliseconds: 10),
    ));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('clearinghouse-load-error')), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('renders API KPIs and opens settlement confirmation', (tester) async {
    await tester.pumpWidget(app(
      clearinghouseLoader: () async => <String, dynamic>{
        'summary': <String, dynamic>{
          'issuedPoints': 80,
          'redeemedPoints': 120,
          'netBalance': 40,
          'pointValue': 1,
        },
        'memberSettlements': <Map<String, dynamic>>[
          <String, dynamic>{
            'coalition_id': 'co-1',
            'to_merchant_id': 'm-2',
            'partner_merchant': 'متجر ب',
            'exchanged_points': 80,
            'net_amount': -80,
            'period': '2026-09',
            'status': 'pending',
          },
        ],
        'disputes': <dynamic>[],
      },
    ));
    await tester.pumpAndSettle();

    expect(find.text('80'), findsWidgets);
    expect(find.text('120'), findsOneWidget);
    expect(find.textContaining('+40.00'), findsOneWidget);
    expect(find.text('متجر ب'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearinghouse-settle-all')));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد التسوية الصافية'), findsOneWidget);
  });
}