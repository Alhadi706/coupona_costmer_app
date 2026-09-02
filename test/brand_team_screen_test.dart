import 'package:coupona_app/screens/brand_team_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand owner invites and revokes team members with explicit permissions', (tester) async {
    final members = <Map<String, dynamic>>[
      {'userId': 'member-1', 'name': 'Existing Member', 'canManageProducts': true, 'canViewGeoDistribution': false},
    ];
    final invitations = <Map<String, dynamic>>[];
    Map<String, dynamic>? submitted;

    await tester.pumpWidget(MaterialApp(
      home: BrandTeamScreen(
        loader: () async => {'members': members, 'invitations': invitations},
        inviter: ({required emailOrPhone, required canManageProducts, required canViewGeoDistribution}) async {
          submitted = {'emailOrPhone': emailOrPhone, 'canManageProducts': canManageProducts, 'canViewGeoDistribution': canViewGeoDistribution};
          invitations.add({'id': 'invite-1', 'email': emailOrPhone, 'status': 'pending'});
          return {'id': 'invite-1'};
        },
        revoker: (userId) async => members.removeWhere((member) => member['userId'] == userId),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Existing Member'), findsOneWidget);
    await tester.tap(find.byKey(const Key('brand-team-revoke-member-1')));
    await tester.pumpAndSettle();
    expect(find.text('Existing Member'), findsNothing);

    await tester.tap(find.byKey(const Key('brand-team-invite')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('brand-team-identifier')), 'member@example.com');
    await tester.tap(find.text('Manage products'));
    await tester.tap(find.byKey(const Key('brand-team-send')));
    await tester.pumpAndSettle();

    expect(submitted, {'emailOrPhone': 'member@example.com', 'canManageProducts': true, 'canViewGeoDistribution': false});
    expect(find.text('member@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
