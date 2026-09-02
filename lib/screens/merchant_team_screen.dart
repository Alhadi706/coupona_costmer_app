import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef MerchantTeamLoader = Future<Map<String, dynamic>> Function();
typedef MerchantTeamInviter = Future<Map<String, dynamic>> Function({
  required String branchId,
  required String roleType,
  required String emailOrPhone,
  required Map<String, bool> permissions,
});
typedef MerchantTeamRevoker = Future<void> Function({
  required String roleType,
  required String branchId,
  required String userId,
});
typedef MerchantManagerPermissionsUpdater = Future<Map<String, dynamic>> Function({
  required String branchId,
  required String userId,
  required Map<String, bool> permissions,
});
typedef MerchantTeamInvitationCanceller = Future<void> Function(String invitationId);

class MerchantTeamScreen extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final MerchantTeamLoader? teamLoader;
  final MerchantTeamInviter? inviter;
  final MerchantTeamRevoker? revoker;
  final MerchantManagerPermissionsUpdater? permissionsUpdater;
  final MerchantTeamInvitationCanceller? invitationCanceller;

  const MerchantTeamScreen({
    super.key,
    required this.branches,
    this.teamLoader,
    this.inviter,
    this.revoker,
    this.permissionsUpdater,
    this.invitationCanceller,
  });

  @override
  State<MerchantTeamScreen> createState() => _MerchantTeamScreenState();
}

class _MerchantTeamScreenState extends State<MerchantTeamScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _team = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await (widget.teamLoader ?? CompanyServerService.getMerchantTeam)();
      if (mounted) setState(() => _team = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _rows(String key) {
    final rows = _team[key];
    return rows is List
        ? rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
        : const [];
  }

  Future<void> _showInviteDialog() async {
    if (widget.branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_tx('merchant_team_branch_required', 'Create a branch before inviting team members.'))));
      return;
    }
    var branchId = (widget.branches.first['id'] ?? '').toString();
    var roleType = 'manager';
    var identifier = '';
    final permissions = <String, bool>{
      'canReviewInvoices': false,
      'canCreateOffers': false,
      'canManageGroup': false,
      'canViewReports': false,
      'canViewSettlements': false,
      'canAddCashiers': false,
      'canReplyReports': false,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('merchant_team_invite_title', 'Invite team member')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('merchant-team-branch'),
                  initialValue: branchId,
                  items: widget.branches.map((branch) => DropdownMenuItem(
                    value: (branch['id'] ?? '').toString(),
                    child: Text((branch['name'] ?? '').toString()),
                  )).toList(),
                  onChanged: (value) => branchId = value ?? branchId,
                  decoration: InputDecoration(labelText: _tx('merchant_branch', 'Branch')),
                ),
                DropdownButtonFormField<String>(
                  key: const Key('merchant-team-role'),
                  initialValue: roleType,
                  items: [
                    DropdownMenuItem(value: 'manager', child: Text(_tx('merchant_team_role_manager', 'Manager'))),
                    DropdownMenuItem(value: 'cashier', child: Text(_tx('merchant_team_role_cashier', 'Cashier'))),
                  ],
                  onChanged: (value) => setDialogState(() => roleType = value ?? roleType),
                  decoration: InputDecoration(labelText: _tx('merchant_team_role', 'Role')),
                ),
                TextField(
                  key: const Key('merchant-team-identifier'),
                  onChanged: (value) => identifier = value,
                  decoration: InputDecoration(labelText: _tx('merchant_team_email_phone', 'Registered email or phone')),
                ),
                if (roleType == 'manager')
                  ...permissions.keys.map((key) => CheckboxListTile(
                    value: permissions[key],
                    title: Text(_tx('merchant_permission_$key', key)),
                    onChanged: (value) => setDialogState(() => permissions[key] = value == true),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_tx('cancel', 'Cancel'))),
            FilledButton(
              key: const Key('merchant-team-send-invite'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tx('merchant_team_send_invite', 'Send invitation')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || identifier.trim().isEmpty) return;
    await (widget.inviter ?? CompanyServerService.inviteMerchantTeamMember)(
      branchId: branchId,
      roleType: roleType,
      emailOrPhone: identifier.trim(),
      permissions: permissions,
    );
    await _load();
  }

  Future<void> _revoke(Map<String, dynamic> member, String roleType) async {
    await (widget.revoker ?? CompanyServerService.revokeMerchantTeamAccess)(
      roleType: roleType,
      branchId: member['branchId'].toString(),
      userId: member['userId'].toString(),
    );
    await _load();
  }

  Future<void> _editManagerPermissions(Map<String, dynamic> member) async {
    final source = member['permissions'];
    final permissions = <String, bool>{
      for (final key in const [
        'canReviewInvoices', 'canCreateOffers', 'canManageGroup',
        'canViewReports', 'canViewSettlements', 'canAddCashiers', 'canReplyReports',
      ])
        key: source is Map && source[key] == true,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('merchant_team_edit_permissions', 'Edit manager permissions')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: permissions.keys.map((key) => CheckboxListTile(
                value: permissions[key],
                title: Text(_tx('merchant_permission_$key', key)),
                onChanged: (value) => setDialogState(() => permissions[key] = value == true),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_tx('cancel', 'Cancel'))),
            FilledButton(
              key: const Key('merchant-team-save-permissions'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tx('save', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await (widget.permissionsUpdater ?? ({required branchId, required userId, required permissions}) =>
        CompanyServerService.updateBranchManagerPermissions(
          branchId: branchId,
          userId: userId,
          canReviewInvoices: permissions['canReviewInvoices'],
          canCreateOffers: permissions['canCreateOffers'],
          canManageGroup: permissions['canManageGroup'],
          canViewReports: permissions['canViewReports'],
          canViewSettlements: permissions['canViewSettlements'],
          canAddCashiers: permissions['canAddCashiers'],
          canReplyReports: permissions['canReplyReports'],
        ))(
      branchId: member['branchId'].toString(),
      userId: member['userId'].toString(),
      permissions: permissions,
    );
    await _load();
  }

  Future<void> _cancelInvitation(Map<String, dynamic> invitation) async {
    await (widget.invitationCanceller ?? CompanyServerService.cancelMerchantTeamInvitation)(invitation['id'].toString());
    await _load();
  }

  String _permissionSummary(Map<String, dynamic> member) {
    final source = member['permissions'];
    if (source is! Map) return '';
    final enabled = source.entries.where((entry) => entry.value == true).map((entry) =>
        _tx('merchant_permission_${entry.key}', entry.key.toString())).toList();
    return enabled.isEmpty ? _tx('merchant_team_no_permissions', 'No permissions') : enabled.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tx('merchant_team_title', 'Store team')),
        actions: [IconButton(onPressed: _showInviteDialog, icon: const Icon(Icons.person_add_alt_1), tooltip: _tx('merchant_team_invite_title', 'Invite team member'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(_tx('retry', 'Retry'))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section(_tx('merchant_team_managers', 'Managers'), _rows('managers'), 'manager'),
                      _section(_tx('merchant_team_cashiers', 'Cashiers'), _rows('cashiers'), 'cashier'),
                      _invitationSection(_rows('invitations')),
                    ],
                  ),
                ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> rows, String roleType) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('$title (${rows.length})'),
        children: rows.isEmpty
            ? [ListTile(title: Text(_tx('merchant_team_empty', 'No team members in this section.')))]
            : rows.map((member) => ListTile(
                title: Text((member['name'] ?? member['email'] ?? member['phone'] ?? '-').toString()),
                subtitle: Text('${member['branchName'] ?? ''}${roleType == 'manager' ? '\n${_permissionSummary(member)}' : ''}'),
                isThreeLine: roleType == 'manager',
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (roleType == 'manager')
                      IconButton(
                        key: Key('merchant-team-edit-manager-${member['userId']}'),
                        onPressed: () => _editManagerPermissions(member),
                        icon: const Icon(Icons.tune_outlined),
                        tooltip: _tx('merchant_team_edit_permissions', 'Edit manager permissions'),
                      ),
                    IconButton(
                      key: Key('merchant-team-revoke-$roleType-${member['userId']}'),
                      onPressed: () => _revoke(member, roleType),
                      icon: const Icon(Icons.person_remove_outlined),
                      tooltip: _tx('merchant_team_revoke', 'Revoke access'),
                    ),
                  ],
                ),
              )).toList(),
      ),
    );
  }

  Widget _invitationSection(List<Map<String, dynamic>> invitations) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('${_tx('merchant_team_pending_invitations', 'Pending invitations')} (${invitations.length})'),
        children: invitations.isEmpty
            ? [ListTile(title: Text(_tx('merchant_team_no_pending', 'No pending invitations.')))]
            : invitations.map((invitation) => ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: Text((invitation['invitedUserName'] ?? invitation['invitedUserEmail'] ?? invitation['invitedUserPhone'] ?? '-').toString()),
                subtitle: Text('${invitation['branchName'] ?? ''} • ${invitation['roleType'] ?? ''}'),
                trailing: IconButton(
                  key: Key('merchant-team-cancel-invite-${invitation['id']}'),
                  onPressed: () => _cancelInvitation(invitation),
                  icon: const Icon(Icons.cancel_outlined),
                  tooltip: _tx('merchant_team_cancel_invitation', 'Cancel invitation'),
                ),
              )).toList(),
      ),
    );
  }
}