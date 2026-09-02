import 'package:coupona_app/screens/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('Renders role requests and calls approve action', (tester) async {
    String? approvedRequestId;

    await tester.pumpWidget(
      app(
        AdminDashboardScreen(
          roleRequestsLoader: (_) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'rr-1',
              'roleType': 'merchant',
              'businessName': 'Demo Store',
              'phone': '0910000000',
              'planType': 'basic',
              'locationLat': 32.88,
              'locationLng': 13.19,
              'locationAddress': 'Tripoli',
            },
          ],
          peerAdsLoader: (_) async => <Map<String, dynamic>>[],
          summaryLoader: () async => <String, dynamic>{
            'users': 1,
            'merchants': 1,
            'brands': 0,
            'reports': 0,
            'fraudFlags': 0,
          },
          approveRoleRequest: (requestId) async {
            approvedRequestId = requestId;
            return <String, dynamic>{'ok': true};
          },
          rejectRoleRequest: (_) async => <String, dynamic>{'ok': true},
          approvePeerAd: (_) async => <String, dynamic>{'ok': true},
          rejectPeerAd: (_) async => <String, dynamic>{'ok': true},
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Role Requests'));
    await tester.pumpAndSettle();

    expect(find.text('Demo Store (merchant)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve').first);
    await tester.pumpAndSettle();

    expect(approvedRequestId, 'rr-1');
  });

  testWidgets('Renders peer ads and calls reject action', (tester) async {
    String? rejectedAdId;

    await tester.pumpWidget(
      app(
        AdminDashboardScreen(
          roleRequestsLoader: (_) async => <Map<String, dynamic>>[],
          peerAdsLoader: (_) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'ad-1',
              'content': 'Peer ad sample',
              'targetType': 'city',
              'targetValue': 'tripoli',
            },
          ],
          summaryLoader: () async => <String, dynamic>{
            'users': 1,
            'merchants': 1,
            'brands': 0,
            'reports': 0,
            'fraudFlags': 0,
          },
          approveRoleRequest: (_) async => <String, dynamic>{'ok': true},
          rejectRoleRequest: (_) async => <String, dynamic>{'ok': true},
          approvePeerAd: (_) async => <String, dynamic>{'ok': true},
          rejectPeerAd: (adId) async {
            rejectedAdId = adId;
            return <String, dynamic>{'ok': true};
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Peer Ads'));
    await tester.pumpAndSettle();

    expect(find.text('Peer ad sample'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
    await tester.pumpAndSettle();

    expect(rejectedAdId, 'ad-1');
  });

  testWidgets('Disables both row actions while a request action is running', (
    tester,
  ) async {
    final action = Completer<Map<String, dynamic>>();
    var calls = 0;

    await tester.pumpWidget(
      app(
        AdminDashboardScreen(
          roleRequestsLoader: (_) async => [
            <String, dynamic>{
              'id': 'rr-1',
              'roleType': 'merchant',
              'businessName': 'Pending Store',
            },
          ],
          peerAdsLoader: (_) async => <Map<String, dynamic>>[],
          summaryLoader: () async => <String, dynamic>{},
          approveRoleRequest: (_) {
            calls++;
            return action.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Role Requests'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    action.complete(<String, dynamic>{'ok': true});
    await tester.pumpAndSettle();
  });

  testWidgets('Shows feedback when an admin action fails', (tester) async {
    await tester.pumpWidget(
      app(
        AdminDashboardScreen(
          roleRequestsLoader: (_) async => [
            <String, dynamic>{
              'id': 'rr-1',
              'roleType': 'merchant',
              'businessName': 'Pending Store',
            },
          ],
          peerAdsLoader: (_) async => <Map<String, dynamic>>[],
          summaryLoader: () async => <String, dynamic>{},
          approveRoleRequest: (_) async => throw StateError('network failure'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Role Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not complete this action. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Overview action opens the related admin tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        AdminDashboardScreen(
          roleRequestsLoader: (_) async => <Map<String, dynamic>>[],
          peerAdsLoader: (_) async => <Map<String, dynamic>>[],
          summaryLoader: () async => <String, dynamic>{'users': 1},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review role requests'));
    await tester.pumpAndSettle();

    expect(find.text('No pending role requests.'), findsOneWidget);
  });

  testWidgets('Overview charts fit a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        AdminDashboardScreen(
          roleRequestsLoader: (_) async => <Map<String, dynamic>>[],
          peerAdsLoader: (_) async => <Map<String, dynamic>>[],
          summaryLoader: () async => <String, dynamic>{
            'users': 4,
            'merchants': 2,
            'brands': 1,
            'activity': <Map<String, dynamic>>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Platform activity & Revenue (30 days)'), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelColor, Colors.white);
  });
}
