import 'dart:convert';
import 'dart:io';

import 'package:coupona_app/screens/brand_dashboard_screen.dart';
import 'package:coupona_app/widgets/brand_analytics_charts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
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
    final contents = await File('assets/lang/$languageCode.json').readAsString();
    translations[languageCode] = (jsonDecode(contents) as Map).cast<String, dynamic>();
  }

  Widget buildApp(Widget home) {
    return EasyLocalization(
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
          home: home,
        ),
      ),
    );
  }

  Widget buildDashboard({
    BrandOffersLoader? offersLoader,
    BrandProductsLoader? productsLoader,
    BrandProductCreator? productCreator,
    BrandProductUpdater? productUpdater,
    BrandProductDeactivator? productDeactivator,
    BrandProductImageSelector? productImageSelector,
    BrandProductBarcodeSelector? productBarcodeSelector,
    BrandAnalyticsRangeLoader? analyticsRangeLoader,
    BrandAnalyticsFilterLoader? analyticsFilterLoader,
    BrandWalletLoader? walletLoader,
    BrandWalletLoader? pendingPointsLoader,
    BrandRewardUpdater? rewardUpdater,
    BrandRewardsLoader? rewardsLoader,
    BrandRewardClaimsLoader? rewardClaimsLoader,
  }) {
    return buildApp(
      BrandDashboardScreen(
        offersLoader: offersLoader ?? () async => <Map<String, dynamic>>[],
        invoicesLoader: ({int limit = 20}) async => <Map<String, dynamic>>[],
        profileLoader: () async => <String, dynamic>{'pointValue': 5.0},
        productsLoader: productsLoader ?? () async => <Map<String, dynamic>>[],
        communityLoader: () async => <Map<String, dynamic>>[],
        rewardsLoader: rewardsLoader ?? () async => <Map<String, dynamic>>[],
        reportsLoader: () async => <Map<String, dynamic>>[],
        analyticsLoader: () async => <String, dynamic>{},
        analyticsRangeLoader: analyticsRangeLoader,
        analyticsFilterLoader: analyticsFilterLoader,
        walletLoader: walletLoader ?? () async => <String, dynamic>{'balance': 0, 'currency': 'SAR'},
        pendingPointsLoader: pendingPointsLoader ?? () async => <String, dynamic>{'total_points': 0, 'customer_count': 0},
        rewardUpdater: rewardUpdater,
        rewardClaimsLoader: rewardClaimsLoader ?? () async => <Map<String, dynamic>>[],
        rewardFundingLoader: (_) async => <String, dynamic>{'walletBalance': 0, 'escrowBalance': 0},
        productCreator: productCreator,
        productUpdater: productUpdater,
        productDeactivator: productDeactivator,
        productImageSelector: productImageSelector,
        productBarcodeSelector: productBarcodeSelector,
      ),
    );
  }

  testWidgets('brand dashboard distinguishes load failures from empty data and retries', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      buildDashboard(
        offersLoader: () async {
          attempts += 1;
          if (attempts == 1) throw Exception('network unavailable');
          return <Map<String, dynamic>>[];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('brand-dashboard-load-error')), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.textContaining('متاجر 0'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('brand-dashboard-load-error')), findsNothing);
    expect(find.textContaining('لوحة العلامة'), findsWidgets);
  });

  testWidgets('brand dashboard uses five destinations on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.takeException(), isNull, reason: 'initial narrow layout');

    await tester.tap(find.text('المزيد'));
    await tester.pumpAndSettle();
    expect(find.text('الإدارة'), findsOneWidget);
    expect(find.text('الشبكة'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'more destinations sheet');

    await tester.tap(find.text('الإدارة'));
    await tester.pumpAndSettle();
    expect(find.text('تنبيهات المبيعات'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'operations destination');
  });

  testWidgets('brand ads tab shows owned ads campaigns and performance', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildDashboard(
        offersLoader: () async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'brand-ad-1',
            'description': 'إعلان علامتي',
            'lifecycleStatus': 'active',
            'impressions': 14,
            'clicks': 3,
          },
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الإعلانات'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('brand-ads-campaigns-tab')), findsOneWidget);
    expect(find.text('إضافة إعلان للوحة الرئيسية'), findsOneWidget);
    expect(find.text('إطلاق حملة مستهدفة'), findsOneWidget);
    expect(find.text('إعلان علامتي'), findsOneWidget);
    expect(find.textContaining('المشاهدات 14'), findsOneWidget);
    expect(find.textContaining('النقرات 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand dashboard uses all destinations on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildDashboard());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('نظرة عامة'), findsOneWidget);
    expect(find.text('التحليلات'), findsOneWidget);
    expect(find.text('المتاجر'), findsOneWidget);
    expect(find.text('المكافآت'), findsOneWidget);
    expect(find.text('الإعلانات'), findsOneWidget);
    expect(find.text('الإدارة'), findsOneWidget);
    expect(find.text('الشبكة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand product lifecycle creates edits and deactivates without deleting history', (tester) async {
    final products = <Map<String, dynamic>>[];
    String? submittedImageUrl;

    await tester.pumpWidget(
      buildDashboard(
        productsLoader: () async => products.map(Map<String, dynamic>.from).toList(),
        productCreator: ({required name, imageUrl, barcode}) async {
          submittedImageUrl = imageUrl;
          products.add(<String, dynamic>{
            'id': 'product-1',
            'name': name,
            'imageUrl': '',
            'barcode': barcode,
            'isActive': true,
          });
          return <String, dynamic>{'id': 'product-1'};
        },
        productUpdater: ({required productId, required name, imageUrl, barcode}) async {
          final product = products.singleWhere((row) => row['id'] == productId);
          product.addAll(<String, dynamic>{'name': name, 'imageUrl': imageUrl, 'barcode': barcode});
          return <String, dynamic>{'ok': true};
        },
        productDeactivator: (productId) async {
          products.singleWhere((row) => row['id'] == productId)['isActive'] = false;
          return <String, dynamic>{'ok': true, 'isActive': false};
        },
        productImageSelector: () async => 'https://example.com/product.png',
        productBarcodeSelector: () async => '123456',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المكافآت'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('إضافة منتج للعلامة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة منتج للعلامة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('brand-product-name')), 'منتج مترابط');
    await tester.tap(find.byKey(const Key('brand-product-select-image')));
    await tester.pumpAndSettle();
    expect(find.text('تم اختيار صورة المنتج'), findsOneWidget);
    await tester.tap(find.byKey(const Key('brand-product-scan-barcode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brand-product-save')));
    await tester.pumpAndSettle();

    expect(find.text('منتج مترابط'), findsOneWidget);
    expect(find.textContaining('123456'), findsOneWidget);
    expect(submittedImageUrl, 'https://example.com/product.png');

    await tester.tap(find.byKey(const Key('brand-product-menu-product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل المنتج'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('brand-product-name')), 'منتج محدث');
    await tester.enterText(find.byKey(const Key('brand-product-barcode')), '654321');
    await tester.tap(find.byKey(const Key('brand-product-save')));
    await tester.pumpAndSettle();

    expect(find.text('منتج محدث'), findsOneWidget);
    expect(find.textContaining('654321'), findsOneWidget);

    await tester.tap(find.byKey(const Key('brand-product-menu-product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إيقاف المنتج'));
    await tester.pumpAndSettle();
    expect(find.textContaining('سيبقى منتج محدث في السجلات السابقة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('brand-product-confirm-deactivate')));
    await tester.pumpAndSettle();

    expect(find.text('الباركود: 654321 • متوقف'), findsOneWidget);
    expect(products.single['isActive'], isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand product catalog searches and filters active state', (tester) async {
    await tester.pumpWidget(
      buildDashboard(
        productsLoader: () async => <Map<String, dynamic>>[
          <String, dynamic>{'id': 'active-1', 'name': 'عصير نشط', 'barcode': '111', 'isActive': true},
          <String, dynamic>{'id': 'inactive-1', 'name': 'صابون متوقف', 'barcode': '222', 'isActive': false},
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المكافآت'));
    await tester.pumpAndSettle();

    expect(find.text('عصير نشط'), findsOneWidget);
    expect(find.text('صابون متوقف'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('brand-product-search')), '111');
    await tester.pump();
    expect(find.text('عصير نشط'), findsOneWidget);
    expect(find.text('صابون متوقف'), findsNothing);

    await tester.enterText(find.byKey(const Key('brand-product-search')), '');
    await tester.tap(find.text('متوقف'));
    await tester.pumpAndSettle();
    expect(find.text('عصير نشط'), findsNothing);
    expect(find.text('صابون متوقف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand rewards show funding and can be paused safely', (tester) async {
    var rewardActive = true;
    var currentQuantityLimit = 10;
    await tester.pumpWidget(
      buildDashboard(
        walletLoader: () async => <String, dynamic>{'balance': 500, 'currency': 'SAR'},
        pendingPointsLoader: () async => <String, dynamic>{'total_points': 40, 'customer_count': 2},
        rewardsLoader: () async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'reward-1',
            'reward_name': 'مكافأة ممولة',
            'value': 100,
            'isActive': rewardActive,
            'quantityLimit': currentQuantityLimit,
            'quantityRedeemed': 3,
          },
        ],
        rewardUpdater: (rewardId, {isActive, quantityLimit, expiresAt, description}) async {
          expect(rewardId, 'reward-1');
          rewardActive = isActive ?? rewardActive;
          if (quantityLimit != null) currentQuantityLimit = quantityLimit;
          return <String, dynamic>{'ok': true};
        },
        rewardClaimsLoader: () async => <Map<String, dynamic>>[
          <String, dynamic>{'id': 'claim-reference-123', 'rewardName': 'مكافأة ممولة', 'pointsCost': 100, 'status': 'redeemed'},
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المكافآت'));
    await tester.pumpAndSettle();

    expect(find.text('500'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('مكافأة ممولة'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const Key('brand-claim-claim-reference-123')),
      find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).last,
      const Offset(0, -300),
    );
    expect(find.text('#claim-re'), findsOneWidget);

    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(rewardActive, isFalse);
    expect((tester.widget<Switch>(find.byType(Switch).first)).value, isFalse);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('brand-reward-quantity')), '8');
    await tester.tap(find.byKey(const Key('brand-reward-save')));
    await tester.pumpAndSettle();
    expect(currentQuantityLimit, 8);
    expect(find.text('3/8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand analytics range filter refreshes analytics without leaving the tab', (tester) async {
    final requestedRanges = <String>[];
    await tester.pumpWidget(
      buildDashboard(
        analyticsRangeLoader: (range) async {
          requestedRanges.add(range);
          return <String, dynamic>{
            'matchedSales': range == '7d' ? 700 : range == '90d' ? 9000 : 3000,
            'matchedCustomers': 1,
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('التحليلات'));
    await tester.pumpAndSettle();

    expect(requestedRanges, <String>['30d']);
    expect(find.textContaining('3,000'), findsNothing);

    await tester.tap(find.text('7 أيام'));
    await tester.pumpAndSettle();
    expect(requestedRanges, <String>['30d', '7d']);
    expect(find.textContaining('700.00'), findsOneWidget);
    expect(find.text('اتجاه المبيعات اليومية'), findsOneWidget);

    await tester.tap(find.text('90 يومًا'));
    await tester.pumpAndSettle();
    expect(requestedRanges, <String>['30d', '7d', '90d']);
    expect(find.textContaining('9000.00'), findsOneWidget);
    expect(find.text('اتجاه المبيعات اليومية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand analytics renders responsive charts and compact empty states', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: SingleChildScrollView(
            child: BrandAnalyticsCharts(
              analytics: <String, dynamic>{
                'matchedSales': 1250,
                'matchedCustomers': 8,
                'pointsIssued': 1000,
                'pointsRedeemed': 250,
                'rewardClaims': 3,
                'redemptionRate': 25,
                'dailySales': <Map<String, dynamic>>[
                  <String, dynamic>{'date': '2026-09-01', 'sales': 500},
                  <String, dynamic>{'date': '2026-09-02', 'sales': 750},
                ],
                'topSellingStores': <Map<String, dynamic>>[
                  <String, dynamic>{'name': 'متجر أ', 'salesTotal': 1250},
                ],
                'topProducts': <Map<String, dynamic>>[
                  <String, dynamic>{'name': 'منتج أ', 'salesTotal': 1250},
                ],
                'growthLevels': <Map<String, dynamic>>[
                  <String, dynamic>{'label': 'الإجمالي', 'current': 1250, 'previous': 900},
                ],
                'consumerDemographics': <String, dynamic>{
                  'gender': <Map<String, dynamic>>[
                    <String, dynamic>{'label': 'ذكر', 'value': 5},
                    <String, dynamic>{'label': 'أنثى', 'value': 3},
                  ],
                  'ageBuckets': <Map<String, dynamic>>[
                    <String, dynamic>{'label': '25-34', 'value': 8},
                  ],
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNWidgets(4));
    expect(find.byType(PieChart), findsNWidgets(2));
    expect(find.byKey(const Key('brand-chart-map')), findsOneWidget);
    expect(find.byKey(const Key('brand-chart-empty')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand analytics combines store product and region filters', (tester) async {
    final requests = <Map<String, String?>>[];
    await tester.pumpWidget(
      buildDashboard(
        analyticsFilterLoader: ({required range, storeId, product, region}) async {
          requests.add({'range': range, 'storeId': storeId, 'product': product, 'region': region});
          return <String, dynamic>{
            'matchedSales': 100,
            'filterOptions': <String, dynamic>{
              'stores': [<String, dynamic>{'value': 'store-1', 'label': 'متجر أ'}],
              'products': [<String, dynamic>{'value': 'product-1', 'label': 'منتج أ'}],
              'regions': [<String, dynamic>{'value': 'طرابلس', 'label': 'طرابلس'}],
            },
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('التحليلات'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('brand-analytics-store-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متجر أ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brand-analytics-product-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منتج أ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brand-analytics-region-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طرابلس').last);
    await tester.pumpAndSettle();

    expect(requests.last, {'range': '30d', 'storeId': 'store-1', 'product': 'product-1', 'region': 'طرابلس'});
    expect(find.text('اتجاه المبيعات اليومية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand analytics bounds large datasets on a phone layout', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final daily = List.generate(100, (index) => <String, dynamic>{'date': '2026-09-${(index % 30 + 1).toString().padLeft(2, '0')}', 'sales': index + 1});
    final stores = List.generate(100, (index) => <String, dynamic>{'name': 'متجر $index', 'salesTotal': index + 1});
    final products = List.generate(100, (index) => <String, dynamic>{'name': 'منتج $index', 'salesTotal': index + 1});

    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: SingleChildScrollView(
            child: BrandAnalyticsCharts(
              analytics: <String, dynamic>{
                'matchedSales': 5050,
                'matchedCustomers': 100,
                'dailySales': daily,
                'topSellingStores': stores,
                'lowestSellingStores': stores.reversed.toList(),
                'topProducts': products,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand dashboard renders core FMCG sections', (tester) async {
    await tester.pumpWidget(
      buildApp(
        BrandDashboardScreen(
          embedded: false,
          offersLoader: () async => <Map<String, dynamic>>[],
          invoicesLoader: ({int limit = 20}) async => <Map<String, dynamic>>[],
          profileLoader: () async => <String, dynamic>{'pointValue': 5.0},
          productsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{'name': 'منتج اختبار', 'barcode': '123'},
          ],
          communityLoader: () async => <Map<String, dynamic>>[],
          rewardsLoader: () async => <Map<String, dynamic>>[],
          reportsLoader: () async => <Map<String, dynamic>>[],
          analyticsLoader: () async => <String, dynamic>{
            'matchedSales': 2500,
            'matchedCustomers': 120,
            'distributionHeatmap': <Map<String, dynamic>>[],
            'topSellingStores': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'متجر التكامل', 'salesTotal': 2500, 'quantity': 10},
            ],
            'topProducts': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'منتج اختبار', 'salesTotal': 2500, 'quantity': 10},
            ],
            'growthLevels': <Map<String, dynamic>>[
              <String, dynamic>{'level': 'overall', 'label': 'Overall brand sales', 'current': 2500, 'previous': 2000, 'growthPercent': 25},
            ],
          },
          walletLoader: () async => <String, dynamic>{'balance': 1000, 'currency': 'SAR'},
          pendingPointsLoader: () async => <String, dynamic>{'total_points': 0, 'customer_count': 0},
          rewardClaimsLoader: () async => <Map<String, dynamic>>[],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('لوحة'), findsWidgets);
    expect(find.text('التحليلات'), findsOneWidget);
    expect(find.text('المكافآت'), findsOneWidget);
    expect(find.text('المزيد'), findsOneWidget);

    await tester.tap(find.text('التحليلات'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('اتجاه المبيعات اليومية'), findsOneWidget);
    expect(find.textContaining('مقارنة النمو'), findsOneWidget);
    expect(find.textContaining('Overall brand sales'), findsNothing);
    expect(find.textContaining('customer-owner-id'), findsNothing);

    await tester.tap(find.text('المكافآت'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('مكافآت'), findsWidgets);

    await tester.tap(find.text('المزيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإدارة'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('جودة'), findsWidgets);
    expect(find.textContaining('مجتمع'), findsWidgets);
    expect(find.text('قيمة النقطة النظامية'), findsOneWidget);
    expect(find.textContaining('0.1'), findsOneWidget);
    expect(find.text('حفظ قيمة النقطة'), findsNothing);
  });
}
