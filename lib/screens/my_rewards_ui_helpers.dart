part of 'package:coupona_app/screens/my_rewards_screen.dart';

class MyRewardsCategoryFilterChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const MyRewardsCategoryFilterChips({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const categories = <String>['الكل', 'مطاعم', 'مواد غذائية', 'غسيل سيارات', 'صيدليات', 'ملابس'];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;
          return FilterChip(
            selected: isSelected,
            label: Text(category),
            selectedColor: const Color(0xFF0A5C43),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.white,
            elevation: isSelected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isSelected ? const Color(0xFF0A5C43) : const Color(0xFFE2E8F0)),
            ),
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

extension _MyRewardsUiHelpers on _MyRewardsScreenState {
  Widget _buildTierDetails() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline, color: kTeal),
        title: Text('wallet_tier_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text('wallet_bronze_scope'.tr()),
          const SizedBox(height: 6),
          Text('wallet_silver_scope'.tr()),
          const SizedBox(height: 6),
          Text('wallet_gold_scope'.tr()),
        ],
      ),
    );
  }

  Widget _buildPendingPointsCard() {
    final pending = List<dynamic>.from(_pending['pending'] ?? const []);
    if (pending.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('wallet_pending_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('wallet_pending_description'.tr(namedArgs: {'points': '${_pending['total_points'] ?? 0}'})),
            const SizedBox(height: 8),
            ...pending.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hourglass_top, color: Colors.orange),
              title: Text('${item['merchant_name'] ?? 'merchant'}'),
              subtitle: Text('wallet_pending_item'.tr(namedArgs: {
                'points': '${item['points_remaining'] ?? 0}',
                'tier': '${item['tier'] ?? ''}',
              })),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateWidget({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard_outlined, size: 28, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0A5C43),
              side: const BorderSide(color: Color(0xFF0A5C43)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
