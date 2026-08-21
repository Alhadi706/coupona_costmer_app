import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_top_tabs.dart';
import 'customer_pos_qr_screen.dart';

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
  List<Map<String, dynamic>> _claims = const <Map<String, dynamic>>[];
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
        CompanyServerService.getMyRewardClaims(limit: 20),
      ]);

      if (!mounted) return;
      setState(() {
        _points = (results[0] as Map<String, dynamic>);
        _rewards = (results[1] as List<Map<String, dynamic>>);
        _ledger = (results[2] as List<Map<String, dynamic>>);
        _claims = (results[3] as List<Map<String, dynamic>>);
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
      final rewardKind = (reward['kind'] ?? 'digital').toString();
      final claim = await CompanyServerService.createRewardClaim(
        pointsCost: requiredPoints,
        sourceType: (reward['sourceType'] ?? 'system').toString(),
        sourceId: (reward['sourceId'] ?? reward['id'] ?? '').toString(),
        rewardKind: rewardKind,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_redeemed_success'.tr(
          namedArgs: {'reward': '${reward['reward_name'] ?? 'reward_generic'.tr()}'},
        ))),
      );
      await _loadData();
      if (!mounted) return;
      _showCouponDialog(
        rewardName: (reward['reward_name'] ?? '').toString(),
        rewardKind: rewardKind,
        pickupQrCode: (claim['pickupQrCode'] ?? '').toString(),
        digitalCode: (claim['digitalCode'] ?? '').toString(),
        status: (claim['status'] ?? '').toString(),
        expiresAt: (claim['expiresAt'] ?? '').toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_redeem_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _formatClaimStatus(String status) {
    switch (status) {
      case 'pending_pickup':
        return 'coupon_status_pending_pickup'.tr();
      case 'used':
      case 'redeemed':
        return 'coupon_status_used'.tr();
      case 'expired':
        return 'coupon_status_expired'.tr();
      case 'refunded_as_points':
        return 'coupon_status_refunded_as_points'.tr();
      default:
        return status;
    }
  }

  Color _claimStatusColor(String status) {
    switch (status) {
      case 'pending_pickup':
        return kGold;
      case 'used':
      case 'redeemed':
        return kTeal;
      case 'expired':
      case 'refunded_as_points':
        return Colors.grey;
      default:
        return kTeal;
    }
  }

  void _showCouponDialog({
    required String rewardName,
    required String rewardKind,
    required String pickupQrCode,
    required String digitalCode,
    required String status,
    required String expiresAt,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(rewardName.isEmpty ? 'reward_generic'.tr() : rewardName),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (rewardKind == 'physical' && pickupQrCode.isNotEmpty) ...[
                  Text('coupon_qr_hint'.tr(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  QrImageView(data: pickupQrCode, size: 200),
                  const SizedBox(height: 10),
                  SelectableText(pickupQrCode),
                ] else if (digitalCode.isNotEmpty) ...[
                  Text('coupon_digital_code_label'.tr()),
                  const SizedBox(height: 8),
                  SelectableText(
                    digitalCode,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTeal),
                  ),
                ],
                const SizedBox(height: 12),
                Text(_formatClaimStatus(status)),
                if (expiresAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('coupon_expires_at'.tr(namedArgs: {'value': expiresAt.split('T').first})),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('close'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availablePoints = _toInt(_points['availablePoints']);
    final kind = _rewardTab == 0 ? 'digital' : 'physical';
    final visibleRewards = _rewards.where((reward) {
      final rewardKind = (reward['kind'] ?? 'digital').toString().toLowerCase();
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CustomerPosQrScreen()),
                        );
                      },
                      icon: const Icon(Icons.qr_code),
                      label: Text('pos_qr_show_button'.tr()),
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
              final storeName = (reward['storeName'] ?? '').toString();
              final imageUrl = (reward['imageUrl'] ?? '').toString();
              final expiresAt = (reward['expiresAt'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? CircleAvatar(backgroundImage: NetworkImage(imageUrl))
                      : const Icon(Icons.card_giftcard, color: kTeal),
                  title: Text((reward['reward_name'] ?? '').toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text((reward['description'] ?? '').toString()),
                      if (storeName.isNotEmpty)
                        Text(
                          'reward_store_label'.tr(namedArgs: {'value': storeName}),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: kTeal),
                        ),
                      if (expiresAt.isNotEmpty)
                        Text('coupon_expires_at'.tr(namedArgs: {'value': expiresAt.split('T').first})),
                    ],
                  ),
                  isThreeLine: storeName.isNotEmpty || expiresAt.isNotEmpty,
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
            'my_coupons'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_claims.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('no_coupons_yet'.tr()),
              ),
            )
          else
            ..._claims.map((claim) {
              final status = (claim['status'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.confirmation_number_outlined, color: _claimStatusColor(status)),
                  title: Text('points_value'.tr(namedArgs: {'points': '${claim['pointsCost'] ?? 0}'})),
                  subtitle: Text(_formatClaimStatus(status)),
                  trailing: status == 'pending_pickup' || status == 'used'
                      ? IconButton(
                          icon: const Icon(Icons.qr_code, color: kTeal),
                          onPressed: () => _showCouponDialog(
                            rewardName: 'reward_generic'.tr(),
                            rewardKind: (claim['rewardKind'] ?? 'digital').toString(),
                            pickupQrCode: (claim['pickupQrCode'] ?? '').toString(),
                            digitalCode: (claim['digitalCode'] ?? '').toString(),
                            status: status,
                            expiresAt: (claim['expiresAt'] ?? '').toString(),
                          ),
                        )
                      : null,
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
              String formattedRef = ref;
              if (ref.startsWith('invoice:')) {
                formattedRef = 'ref_invoice_prefix'.tr() + ref.replaceFirst('invoice:', '');
              } else if (ref.startsWith('reward:')) {
                formattedRef = 'ref_reward_prefix'.tr() + ref.replaceFirst('reward:', '');
              } else if (ref.startsWith('manual:')) {
                formattedRef = 'ref_manual_prefix'.tr() + ref.replaceFirst('manual:', '');
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(_formatLedgerType((entry['type'] ?? '').toString())),
                  subtitle: Text(formattedRef),
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
