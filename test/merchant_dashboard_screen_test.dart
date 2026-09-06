import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/screens/merchant_dashboard_screen.dart';
import 'package:flutter/material.dart';

void main() {
  List<dynamic> dashboardData({
    required bool cashierActive,
    List<Map<String, dynamic>> claims = const <Map<String, dynamic>>[],
  }) => <dynamic>[
        <Map<String, dynamic>>[],
        <String, dynamic>{'score': 70, 'trend': 'stable'},
        <Map<String, dynamic>>[],
        <String, dynamic>{'id': 'merchant-1', 'cashbackPercentage': 5.0},
        <Map<String, dynamic>>[],
        <Map<String, dynamic>>[],
        <String, dynamic>{
          'cashier': <Map<String, dynamic>>[
            <String, dynamic>{'isActive': cashierActive},
          ],
          'subscriptions': <Map<String, dynamic>>[],
        },
        <String, dynamic>{
          'sales': <String, dynamic>{'redemptions': 0, 'pointsSpent': 0},
        },
        claims,
      ];

  Widget buildDashboard({required bool cashierActive}) {
    return MaterialApp(
      home: MerchantDashboardScreen(
        dashboardLoader: ({required range, branchId}) async =>
            dashboardData(cashierActive: cashierActive),
        analyticsLoader: ({required range, branchId}) async =>
            dashboardData(cashierActive: cashierActive).last as Map<String, dynamic>,
        pendingPointsLoader: () async => <String, dynamic>{},
        rewardFundingLoader: (_) async => <String, dynamic>{'walletBalance': 0, 'escrowBalance': 0},
      ),
    );
  }

  test('POS access requires an active cashier association', () {
    expect(hasActiveCashierAssociation(const <String, dynamic>{}), isFalse);
    expect(
      hasActiveCashierAssociation(const <String, dynamic>{
        'cashier': <Map<String, dynamic>>[
          <String, dynamic>{'isActive': false},
        ],
      }),
      isFalse,
    );
    expect(
      hasActiveCashierAssociation(const <String, dynamic>{
        'cashier': <Map<String, dynamic>>[
          <String, dynamic>{'isActive': true},
        ],
      }),
      isTrue,
    );
  });

  test('malformed cashier role data does not grant POS access', () {
    expect(
      hasActiveCashierAssociation(const <String, dynamic>{
        'cashier': <dynamic>[true, 'active', <String, dynamic>{}],
      }),
      isFalse,
    );
  });

  testWidgets('merchant without cashier association cannot open POS', (tester) async {
    await tester.pumpWidget(buildDashboard(cashierActive: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-pos-entry-disabled')), findsOneWidget);
    expect(find.byKey(const Key('merchant-pos-entry-enabled')), findsNothing);
  });

  testWidgets('merchant dashboard distinguishes load failures and retries', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          dashboardLoader: ({required range, branchId}) async {
            attempts += 1;
            if (attempts == 1) throw Exception('network unavailable');
            return dashboardData(cashierActive: false);
          },
          pendingPointsLoader: () async => <String, dynamic>{},
          rewardFundingLoader: (_) async => <String, dynamic>{'walletBalance': 0, 'escrowBalance': 0},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-dashboard-load-error')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('merchant-dashboard-load-error')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('merchant with cashier association gets a separate POS entry', (tester) async {
    await tester.pumpWidget(buildDashboard(cashierActive: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-pos-entry-enabled')), findsOneWidget);
  });

  testWidgets('merchant command center shows digital identity and branch POS tabs', (tester) async {
    final data = dashboardData(cashierActive: false);
    data[0] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'branch-1',
        'name': 'فرع طرابلس',
        'address': 'طرابلس',
        'status': 'active',
        'workingHours': '09:00 - 23:00',
      },
    ];
    data[3] = <String, dynamic>{
      'id': 'merchant-1',
      'businessName': 'متجر الاختبار',
      'cashbackPercentage': 2.0,
      'status': 'active',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          initialTab: 5,
          dashboardLoader: ({required range, branchId}) async => data,
          pendingPointsLoader: () async => <String, dynamic>{},
          rewardFundingLoader: (_) async => <String, dynamic>{'walletBalance': 0, 'escrowBalance': 0},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('متجر الاختبار'), findsOneWidget);
    expect(find.text('الهوية الرقمية والسياسة المالية'), findsOneWidget);
    expect(find.text('فاتورة بقيمة 100 دينار'), findsOneWidget);

    await tester.tap(find.text('الفروع ونقاط البيع POS'));
    await tester.pumpAndSettle();

    expect(find.text('بطاقات الفروع الذكية'), findsOneWidget);
    expect(find.text('فرع طرابلس'), findsOneWidget);
    expect(find.text('كود ربط POS'), findsOneWidget);
  });

  testWidgets('merchant dashboard uses five destinations on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(buildDashboard(cashierActive: false));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('merchant dashboard uses all destinations on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildDashboard(cashierActive: false));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.textContaining('merchant_nav_overview'), findsOneWidget);
    expect(find.textContaining('merchant_nav_rewards'), findsOneWidget);
    expect(find.textContaining('merchant_nav_ads'), findsOneWidget);
    expect(find.textContaining('merchant_nav_community'), findsOneWidget);
    expect(find.textContaining('merchant_nav_store'), findsOneWidget);
    expect(find.textContaining('merchant_nav_networks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merchant rewards tab shows owned claim reference and status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantDashboardScreen(
          dashboardLoader: ({required range, branchId}) async => dashboardData(
            cashierActive: false,
            claims: const <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'claim-123456789',
                'reference': 'reward_claim:claim-123456789',
                'rewardName': 'Merchant Gift',
                'pointsCost': 75,
                'status': 'redeemed',
              },
            ],
          ),
          pendingPointsLoader: () async => <String, dynamic>{},
          rewardFundingLoader: (_) async => <String, dynamic>{
            'walletBalance': 0,
            'escrowBalance': 0,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-reward-claim-claim-123456789')), findsOneWidget);
    expect(find.text('Merchant Gift'), findsOneWidget);
    expect(find.textContaining('redeemed'), findsOneWidget);
    expect(find.byTooltip('reward_claim:claim-123456789'), findsOneWidget);
  });
}
