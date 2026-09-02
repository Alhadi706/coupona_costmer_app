import 'package:coupona_app/screens/admin_public_coalition_requests_screen.dart';
import 'package:coupona_app/screens/home_screen.dart';
import 'package:coupona_app/screens/public_coalition_membership_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification applicant type overrides the currently active role safely', () {
    expect(
      publicCoalitionApplicantType(
        const <String, dynamic>{'payload': <String, dynamic>{'applicantType': 'brand'}},
        'customer',
      ),
      'brand',
    );
    expect(
      publicCoalitionApplicantType(
        const <String, dynamic>{'payload': <String, dynamic>{'applicantType': 'admin'}},
        'customer',
      ),
      isNull,
    );
  });

  testWidgets('merchant and brand applications submit the correct applicant type', (tester) async {
    for (final applicantType in ['merchant', 'brand']) {
      String? submittedType;
      await tester.pumpWidget(MaterialApp(
        home: PublicCoalitionMembershipScreen(
          key: ValueKey<String>(applicantType),
          applicantType: applicantType,
          requestLoader: (_) async => null,
          requestAction: (type) async {
            submittedType = type;
            return <String, dynamic>{'id': 'request-1', 'status': 'pending_admin_review'};
          },
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('public-coalition-submit-request')));
      await tester.pumpAndSettle();

      expect(submittedType, applicantType);
      expect(find.byKey(const Key('public-coalition-status-pending_admin_review')), findsOneWidget);
    }
  });

  testWidgets('pending application cannot open payment', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'merchant',
        requestLoader: (_) async => <String, dynamic>{'id': 'request-1', 'status': 'pending_admin_review'},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-coalition-status-pending_admin_review')), findsOneWidget);
    expect(find.byKey(const Key('public-coalition-open-payment')), findsNothing);
  });

  testWidgets('approved application shows private admin message and payment action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'brand',
        requestLoader: (_) async => <String, dynamic>{
          'id': 'request-1',
          'status': 'approved_pending_payment',
          'adminMessage': 'Complete payment using your private link.',
          'paymentUrl': 'https://payments.example/request-1',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Complete payment using your private link.'), findsOneWidget);
    expect(find.byKey(const Key('public-coalition-open-payment')), findsOneWidget);
  });

  testWidgets('admin actions follow the request lifecycle', (tester) async {
    Future<List<Map<String, dynamic>>> loader(String status) async {
      if (status == 'approved_pending_payment') {
        return <Map<String, dynamic>>[
          <String, dynamic>{'id': 'request-2', 'applicantName': 'Brand B', 'applicantType': 'brand', 'status': status},
        ];
      }
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 'request-1', 'applicantName': 'Merchant A', 'applicantType': 'merchant', 'status': status},
      ];
    }

    await tester.pumpWidget(MaterialApp(home: AdminPublicCoalitionRequestsScreen(requestsLoader: loader)));
    await tester.pumpAndSettle();
    expect(find.text('Merchant A'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('approve'), findsOneWidget);
    expect(find.text('reject'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('public_coalition_status_payment').last);
    await tester.pumpAndSettle();
    expect(find.text('Brand B'), findsOneWidget);
    expect(find.text('public_coalition_admin_activate'), findsOneWidget);
  });
}