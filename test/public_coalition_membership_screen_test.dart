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

  test('notification target handles coalition and trial deep links', () {
    expect(
      notificationTarget(const <String, dynamic>{
        'type': 'coalition_activated',
        'targetScreen': 'public_coalition_membership',
      }),
      'clearing_house',
    );
    expect(
      notificationTarget(const <String, dynamic>{
        'type': 'subscription_warning',
      }),
      'wallet_top_up',
    );
    expect(
      notificationTarget(const <String, dynamic>{
        'payload': <String, dynamic>{'action_url': '/wallet/top-up'},
      }),
      'wallet_top_up',
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

  testWidgets('pending application shows review guidance and support contact, no payment action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'merchant',
        requestLoader: (_) async => <String, dynamic>{'id': 'request-1', 'status': 'pending_admin_review'},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-coalition-status-pending_admin_review')), findsOneWidget);
    expect(find.byKey(const Key('public-coalition-open-payment')), findsNothing);
    expect(find.byKey(const Key('public-coalition-contact-support')), findsOneWidget);
    expect(
      find.text('سيقوم مسؤول المنصة بمراجعة طلبك وإرسال تفاصيل التفعيل وتعبئة رصيدك.'),
      findsOneWidget,
    );
  });

  testWidgets('approved application shows admin message without any payment action', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'brand',
        requestLoader: (_) async => <String, dynamic>{
          'id': 'request-1',
          'status': 'approved_pending_payment',
          'adminMessage': 'Activation is handled via a platform-issued code.',
          'paymentUrl': 'https://payments.example/request-1',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Activation is handled via a platform-issued code.'), findsOneWidget);
    expect(find.byKey(const Key('public-coalition-open-payment')), findsNothing);
    expect(find.byKey(const Key('public-coalition-contact-support')), findsOneWidget);
  });

  testWidgets('active membership hides payment guidance and opens clearinghouse', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'merchant',
        requestLoader: (_) async => <String, dynamic>{
          'id': 'request-1',
          'status': 'active',
          'adminMessage': 'قم بالدفع للحصول على اشتراك وسيتوقف لاحقاً',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('عضويتك في الائتلاف العام نشطة وجاهزة للاستخدام'),
      findsOneWidget,
    );
    expect(find.textContaining('قم بالدفع'), findsNothing);
    expect(find.byKey(const Key('public-coalition-activation-code-input')), findsNothing);
    expect(find.byKey(const Key('public-coalition-open-clearinghouse')), findsOneWidget);
  });

  testWidgets('merchant can redeem an activation code; brand does not see the code card', (tester) async {
    String? redeemedCode;
    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'merchant',
        requestLoader: (_) async => null,
        codeActivationAction: (code) async {
          redeemedCode = code;
          return <String, dynamic>{'ok': true, 'creditedPoints': 1000, 'balance': 1000};
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-coalition-activation-code-input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('public-coalition-activation-code-input')), 'GOLD-1234');
    await tester.tap(find.byKey(const Key('public-coalition-activate-code')));
    await tester.pumpAndSettle();
    expect(redeemedCode, 'GOLD-1234');

    await tester.pumpWidget(MaterialApp(
      home: PublicCoalitionMembershipScreen(
        applicantType: 'brand',
        requestLoader: (_) async => null,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public-coalition-activation-code-input')), findsNothing);
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