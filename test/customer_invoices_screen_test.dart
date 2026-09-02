import 'package:coupona_app/screens/customer_invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> invoice(String state) => <String, dynamic>{
        'id': 'invoice-1',
        'merchantName': 'Store One',
        'invoiceNumber': 'INV-100',
        'totalAmount': 25,
        'currency': 'LYD',
        'state': state,
        'reviewNote': state == 'rejected' ? 'Total is unclear' : null,
      };

  testWidgets('approved customer invoice has no dispute action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerInvoicesScreen(
          invoicesLoader: ({limit = 100}) async => <Map<String, dynamic>>[
            invoice('approved'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('INV-100'), findsOneWidget);
    expect(find.byKey(const Key('customer-invoice-invoice-1-dispute')), findsNothing);
  });

  testWidgets('rejected invoice can be disputed and reloads as disputed', (tester) async {
    var state = 'rejected';
    String? submittedInvoiceId;
    String? submittedReason;
    var loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerInvoicesScreen(
          invoicesLoader: ({limit = 100}) async {
            loads += 1;
            return <Map<String, dynamic>>[invoice(state)];
          },
          disputeCreator: ({required invoiceId, required reason, evidence}) async {
            submittedInvoiceId = invoiceId;
            submittedReason = reason;
            state = 'disputed';
            return <String, dynamic>{'ok': true, 'status': 'new'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer-invoice-invoice-1-dispute')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'The receipt is clear');
    await tester.tap(find.text('Submit dispute'));
    await tester.pumpAndSettle();

    expect(submittedInvoiceId, 'invoice-1');
    expect(submittedReason, 'The receipt is clear');
    expect(loads, 2);
    expect(find.byKey(const Key('customer-invoice-invoice-1-dispute')), findsNothing);
    expect(find.text('Disputed'), findsOneWidget);
  });
}
