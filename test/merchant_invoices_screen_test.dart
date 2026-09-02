import 'package:coupona_app/screens/merchant_invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> queue(List<Map<String, dynamic>> invoices) => <String, dynamic>{
        'reviewerRole': 'merchant_owner',
        'invoices': invoices,
      };

  Map<String, dynamic> invoice({required String state}) => <String, dynamic>{
        'id': 'invoice-1',
        'ownerLabel': 'Customer One',
        'branchName': 'Main Branch',
        'invoiceNumber': 'INV-100',
        'totalAmount': 25,
        'currency': 'LYD',
        'state': state,
      };

  testWidgets('invoice queue distinguishes failure from empty data and retries', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantInvoicesScreen(
          invoicesLoader: ({required state, limit = 100}) async {
            attempts += 1;
            if (attempts == 1) throw Exception('offline');
            return queue(const <Map<String, dynamic>>[]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-invoices-load-error')), findsOneWidget);
    expect(find.byKey(const Key('merchant-invoices-empty')), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('merchant-invoices-load-error')), findsNothing);
    expect(find.byKey(const Key('merchant-invoices-empty')), findsOneWidget);
  });

  testWidgets('approved invoice exposes no review actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantInvoicesScreen(
          invoicesLoader: ({required state, limit = 100}) async => queue(<Map<String, dynamic>>[
            invoice(state: 'approved'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-100'), findsOneWidget);
    expect(find.byKey(const Key('invoice-invoice-1-approved')), findsNothing);
    expect(find.byKey(const Key('invoice-invoice-1-rejected')), findsNothing);
    expect(find.byKey(const Key('invoice-invoice-1-manual_review')), findsNothing);
  });

  testWidgets('processing invoice can be approved and reloads the queue', (tester) async {
    var currentState = 'processing';
    String? transitionedInvoiceId;
    String? transitionedTo;
    var loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantInvoicesScreen(
          invoicesLoader: ({required state, limit = 100}) async {
            loads += 1;
            return queue(<Map<String, dynamic>>[invoice(state: currentState)]);
          },
          invoiceTransition: ({required invoiceId, required to, note}) async {
            transitionedInvoiceId = invoiceId;
            transitionedTo = to;
            currentState = to;
            return <String, dynamic>{'ok': true, 'to': to};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invoice-invoice-1-approved')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(transitionedInvoiceId, 'invoice-1');
    expect(transitionedTo, 'approved');
    expect(loads, 2);
    expect(find.byKey(const Key('invoice-invoice-1-approved')), findsNothing);
  });
}