import 'package:coupona_app/screens/customer_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer responds to requested information and report returns to review', (tester) async {
    var status = 'information_requested';
    String? submittedMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerReportsScreen(
          reportsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'report-1',
              'reportType': 'quality',
              'description': 'Original report description',
              'status': status,
              'resolutionNote': 'Please add the batch number',
            },
          ],
          reportResponder: (reportId, message) async {
            expect(reportId, 'report-1');
            submittedMessage = message;
            status = 'new';
            return <String, dynamic>{'ok': true, 'status': 'new'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Information requested'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer-report-respond-report-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customer-report-response')), 'Batch number is 42');
    await tester.tap(find.byKey(const Key('customer-report-response-submit')));
    await tester.pumpAndSettle();

    expect(submittedMessage, 'Batch number is 42');
    expect(find.text('New'), findsOneWidget);
    expect(find.byKey(const Key('customer-report-respond-report-1')), findsNothing);
    expect(find.text('Original report description'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
