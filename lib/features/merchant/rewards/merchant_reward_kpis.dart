import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../services/company_server_service.dart';
import '../../../theme/design_tokens.dart';

class MerchantRewardKPIs extends StatefulWidget {
  final String sourceType;

  const MerchantRewardKPIs({super.key, required this.sourceType});

  @override
  State<MerchantRewardKPIs> createState() => _MerchantRewardKPIsState();
}

class _MerchantRewardKPIsState extends State<MerchantRewardKPIs> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _metrics = const {};

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
      final metrics = await CompanyServerService.getMerchantRewardKPIs(widget.sourceType);
      if (mounted) setState(() => _metrics = metrics);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text('تعذر تحميل مؤشرات الجوائز'),
                    trailing: IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  )
                : Row(
                    children: [
                      _buildKPICard(
                        icon: Icons.redeem_outlined,
                        title: 'إجمالي الاستبدالات',
                        value: '${_metrics['totalRedemptions'] ?? 0}',
                        subtitle: 'هذا الشهر',
                        color: kTeal,
                      ),
                      const SizedBox(width: 12),
                      _buildKPICard(
                        icon: Icons.emoji_events_outlined,
                        title: 'الجائزة الأكثر طلباً',
                        value: '${_metrics['topRewardName'] ?? 'لا توجد'}',
                        subtitle: '${_metrics['topRewardClaims'] ?? 0} طلب',
                        color: kGold,
                      ),
                      const SizedBox(width: 12),
                      _buildKPICard(
                        icon: Icons.attach_money_outlined,
                        title: 'القيمة الممنوحة',
                        value: '${_metrics['totalValueGiven'] ?? 0} د.ل',
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
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