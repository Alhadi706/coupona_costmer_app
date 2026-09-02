import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef TeamInvitationsLoader = Future<List<Map<String, dynamic>>> Function();
typedef TeamInvitationResponder = Future<Map<String, dynamic>> Function(String invitationId, bool accept);

class TeamInvitationsScreen extends StatefulWidget {
  final TeamInvitationsLoader? invitationsLoader;
  final TeamInvitationResponder? responder;

  const TeamInvitationsScreen({super.key, this.invitationsLoader, this.responder});

  @override
  State<TeamInvitationsScreen> createState() => _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends State<TeamInvitationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _invitations = const [];

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
      final rows = widget.invitationsLoader != null
          ? await widget.invitationsLoader!()
          : <Map<String, dynamic>>[
              ...await CompanyServerService.getMyMerchantTeamInvitations(),
              ...await CompanyServerService.getMyBrandTeamInvitations(),
            ];
      if (mounted) setState(() => _invitations = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> invitation, bool accept) async {
    final id = invitation['id'].toString();
    if (widget.responder != null) {
      await widget.responder!(id, accept);
    } else if ((invitation['brandId'] ?? '').toString().isNotEmpty) {
      await CompanyServerService.respondToBrandTeamInvitation(id, accept: accept);
    } else {
      await CompanyServerService.respondToMerchantTeamInvitation(id, accept: accept);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('team_invitations_title', 'Team invitations'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(_tx('retry', 'Retry'))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _invitations.isEmpty
                        ? [ListTile(title: Text(_tx('team_invitations_empty', 'No pending team invitations.')))]
                        : _invitations.map((invitation) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text((invitation['merchantName'] ?? invitation['brandName'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text((invitation['brandId'] ?? '').toString().isNotEmpty
                                      ? _tx('brand_team_title', 'Brand team')
                                      : '${invitation['branchName'] ?? ''} • ${invitation['roleType'] ?? ''}'),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: FilledButton(
                                        key: Key('team-invitation-accept-${invitation['id']}'),
                                        onPressed: () => _respond(invitation, true),
                                        child: Text(_tx('accept', 'Accept')),
                                      )),
                                      const SizedBox(width: 8),
                                      Expanded(child: OutlinedButton(
                                        key: Key('team-invitation-reject-${invitation['id']}'),
                                        onPressed: () => _respond(invitation, false),
                                        child: Text(_tx('reject', 'Reject')),
                                      )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )).toList(),
                  ),
                ),
    );
  }
}