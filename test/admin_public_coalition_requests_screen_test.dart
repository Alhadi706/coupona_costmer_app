import 'package:coupona_app/screens/admin_public_coalition_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('Embedded coalition tab does not add a nested app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        AdminPublicCoalitionRequestsScreen(
          embedded: true,
          requestsLoader: (_) async => <Map<String, dynamic>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('Coalition approval submits once and shows success feedback', (
    tester,
  ) async {
    var calls = 0;
    String? submittedMessage;
    await tester.pumpWidget(
      app(
        AdminPublicCoalitionRequestsScreen(
          embedded: true,
          requestsLoader: (_) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'coalition-1',
              'applicantName': 'Demo Merchant',
              'applicantType': 'merchant',
              'status': 'pending_admin_review',
            },
          ],
          approveAction:
              (requestId, {required adminMessage, paymentUrl}) async {
                calls++;
                submittedMessage = adminMessage;
                return <String, dynamic>{'id': requestId};
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('approve').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Payment instructions',
    );
    await tester.tap(find.text('public_coalition_send_payment_message'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(submittedMessage, 'Payment instructions');
    expect(find.text('Action completed successfully.'), findsOneWidget);
  });
}
