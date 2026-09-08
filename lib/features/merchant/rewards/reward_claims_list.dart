import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class RewardClaimsList extends StatelessWidget {
  final List<Map<String, dynamic>> claims;

  const RewardClaimsList({super.key, required this.claims});

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return Card(
        child: ListTile(
          title: Text('merchant_reward_claims_empty'.tr()),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'merchant_reward_claims_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        const SizedBox(height: 8),
        ...claims.take(10).map((claim) {
          final claimId = (claim['id'] ?? '').toString();
          final shortId = claimId.length > 8 ? claimId.substring(0, 8) : claimId;
          final status = claim['status'] ?? '-';
          final pointsCost = claim['pointsCost'] ?? 0;
          final customerName = claim['customerName'] ?? 'زبون';
          final createdAt = claim['createdAt'] != null
              ? DateTime.parse(claim['createdAt'].toString()).toLocal()
              : null;

          return Card(
            key: Key('merchant-reward-claim-$claimId'),
            child: ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text((claim['rewardName'] ?? 'reward_generic'.tr()).toString()),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$customerName • $pointsCost نقطة'),
                  if (createdAt != null)
                    Text(
                      '${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(status),
                backgroundColor: _getStatusColor(status).withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'pending' => Colors.orange,
      'completed' => kTeal,
      'cancelled' => Colors.red,
      'expired' => Colors.grey,
      _ => Colors.grey,
    };
  }
}