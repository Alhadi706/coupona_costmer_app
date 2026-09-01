import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Visual Coalition Classification Badges
/// Implements Pro-Rata Coalition Engine v3 merchant type indicators
enum CoalitionBadgeType {
  publicNetwork, // 🟢 Platform-wide vouchers
  privateCoalition, // 🔵 Coalition badges, aggregated points
  standalone, // ⚪ In-store only
}

class CoalitionBadge extends StatelessWidget {
  final CoalitionBadgeType type;
  final bool showDescription;

  const CoalitionBadge({
    super.key,
    required this.type,
    this.showDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    late String labelKey;
    late String descKey;
    late Color color;
    late IconData icon;

    switch (type) {
      case CoalitionBadgeType.publicNetwork:
        labelKey = 'coalition_badge_public_network';
        descKey = 'coalition_badge_public_desc';
        color = Colors.green;
        icon = Icons.public;
        break;
      case CoalitionBadgeType.privateCoalition:
        labelKey = 'coalition_badge_private_coalition';
        descKey = 'coalition_badge_private_desc';
        color = Colors.blue;
        icon = Icons.group;
        break;
      case CoalitionBadgeType.standalone:
        labelKey = 'coalition_badge_standalone';
        descKey = 'coalition_badge_standalone_desc';
        color = Colors.grey;
        icon = Icons.store;
        break;
    }

    if (!showDescription) {
      return Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(
          labelKey.tr(),
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
        backgroundColor: color.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelKey.tr(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  descKey.tr(),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to determine badge type from merchant coalition status
CoalitionBadgeType determineBadgeType({
  bool isInPublicNetwork = false,
  bool isInPrivateCoalition = false,
}) {
  if (isInPublicNetwork) return CoalitionBadgeType.publicNetwork;
  if (isInPrivateCoalition) return CoalitionBadgeType.privateCoalition;
  return CoalitionBadgeType.standalone;
}
