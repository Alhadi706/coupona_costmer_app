import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/company_server_service.dart';
import '../../theme/design_tokens.dart';
import 'create_private_coalition_dialog.dart';

class CoalitionDashboardScreen extends StatefulWidget {
  final int initialTabIndex;

  const CoalitionDashboardScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CoalitionDashboardScreen> createState() => _CoalitionDashboardScreenState();
}

class _CoalitionDashboardScreenState extends State<CoalitionDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  bool _publicLoading = true;
  bool _publicActive = false;
  int _walletBalance = 0;
  String? _error;
  List<Map<String, dynamic>> _myCoalitions = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _discoverCoalitions = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invitations = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = widget.initialTabIndex.clamp(0, 2);
    _load();
    _loadPublicStatus();
  }

  Future<void> _loadPublicStatus() async {
    try {
      final result = await CompanyServerService.getPublicCoalitionWalletBalance();
      if (!mounted) return;
      setState(() {
        _walletBalance = int.tryParse('${result['balance'] ?? 0}') ?? 0;
        _publicActive = result['isPublicCoalitionActive'] == true;
        _publicLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _publicLoading = false);
    }
  }

  Future<void> _activatePublicCoalition() async {
    try {
      final result = await CompanyServerService.activatePublicCoalition();
      if (!mounted) return;
      setState(() {
        _publicActive = result['isPublicCoalitionActive'] == true;
        _walletBalance = int.tryParse('${result['balance'] ?? _walletBalance}') ?? _walletBalance;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('coalition_public_activation_success'.tr())));
    } catch (error) {
      if (error.toString().contains('public_coalition_top_up_required')) {
        _showTopUpDialog();
      } else {
        _showError(error.toString());
      }
    }
  }

  void _showTopUpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('coalition_public_top_up_title'.tr()),
        content: Text('coalition_public_top_up_message'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('coalition_cancel'.tr())),
          ...[100, 250, 500].map((amount) => FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    final result = await CompanyServerService.topUpPublicCoalitionWallet(amount);
                    if (!mounted) return;
                    setState(() {
                      _walletBalance = int.tryParse('${result['balance'] ?? 0}') ?? 0;
                      _publicActive = result['isPublicCoalitionActive'] == true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('coalition_public_activation_success'.tr())));
                  } catch (error) {
                    _showError(error.toString());
                  }
                },
                child: Text('coalition_public_top_up_package'.tr(namedArgs: {'amount': '$amount'})),
              )),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait(<Future<dynamic>>[
        CompanyServerService.getMerchantCoalitionsMine(),
        CompanyServerService.getMerchantCoalitions(),
        CompanyServerService.getMerchantCoalitionInvitations(),
      ]);

      if (!mounted) return;
      setState(() {
        _myCoalitions = List<Map<String, dynamic>>.from((results[0] as Map<String, dynamic>)['coalitions'] ?? const <dynamic>[]);
        _discoverCoalitions = List<Map<String, dynamic>>.from((results[1] as Map<String, dynamic>)['coalitions'] ?? const <dynamic>[]);
        _invitations = List<Map<String, dynamic>>.from((results[2] as Map<String, dynamic>)['invitations'] ?? const <dynamic>[]);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _joinCoalition(String coalitionId) async {
    try {
      await CompanyServerService.joinMerchantCoalition(coalitionId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('coalition_join_request_confirmed'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _respondToInvitation(String invitationId, bool accepted) async {
    try {
      if (accepted) {
        await CompanyServerService.acceptMerchantCoalitionInvitation(invitationId);
      } else {
        await CompanyServerService.rejectMerchantCoalitionInvitation(invitationId);
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('coalition_screen_title'.tr()),
        actions: [
          IconButton(
            onPressed: () async {
              await CreatePrivateCoalitionDialog.show(context);
              await _load();
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'coalition_create_private'.tr(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'coalition_tab_active'.tr()),
            Tab(text: 'coalition_tab_discover'.tr()),
            Tab(text: 'coalition_tab_invitations'.tr()),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: kGold)),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyCoalitions(),
                    _buildDiscoverTab(),
                    _buildInvitationTab(),
                  ],
                ),
    );
  }

  Widget _buildMyCoalitions() {
    final cards = _myCoalitions
        .map((coalition) {
          final type = (coalition['type'] ?? 'general').toString();
          final memberCount = (coalition['member_count'] ?? coalition['memberCount'] ?? 0).toString();
          final status = (coalition['is_active'] ?? coalition['isActive'] ?? true) == true
              ? 'coalition_status_active'.tr()
              : 'coalition_status_inactive'.tr();

          return Card(
            child: ListTile(
              title: Text((coalition['name'] ?? 'coalition_untitled'.tr()).toString()),
              subtitle: Text('coalition_membership_summary'.tr(namedArgs: {
                'type': type,
                'members': memberCount,
                'status': status,
              })),
              trailing: const Icon(Icons.groups_outlined),
            ),
          );
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPublicCoalitionCard(),
        const SizedBox(height: 12),
        _buildGuideCard(
          titleKey: 'coalition_guide_my_title',
          stepKeys: const [
            'coalition_guide_my_step_1',
            'coalition_guide_my_step_2',
            'coalition_guide_my_step_3',
          ],
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          Card(
            child: ListTile(
              title: Text('coalition_my_empty'.tr()),
            ),
          )
        else
          ...cards,
      ],
    );
  }

  Widget _buildDiscoverTab() {
    final cards = _discoverCoalitions
        .where((coalition) => (coalition['type'] ?? '').toString() == 'private')
        .map((coalition) {
          final type = (coalition['type'] ?? 'general').toString();
          final memberCount = (coalition['member_count'] ?? coalition['memberCount'] ?? 0).toString();
          final region = (coalition['region'] ?? coalition['city'] ?? 'coalition_region_global'.tr()).toString();
          final isMember = coalition['is_member'] == true || coalition['isMember'] == true;

          return Card(
            child: ListTile(
              title: Text((coalition['name'] ?? 'coalition_unknown'.tr()).toString()),
              subtitle: Text('coalition_discover_summary'.tr(namedArgs: {
                'type': type,
                'members': memberCount,
                'region': region,
              })),
              trailing: FilledButton(
                onPressed: isMember ? null : () => _joinCoalition((coalition['id'] ?? '').toString()),
                child: Text(isMember ? 'coalition_joined'.tr() : 'coalition_join_request'.tr()),
              ),
            ),
          );
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          titleKey: 'coalition_private_discover_title',
          stepKeys: const [
            'coalition_private_discover_step_1',
            'coalition_private_discover_step_2',
            'coalition_private_discover_step_3',
          ],
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          Card(
            child: ListTile(
              title: Text('coalition_private_discover_empty'.tr()),
            ),
          )
        else
          ...cards,
      ],
    );
  }

  Widget _buildPublicCoalitionCard() {
    if (_publicLoading) return const LinearProgressIndicator();
    return Card(
      color: _publicActive ? Colors.green.shade50 : Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_publicActive ? Icons.check_circle : Icons.public, color: _publicActive ? Colors.green : Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text('coalition_public_header'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ]),
          if (_publicActive) ...[
            const SizedBox(height: 8),
            Text(
              'coalition_public_active_badge'.tr(),
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 8),
          Text('coalition_public_description'.tr()),
          const SizedBox(height: 8),
          Text('coalition_public_wallet_balance'.tr(namedArgs: {'points': '$_walletBalance'})),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _publicActive ? _showTopUpDialog : _activatePublicCoalition,
            icon: Icon(_publicActive ? Icons.add_card : Icons.bolt),
            label: Text(_publicActive ? 'coalition_public_recharge_button'.tr() : 'coalition_public_activate_button'.tr()),
          ),
        ]),
      ),
    );
  }

  Widget _buildInvitationTab() {
    final cards = _invitations
        .map((invitation) {
          final coalitionName = (invitation['coalition_name'] ?? invitation['name'] ?? 'coalition_label'.tr()).toString();
          final inviterName = (invitation['inviter_name'] ?? invitation['inviterName'] ?? 'coalition_merchant_generic'.tr()).toString();

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coalitionName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('coalition_invited_by'.tr(namedArgs: {'name': inviterName})),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _respondToInvitation((invitation['id'] ?? '').toString(), true),
                          child: Text('coalition_accept'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respondToInvitation((invitation['id'] ?? '').toString(), false),
                          child: Text('coalition_reject'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          titleKey: 'coalition_guide_invitations_title',
          stepKeys: const [
            'coalition_guide_invitations_step_1',
            'coalition_guide_invitations_step_2',
            'coalition_guide_invitations_step_3',
          ],
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          Card(
            child: ListTile(
              title: Text('coalition_invitations_empty'.tr()),
            ),
          )
        else
          ...cards,
      ],
    );
  }

  Widget _buildGuideCard({required String titleKey, required List<String> stepKeys}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleKey.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...stepKeys.map((key) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${key.tr()}'),
              )),
        ],
      ),
    );
  }
}
