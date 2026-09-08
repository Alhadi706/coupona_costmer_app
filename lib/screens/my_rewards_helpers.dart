part of 'package:coupona_app/screens/my_rewards_screen.dart';

extension _MyRewardsHelpers on _MyRewardsScreenState {
  Widget _buildTierCounters() {
    final tiers = (_tiers['tiers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final definitions = <Map<String, dynamic>>[
      {'key': 'bronze', 'label': 'wallet_bronze_points', 'shortLabel': 'برونزي', 'icon': Icons.workspace_premium_outlined, 'color': Colors.brown},
      {'key': 'silver', 'label': 'wallet_silver_points', 'shortLabel': 'فضي', 'icon': Icons.workspace_premium_outlined, 'color': Colors.blueGrey},
      {'key': 'gold', 'label': 'wallet_gold_points', 'shortLabel': 'ذهبي', 'icon': Icons.workspace_premium_outlined, 'color': Colors.amber.shade800},
    ];
    return Row(
      children: definitions.map((definition) {
        final tierKey = definition['key'] as String;
        final tier = (tiers[tierKey] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final balance = _toInt(tier['balance']);
        final color = definition['color'] as Color;
        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTierBottomSheet(tierKey),
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                label: '${definition['label']}'.tr(),
                value: '$balance',
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: kWhite.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.85)),
                  ),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(definition['icon'] as IconData, color: color, size: 16),
                        const SizedBox(width: 3),
                        const Icon(Icons.unfold_more, color: Colors.white70, size: 12),
                      ]),
                      const SizedBox(height: 2),
                      Text('$balance', style: kPointsNumberStyle(size: 17, color: color)),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Flexible(
                          child: Text(
                            definition['shortLabel'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kBodyTextStyle(size: 11, weight: FontWeight.w600, color: kWhite),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text('🔍', style: TextStyle(fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getRewardCategoryKey(Map<String, dynamic> item) {
    final category = (item['category'] ?? item['storeCategory'] ?? item['activity'] ?? '').toString().toLowerCase();
    final title = (item['reward_name'] ?? item['title'] ?? '').toString().toLowerCase();
    final store = (item['storeName'] ?? item['merchant_name'] ?? '').toString().toLowerCase();
    final desc = (item['description'] ?? '').toString().toLowerCase();
    final text = '$category $title $store $desc';

    if (text.contains('مطعم') || text.contains('وجبة') || text.contains('أكل') || text.contains('طعام') ||
        text.contains('أرز') || text.contains('ارز') || text.contains('كافيه') || text.contains('قهوة') ||
        text.contains('دجاج') || text.contains('بيتزا') || text.contains('burger') || text.contains('food') ||
        text.contains('coffee') || text.contains('restaurant')) {
      return 'مطاعم';
    }
    if (text.contains('مواد غذائية') || text.contains('سوبرماركت') || text.contains('بقالة') ||
        text.contains('تموين') || text.contains('غذائية') || text.contains('market') || text.contains('grocery')) {
      return 'مواد غذائية';
    }
    if (text.contains('غسيل') || text.contains('سيارة') || text.contains('سيارات') || text.contains('مغسلة') ||
        text.contains('مركبة') || text.contains('car') || text.contains('wash')) {
      return 'غسيل سيارات';
    }
    if (text.contains('صيدلية') || text.contains('صيدليات') || text.contains('دواء') || text.contains('علاج') ||
        text.contains('صحية') || text.contains('pharmacy') || text.contains('health')) {
      return 'صيدليات';
    }
    if (text.contains('ملابس') || text.contains('ازياء') || text.contains('أزياء') || text.contains('ثياب') ||
        text.contains('موضة') || text.contains('clothes') || text.contains('fashion')) {
      return 'ملابس';
    }
    return 'أخرى';
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'مطاعم':
        return Icons.restaurant_outlined;
      case 'مواد غذائية':
        return Icons.shopping_bag_outlined;
      case 'غسيل سيارات':
        return Icons.directions_car_outlined;
      case 'صيدليات':
        return Icons.medical_services_outlined;
      case 'ملابس':
        return Icons.checkroom_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  Widget _buildDynamicCashBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outlined, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 حاسبة الخصم المالي المباشر', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                    SizedBox(height: 2),
                    Text('تحويل النقاط إلى خصم مالي مباشر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('ادخل المبلغ الذي تريد خصمه من فاتورتك (مثلاً: 10 دينار = 100 نقطة)', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: _openDynamicVoucherSheet,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('💵 فتح حاسبة الخصم المالي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A5C43),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
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

  Map<String, dynamic>? _nextTargetReward(int availablePoints) {
    Map<String, dynamic>? next;
    int? minCost;
    final candidateRewards = <Map<String, dynamic>>[..._rewards, ..._giftLocked];
    for (final item in candidateRewards) {
      final cost = _toInt(item['value'] ?? item['pointsCost']);
      if (cost > availablePoints && (minCost == null || cost < minCost)) {
        minCost = cost;
        next = item;
      }
    }
    return next;
  }

  int? _nextMilestoneValue(int availablePoints) {
    int? next;
    for (final reward in _rewards) {
      final value = _toInt(reward['value']);
      if (value > availablePoints && (next == null || value < next)) next = value;
    }
    return next;
  }

  String? _resolveClaimRewardName(Map<String, dynamic> claim) {
    final rewardId = (claim['rewardId'] ?? '').toString();
    final sourceId = (claim['sourceId'] ?? '').toString();
    final pointsCost = _toInt(claim['pointsCost']);
    if (rewardId.isNotEmpty) {
      for (final reward in _rewards) {
        if ((reward['id'] ?? '').toString() == rewardId) {
          return (reward['reward_name'] ?? '').toString();
        }
      }
    }
    if (sourceId.isEmpty) return null;
    for (final reward in _rewards) {
      if ((reward['id'] ?? '').toString() == sourceId) {
        return (reward['reward_name'] ?? '').toString();
      }
    }
    for (final reward in _rewards) {
      final rewardSourceId = (reward['sourceId'] ?? '').toString();
      if (rewardSourceId.isNotEmpty && rewardSourceId == sourceId && _toInt(reward['value']) == pointsCost) {
        return (reward['reward_name'] ?? '').toString();
      }
    }
    return null;
  }

  String _claimRewardLabel(Map<String, dynamic> claim) {
    final name = _resolveClaimRewardName(claim);
    if (name != null && name.isNotEmpty) return name;
    return 'coupon_value_label'.tr(namedArgs: {'value': '${_toInt(claim['pointsCost'])}'});
  }

  List<_TxEntry> _buildTransactions() {
    final items = <_TxEntry>[];
    for (final entry in _ledger) {
      final points = _toInt(entry['points']);
      if (points == 0) continue;
      final type = (entry['type'] ?? '').toString();
      final date = DateTime.tryParse((entry['createdAt'] ?? '').toString()) ?? DateTime.now();
      final label = type == 'pointsEarned'
          ? 'tx_receipt_scan_approved'.tr()
          : ((type == 'pointsRedeemed' || type == 'rewardClaimCreated')
              ? 'tx_reward_redeemed_generic'.tr()
              : _formatLedgerType(type));
      items.add(_TxEntry(date: date, label: label, points: points));
    }
    for (final claim in _claims) {
      if (!shouldAddClaimTransaction(claim, _ledger)) continue;
      final pointsCost = _toInt(claim['pointsCost']);
      if (pointsCost <= 0) continue;
      final date = DateTime.tryParse((claim['createdAt'] ?? '').toString()) ?? DateTime.now();
      final rewardName = _resolveClaimRewardName(claim);
      final label = rewardName != null && rewardName.isNotEmpty
          ? 'tx_reward_redeemed'.tr(namedArgs: {'reward': rewardName})
          : 'tx_reward_redeemed_generic'.tr();
      items.add(_TxEntry(date: date, label: label, points: -pointsCost));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items.take(20).toList();
  }

  String _formatTxDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}
