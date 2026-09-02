import 'package:coupona_app/screens/merchant_team_screen.dart';
import 'package:coupona_app/screens/team_invitations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('merchant sees branch team and can revoke cashier access', (tester) async {
    String? revokedRole;
    String? revokedUser;
    var revoked = false;
    Future<Map<String, dynamic>> loadTeam() async => <String, dynamic>{
      'managers': <Map<String, dynamic>>[],
      'cashiers': revoked ? <Map<String, dynamic>>[] : <Map<String, dynamic>>[
        <String, dynamic>{'userId': 'cashier-1', 'name': 'Cashier One', 'branchId': 'branch-1', 'branchName': 'Main Branch', 'isActive': true},
      ],
      'invitations': <Map<String, dynamic>>[],
    };

    await tester.pumpWidget(MaterialApp(home: MerchantTeamScreen(
      branches: const <Map<String, dynamic>>[<String, dynamic>{'id': 'branch-1', 'name': 'Main Branch'}],
      teamLoader: loadTeam,
      revoker: ({required roleType, required branchId, required userId}) async {
        revokedRole = roleType;
        revokedUser = userId;
        revoked = true;
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Cashier One'), findsOneWidget);
    expect(find.text('Main Branch'), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchant-team-revoke-cashier-cashier-1')));
    await tester.pumpAndSettle();

    expect(revokedRole, 'cashier');
    expect(revokedUser, 'cashier-1');
    expect(find.text('Cashier One'), findsNothing);
  });

  testWidgets('merchant sends manager invitation by registered email with permissions', (tester) async {
    String? invitedBranch;
    String? invitedRole;
    String? invitedIdentifier;
    Map<String, bool>? invitedPermissions;

    await tester.pumpWidget(MaterialApp(home: MerchantTeamScreen(
      branches: const <Map<String, dynamic>>[<String, dynamic>{'id': 'branch-1', 'name': 'Main Branch'}],
      teamLoader: () async => <String, dynamic>{'managers': [], 'cashiers': [], 'invitations': []},
      inviter: ({required branchId, required roleType, required emailOrPhone, required permissions}) async {
        invitedBranch = branchId;
        invitedRole = roleType;
        invitedIdentifier = emailOrPhone;
        invitedPermissions = permissions;
        return <String, dynamic>{'id': 'invite-1', 'status': 'pending'};
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Invite team member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('merchant-team-identifier')), 'staff@example.com');
    await tester.tap(find.text('canReviewInvoices'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('merchant-team-send-invite')));
    await tester.pumpAndSettle();

    expect(invitedBranch, 'branch-1');
    expect(invitedRole, 'manager');
    expect(invitedIdentifier, 'staff@example.com');
    expect(invitedPermissions?['canReviewInvoices'], isTrue);
  });

  testWidgets('invitee accepts a branch role and invitation leaves the list', (tester) async {
    final invitations = <Map<String, dynamic>>[
      <String, dynamic>{'id': 'invite-1', 'merchantName': 'Demo Store', 'branchName': 'Main Branch', 'roleType': 'manager'},
    ];
    String? respondedId;
    bool? accepted;

    await tester.pumpWidget(MaterialApp(home: TeamInvitationsScreen(
      invitationsLoader: () async => invitations.map(Map<String, dynamic>.from).toList(),
      responder: (invitationId, accept) async {
        respondedId = invitationId;
        accepted = accept;
        invitations.clear();
        return <String, dynamic>{'ok': true, 'status': 'accepted'};
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Demo Store'), findsOneWidget);
    expect(find.textContaining('Main Branch'), findsOneWidget);
    await tester.tap(find.byKey(const Key('team-invitation-accept-invite-1')));
    await tester.pumpAndSettle();

    expect(respondedId, 'invite-1');
    expect(accepted, isTrue);
    expect(find.text('Demo Store'), findsNothing);
    expect(find.text('No pending team invitations.'), findsOneWidget);
  });

  testWidgets('merchant edits manager permissions after acceptance', (tester) async {
    Map<String, bool>? savedPermissions;
    await tester.pumpWidget(MaterialApp(home: MerchantTeamScreen(
      branches: const <Map<String, dynamic>>[<String, dynamic>{'id': 'branch-1', 'name': 'Main Branch'}],
      teamLoader: () async => <String, dynamic>{
        'managers': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'manager-1', 'name': 'Manager One', 'branchId': 'branch-1', 'branchName': 'Main Branch',
            'permissions': <String, bool>{'canReviewInvoices': true},
          },
        ],
        'cashiers': <Map<String, dynamic>>[],
        'invitations': <Map<String, dynamic>>[],
      },
      permissionsUpdater: ({required branchId, required userId, required permissions}) async {
        savedPermissions = Map<String, bool>.from(permissions);
        return <String, dynamic>{'ok': true};
      },
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('canReviewInvoices'), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchant-team-edit-manager-manager-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('canCreateOffers'));
    await tester.tap(find.byKey(const Key('merchant-team-save-permissions')));
    await tester.pumpAndSettle();

    expect(savedPermissions?['canReviewInvoices'], isTrue);
    expect(savedPermissions?['canCreateOffers'], isTrue);
  });

  testWidgets('merchant cancels a pending invitation', (tester) async {
    var pending = true;
    String? cancelledId;
    await tester.pumpWidget(MaterialApp(home: MerchantTeamScreen(
      branches: const <Map<String, dynamic>>[<String, dynamic>{'id': 'branch-1', 'name': 'Main Branch'}],
      teamLoader: () async => <String, dynamic>{
        'managers': <Map<String, dynamic>>[],
        'cashiers': <Map<String, dynamic>>[],
        'invitations': pending ? <Map<String, dynamic>>[
          <String, dynamic>{'id': 'invite-1', 'invitedUserEmail': 'staff@example.com', 'branchName': 'Main Branch', 'roleType': 'manager'},
        ] : <Map<String, dynamic>>[],
      },
      invitationCanceller: (invitationId) async {
        cancelledId = invitationId;
        pending = false;
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('staff@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchant-team-cancel-invite-invite-1')));
    await tester.pumpAndSettle();

    expect(cancelledId, 'invite-1');
    expect(find.text('staff@example.com'), findsNothing);
  });
}