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
        <String, dynamic>{'id': 'merchant-1', 'pointValue': 1},
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
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Networks'), findsOneWidget);
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
