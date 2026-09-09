import 'package:flutter/material.dart';
import 'package:coupona_app/theme/design_tokens.dart';

class MerchantRewardKPIs extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final List<Map<String, dynamic>> claims;

  const MerchantRewardKPIs({
    super.key,
    required this.rewards,
    required this.claims,
  });

  Map<String, dynamic> get _metrics {
    final knownRewardNames = rewards
        .map((reward) => (reward['reward_name'] ?? reward['rewardName'] ?? reward['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();
    final claimsByReward = <String, int>{};
    for (final claim in claims) {
      final rewardName = (claim['rewardName'] ?? claim['reward_name'] ?? 'لا توجد').toString();
      if (knownRewardNames.isEmpty || !knownRewardNames.contains(rewardName)) {
        continue;
      }
      claimsByReward[rewardName] = (claimsByReward[rewardName] ?? 0) + 1;
    }
    final topReward = claimsByReward.entries.fold<MapEntry<String, int>?>(
      null,
      (current, entry) => current == null || entry.value > current.value ? entry : current,
    );
    final rewardValues = {
      for (final reward in rewards)
        (reward['reward_name'] ?? reward['rewardName'] ?? reward['name'] ?? '').toString():
            (reward['value'] as num?)?.toDouble() ?? 0,
    };
    final totalValueGiven = claims.fold<double>(0, (total, claim) {
      final name = (claim['rewardName'] ?? claim['reward_name'] ?? '').toString();
      return total + (rewardValues[name] ?? (claim['pointsCost'] as num?)?.toDouble() ?? 0);
    });
    return <String, dynamic>{
      'totalRedemptions': claims.length,
      'topRewardName': topReward?.key ?? 'لا توجد',
      'topRewardClaims': topReward?.value ?? 0,
      'totalValueGiven': totalValueGiven.toStringAsFixed(0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildKPICard(
              icon: Icons.redeem_outlined,
              title: 'إجمالي الاستبدالات',
              value: '${metrics['totalRedemptions'] ?? 0}',
              subtitle: 'هذا الشهر',
              color: kTeal,
            ),
            const SizedBox(width: 12),
            _buildKPICard(
              icon: Icons.emoji_events_outlined,
              title: 'الجائزة الأكثر طلباً',
              value: '${metrics['topRewardName'] ?? 'لا توجد'}',
              subtitle: '${metrics['topRewardClaims'] ?? 0} طلب',
              color: kGold,
            ),
            const SizedBox(width: 12),
            _buildKPICard(
              icon: Icons.attach_money_outlined,
              title: 'القيمة الممنوحة',
              value: '${metrics['totalValueGiven'] ?? 0} د.ل',
              subtitle: 'إجمالي القيمة المرجعة',
              color: kMerchantBrandGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}