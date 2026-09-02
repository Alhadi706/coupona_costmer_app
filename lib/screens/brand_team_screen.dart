import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef BrandTeamLoader = Future<Map<String, dynamic>> Function();
typedef BrandTeamInviter = Future<Map<String, dynamic>> Function({required String emailOrPhone, required bool canManageProducts, required bool canViewGeoDistribution});
typedef BrandTeamRevoker = Future<void> Function(String userId);

class BrandTeamScreen extends StatefulWidget {
  final BrandTeamLoader? loader;
  final BrandTeamInviter? inviter;
  final BrandTeamRevoker? revoker;

  const BrandTeamScreen({super.key, this.loader, this.inviter, this.revoker});

  @override
  State<BrandTeamScreen> createState() => _BrandTeamScreenState();
}

class _BrandTeamScreenState extends State<BrandTeamScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _team = const {};

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await (widget.loader ?? CompanyServerService.getBrandTeam)();
      if (mounted) setState(() => _team = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _rows(String key) {
    final rows = _team[key];
    return rows is List ? rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : const [];
  }

  Future<void> _invite() async {
    var identifier = '';
    var canManageProducts = false;
    var canViewGeo = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_tx('brand_team_invite', 'Invite brand team member')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(key: const Key('brand-team-identifier'), onChanged: (value) => identifier = value, decoration: InputDecoration(labelText: _tx('brand_team_email_phone', 'Registered email or phone'))),
              CheckboxListTile(value: canManageProducts, title: Text(_tx('brand_can_manage_products', 'Manage products')), onChanged: (value) => setDialogState(() => canManageProducts = value == true)),
              CheckboxListTile(value: canViewGeo, title: Text(_tx('brand_can_view_geo_distribution', 'View geographic distribution')), onChanged: (value) => setDialogState(() => canViewGeo = value == true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_tx('cancel', 'Cancel'))),
            FilledButton(key: const Key('brand-team-send'), onPressed: () => Navigator.pop(dialogContext, true), child: Text(_tx('brand_team_send_invite', 'Send invitation'))),
          ],
        ),
      ),
    );
    if (accepted != true || identifier.trim().isEmpty) return;
    await (widget.inviter ?? CompanyServerService.inviteBrandTeamMember)(emailOrPhone: identifier.trim(), canManageProducts: canManageProducts, canViewGeoDistribution: canViewGeo);
    await _load();
  }

  Future<void> _revoke(String userId) async {
    await (widget.revoker ?? CompanyServerService.revokeBrandTeamMember)(userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tx('brand_team_title', 'Brand team')),
        actions: [IconButton(key: const Key('brand-team-invite'), onPressed: _invite, icon: const Icon(Icons.person_add_alt_1))],
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
                      Text(_tx('brand_team_members', 'Members'), style: Theme.of(context).textTheme.titleMedium),
                      ..._rows('members').map((member) => Card(child: ListTile(
                        title: Text((member['name'] ?? member['email'] ?? member['phone'] ?? '-').toString()),
                        subtitle: Text([
                          if (member['canManageProducts'] == true) _tx('brand_can_manage_products', 'Manage products'),
                          if (member['canViewGeoDistribution'] == true) _tx('brand_can_view_geo_distribution', 'View geographic distribution'),
                        ].join(' • ')),
                        trailing: IconButton(key: Key('brand-team-revoke-${member['userId']}'), onPressed: () => _revoke(member['userId'].toString()), icon: const Icon(Icons.person_remove_outlined)),
                      ))),
                      const SizedBox(height: 16),
                      Text(_tx('brand_team_pending', 'Pending invitations'), style: Theme.of(context).textTheme.titleMedium),
                      ..._rows('invitations').map((invitation) => Card(child: ListTile(
                        title: Text((invitation['name'] ?? invitation['email'] ?? invitation['phone'] ?? '-').toString()),
                        trailing: const Chip(label: Text('pending')),
                      ))),
                    ],
                  ),
                ),
    );
  }
}
