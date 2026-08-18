import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_top_tabs.dart';

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen> {
  bool _loading = true;
  bool _redeeming = false;
  Map<String, dynamic> _points = const <String, dynamic>{};
  List<Map<String, dynamic>> _rewards = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];
  int _rewardTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await CompanyServerService.ensureAccountingDocuments();
      final results = await Future.wait<dynamic>([
        CompanyServerService.getPointAccount(),
        CompanyServerService.getRewards(),
        CompanyServerService.getLedgerEntries(limit: 20),
      ]);

      if (!mounted) return;
      setState(() {
        _points = (results[0] as Map<String, dynamic>);
        _rewards = (results[1] as List<Map<String, dynamic>>);
        _ledger = (results[2] as List<Map<String, dynamic>>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('rewards_load_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatLedgerType(String type) {
    switch (type) {
      case 'cashbackEarned':
        return 'ledger_cashback_earned'.tr();
      case 'pointsEarned':
        return 'ledger_points_earned'.tr();
      case 'pointsRedeemed':
        return 'ledger_points_redeemed'.tr();
      default:
        return type;
    }
  }

  Future<void> _redeemReward(Map<String, dynamic> reward) async {
    if (_redeeming) return;
    final requiredPoints = _toInt(reward['value']);
    final currentPoints = _toInt(_points['availablePoints']);
    if (requiredPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_invalid_value'.tr())),
      );
      return;
    }
    if (currentPoints < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_insufficient_points'.tr())),
      );
      return;
    }

    setState(() => _redeeming = true);
    try {
      await CompanyServerService.redeemPoints(
        points: requiredPoints,
        reference: 'reward:${reward['id'] ?? reward['reward_name']}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'reward_redeemed_success'.tr(
              namedArgs: {'reward': '${reward['reward_name'] ?? 'reward_generic'.tr()}'},
            ),
          ),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_redeem_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availablePoints = _toInt(_points['availablePoints']);
    final kind = _rewardTab == 0 ? 'digital' : 'physical';
    final visibleRewards = _rewards.where((reward) {
      final rewardKind = (reward['rewardKind'] ?? reward['kind'] ?? '').toString().toLowerCase();
      if (rewardKind.isEmpty) return _rewardTab == 0;
      return rewardKind == kind;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'your_points_balance'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$availablePoints',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: kTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          KupunaTopTabs(
            tabs: const <String>['رقمي', 'مادي'],
            activeIndex: _rewardTab,
            onSelect: (index) => setState(() => _rewardTab = index),
          ),
          const SizedBox(height: 10),
          Text(
            'available_rewards'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (visibleRewards.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('no_rewards_available_now'.tr()),
              ),
            )
          else
            ...visibleRewards.map((reward) {
              final cost = _toInt(reward['value']);
              final canRedeem = availablePoints >= cost;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard, color: kTeal),
                  title: Text((reward['reward_name'] ?? '').toString()),
                  subtitle: Text((reward['description'] ?? '').toString()),
                  trailing: ElevatedButton(
                    onPressed: canRedeem && !_redeeming
                        ? () => _redeemReward(reward)
                        : null,
                    child: Text('redeem_points_value'.tr(namedArgs: {'value': '$cost'})),
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          Text(
            'transactions_log'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_ledger.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('no_log_entries_yet'.tr()),
              ),
            )
          else
            ..._ledger.map((entry) {
              final amount = (entry['amount'] is num)
                  ? (entry['amount'] as num).toDouble()
                  : double.tryParse(entry['amount']?.toString() ?? '') ?? 0;
              final points = _toInt(entry['points']);
              final ref = (entry['reference'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(_formatLedgerType((entry['type'] ?? '').toString())),
                  subtitle: Text(ref),
                  trailing: Text(
                    points > 0
                        ? 'points_value'.tr(namedArgs: {'points': '+$points'})
                        : 'currency_amount_value'.tr(namedArgs: {'amount': '+${amount.toStringAsFixed(2)}'}),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
