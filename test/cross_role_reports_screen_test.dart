import 'package:coupona_app/screens/customer_reports_screen.dart';
import 'package:coupona_app/screens/merchant_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer sees report resolution and compensation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerReportsScreen(
          reportsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'report-1',
              'targetStoreName': 'Store One',
              'description': 'Wrong price',
              'status': 'reward_granted',
              'rewardPoints': 15,
              'resolutionNote': 'Price corrected',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Store One'), findsOneWidget);
    expect(find.textContaining('Price corrected'), findsOneWidget);
    expect(find.textContaining('15'), findsOneWidget);
  });

  testWidgets('resolved merchant report has no resolution action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReportsScreen(
          reportsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'report-1',
              'reportType': 'bad_service',
              'description': 'Issue',
              'status': 'accepted',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-report-report-1-resolve')), findsNothing);
  });

  testWidgets('merchant resolves a new report once and reloads it', (tester) async {
    var status = 'new';
    var resolutions = 0;
    var loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReportsScreen(
          reportsLoader: () async {
            loads += 1;
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'report-1',
                'reportType': 'bad_service',
                'description': 'Issue',
                'status': status,
              },
            ];
          },
          reportResolver: (reportId, {action = 'accept', grantReward = false, rewardPoints = 10, resolutionNote}) async {
            resolutions += 1;
            status = 'accepted';
            return <String, dynamic>{'ok': true, 'id': reportId};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('merchant-report-report-1-resolve')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(resolutions, 1);
    expect(loads, 2);
    expect(find.byKey(const Key('merchant-report-report-1-resolve')), findsNothing);
  });

  testWidgets('merchant requests information with a required note', (tester) async {
    String? selectedAction;
    String? submittedNote;
    await tester.pumpWidget(MaterialApp(home: MerchantReportsScreen(
      reportsLoader: () async => <Map<String, dynamic>>[
        <String, dynamic>{'id': 'report-1', 'reportType': 'quality', 'description': 'Unclear batch', 'status': 'new'},
      ],
      reportResolver: (reportId, {action = 'accept', grantReward = false, rewardPoints = 10, resolutionNote}) async {
        selectedAction = action;
        submittedNote = resolutionNote;
        return <String, dynamic>{'ok': true, 'id': reportId, 'status': 'information_requested'};
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-report-report-1-resolve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('merchant-report-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request information').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Please attach a clearer receipt.');
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.byKey(const Key('merchant-report-confirm-action')));
    expect(confirm.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('merchant-report-confirm-action')));
    await tester.pumpAndSettle();

    expect(selectedAction, 'request_information');
    expect(submittedNote, 'Please attach a clearer receipt.');
  });

  testWidgets('customer sees chronological report conversation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CustomerReportsScreen(
      reportsLoader: () async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'report-1', 'targetStoreName': 'Store One', 'description': 'Issue',
          'status': 'information_requested',
          'updates': <Map<String, dynamic>>[
            <String, dynamic>{'authorRole': 'merchant', 'message': 'Send invoice number'},
            <String, dynamic>{'authorRole': 'customer', 'message': 'Invoice 42'},
          ],
        },
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Send invoice number'), findsOneWidget);
    expect(find.text('Invoice 42'), findsOneWidget);
    expect(find.text('merchant'), findsOneWidget);
    expect(find.text('customer'), findsOneWidget);
  });
}
