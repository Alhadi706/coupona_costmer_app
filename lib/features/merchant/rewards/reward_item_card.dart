import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../services/company_server_service.dart';
import '../../../theme/design_tokens.dart';

class RewardItemCard extends StatelessWidget {
  final Map<String, dynamic> reward;
  final VoidCallback onToggleActive;
  final VoidCallback onTap;

  const RewardItemCard({
    super.key,
    required this.reward,
    required this.onToggleActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = reward['isActive'] == true;
    final limit = reward['quantityLimit'];
    final redeemed = reward['quantityRedeemed'] ?? 0;
    final hasLimit = limit != null && limit > 0;
    final progress = hasLimit ? redeemed / limit : 0.0;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard_outlined, color: kTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reward['reward_name'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${reward['value'] ?? 0} نقطة',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: active,
                    onChanged: (_) => onToggleActive(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(active ? 'النشطة' : 'الموقوفة'),
                    backgroundColor: active ? kTeal.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: active ? kTeal : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (hasLimit) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المخزون',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          'تم استبدال $redeemed من $limit',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 0.8 ? Colors.red : kTeal,
                      ),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}