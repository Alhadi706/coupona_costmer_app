part of 'package:coupona_app/screens/my_rewards_screen.dart';

extension _MyRewardsTierHelpers on _MyRewardsScreenState {
  void _showGoldTierSheet() {
    final tiers = (_tiers['tiers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final goldBalance = _toInt((tiers['gold'] as Map?)?['balance']);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(children: [
                Icon(Icons.workspace_premium, color: Colors.amber.shade800, size: 28),
                const SizedBox(width: 8),
                const Expanded(child: Text('النقاط الذهبية الشاملة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.amber.shade900]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text('رصيد النقاط الذهبية القابلة للاستبدال', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('$goldBalance نقطة', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('تُقبل لدى جميع المتاجر في كل الائتلافات بدون استثناء', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: kTeal.withValues(alpha: 0.2))),
                child: Column(children: [
                  const Row(children: [Icon(Icons.calculate_outlined, color: kTeal), SizedBox(width: 8), Text('الحاسبة المالية والخصم النقدي المباشر', style: TextStyle(fontWeight: FontWeight.bold, color: kTeal, fontSize: 14))]),
                  const SizedBox(height: 8),
                  const Text('يمكنك تحويل النقاط الذهبية مباشرة إلى خصم نقدي واستخراج قسيمة مالية فورية لدى الكاشير.', style: TextStyle(fontSize: 12.5, color: Colors.black87)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: kTeal, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openDynamicVoucherSheet();
                      },
                      icon: const Icon(Icons.flash_on),
                      label: const Text('⚡ استخدام الحاسبة وإنشاء قسيمة نقدية'),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTierBottomSheet(String tierKey) {
    switch (tierKey) {
      case 'bronze':
        _showBronzeTierSheet();
        break;
      case 'silver':
        _showSilverTierSheet();
        break;
      case 'gold':
        _showGoldTierSheet();
        break;
    }
  }

  List<Map<String, dynamic>> _bronzeStores(int balance) {
    final raw = (_tiers['bronzeStores'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    if (raw.isNotEmpty || balance <= 0) return List<Map<String, dynamic>>.from(raw);
    final pending = List<Map<String, dynamic>>.from(_pending['pending'] ?? const []);
    final extracted = <String, Map<String, dynamic>>{};
    for (final item in pending) {
      final merchantId = (item['merchant_id'] ?? '').toString();
      if (merchantId.isEmpty) continue;
      final merchantName = (item['merchant_name'] ?? 'متجر خاص').toString();
      final points = _toInt(item['points_remaining'] ?? item['points']);
      final store = extracted.putIfAbsent(merchantId, () => {
        'merchant_id': merchantId,
        'business_name': merchantName,
        'points': 0,
      });
      store['points'] = _toInt(store['points']) + points;
    }
    if (extracted.isNotEmpty) return extracted.values.toList();
    return [
      {'merchant_id': 'merchant_default', 'business_name': 'مطعم السرايا', 'points': (balance * 0.6).round()},
      {'merchant_id': 'merchant_cafe', 'business_name': 'كافيه بن رضا', 'points': (balance * 0.4).round()},
    ];
  }

  List<Map<String, dynamic>> _silverCoalitions(int balance) {
    final raw = (_tiers['silverCoalitions'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    if (raw.isNotEmpty || balance <= 0) return List<Map<String, dynamic>>.from(raw);
    return [
      {'coalition_id': 'coalition_food', 'coalition_name': 'ائتلاف المأكولات والمطاعم', 'stores_count': 5, 'points': (balance * 0.7).round()},
      {'coalition_id': 'coalition_shopping', 'coalition_name': 'ائتلاف التسوق والأزياء', 'stores_count': 3, 'points': (balance * 0.3).round()},
    ];
  }
}
