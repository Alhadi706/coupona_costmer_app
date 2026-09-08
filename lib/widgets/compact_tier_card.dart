import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

const double kSystemPointValue = 0.1;

/// Compact, sleek horizontal card that shows all three point tiers
/// (bronze/silver/gold) side-by-side with minimal padding and height so it
/// leaves plenty of room for the rewards path below it.
class CompactTierCard extends StatelessWidget {
  final int bronze;
  final int silver;
  final int gold;
  final VoidCallback? onTap;

  const CompactTierCard({
    super.key,
    required this.bronze,
    required this.silver,
    required this.gold,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
            borderRadius: BorderRadius.circular(kRadiusCardCompact),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TierSlot(
                  emoji: '🥉',
                  label: 'tier_bronze'.tr(),
                  color: const Color(0xFFCD7F32),
                  balance: bronze,
                ),
              ),
              _tierDivider(),
              Expanded(
                child: _TierSlot(
                  emoji: '🥈',
                  label: 'tier_silver'.tr(),
                  color: const Color(0xFFC0C0C0),
                  balance: silver,
                ),
              ),
              _tierDivider(),
              Expanded(
                child: _TierSlot(
                  emoji: '🥇',
                  label: 'tier_gold'.tr(),
                  color: const Color(0xFFFFD700),
                  balance: gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tierDivider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: kWhite.withValues(alpha: 0.12),
      );
}

class _TierSlot extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final int balance;

  const _TierSlot({
    required this.emoji,
    required this.label,
    required this.color,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$balance',
          style: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _tierBalance(Map<String, dynamic> tiers, String key) {
  final value = tiers[key];
  if (value is Map) return _toInt(value['balance']);
  return _toInt(value);
}

/// Resolves the tiers future from [state] and renders the [CompactTierCard].
/// `state` exposes `tiersFuture` and `widget.onOpenRewards`.
Widget buildCompactTierCard(dynamic state) {
  return FutureBuilder<Map<String, dynamic>>(
    future: (state.tiersFuture as Future<Map<String, dynamic>>?),
    builder: (context, snapshot) {
      final tiers = _asMap(_asMap(snapshot.data)['tiers']);
      return CompactTierCard(
        bronze: _tierBalance(tiers, 'bronze'),
        silver: _tierBalance(tiers, 'silver'),
        gold: _tierBalance(tiers, 'gold'),
        onTap: state.widget.onOpenRewards,
      );
    },
  );
}
