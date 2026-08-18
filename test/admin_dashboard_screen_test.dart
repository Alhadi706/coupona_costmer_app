import 'package:coupona_app/screens/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
