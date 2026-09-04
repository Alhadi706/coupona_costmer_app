import 'package:coupona_app/screens/admin_subscriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin subscription actions follow current lifecycle state', (tester) async {
    var status = 'trial';
    String? action;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminSubscriptionsScreen(
      loader: (_, __) async => [<String, dynamic>{'id': 'sub-1', 'ownerLabel': 'Demo Store', 'roleType': 'merchant', 'status': status, 'planType': 'basic'}],
      expireTrial: (_) async { action = 'expire'; status = 'grace_period'; return {'ok': true}; },
      endGrace: (_) async { action = 'end_grace'; status = 'suspended'; return {'ok': true}; },
      activate: (_) async { action = 'activate'; status = 'active'; return {'ok': true}; },
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Demo Store'), findsOneWidget);
    await tester.tap(find.text('subscription_end_trial'));
    await tester.pumpAndSettle();
    expect(action, 'expire');
    expect(find.textContaining('grace_period'), findsOneWidget);
  });
}
