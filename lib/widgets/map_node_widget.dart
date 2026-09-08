import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Lifecycle state of a single reward milestone on the rewards path/map.
enum RewardNodeStatus { achieved, current, locked, jackpot }

/// One milestone (gift) rendered along the winding rewards path.
class RewardMilestone {
  final String title;
  final String subtitle;
  final int pointsRequired;
  final RewardNodeStatus status;
  final double progress;
  final Map<String, dynamic>? reward;

  const RewardMilestone({
    required this.title,
    required this.subtitle,
    required this.pointsRequired,
    required this.status,
    this.progress = 0,
    this.reward,
  });
}

/// Reusable gamified milestone node component for rewards path & full map.
class MapNodeWidget extends StatelessWidget {
  final RewardMilestone milestone;
  final double size;
  final VoidCallback? onTap;

  const MapNodeWidget({
    super.key,
    required this.milestone,
    this.size = 60,
    this.onTap,
  });

  bool get _isAchieved => milestone.status == RewardNodeStatus.achieved;
  bool get _isCurrent => milestone.status == RewardNodeStatus.current;
  bool get _isJackpot => milestone.status == RewardNodeStatus.jackpot;
  bool get _isLocked => milestone.status == RewardNodeStatus.locked;

  Color get _accentColor {
    if (_isJackpot) return kGold;
    if (_isCurrent) return kGold;
    if (_isAchieved) return kTeal;
    return kInk.withValues(alpha: 0.35);
  }

  IconData get _icon {
    if (_isJackpot) return Icons.emoji_events_rounded;
    if (_isAchieved) return Icons.check_circle_rounded;
    if (_isCurrent) return Icons.person_pin_circle_rounded;
    return Icons.lock_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSize = _isJackpot ? size * 1.25 : size;
    final accent = _accentColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 3D-styled Node Circle Badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: effectiveSize,
            height: effectiveSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isJackpot
                  ? const LinearGradient(
                      colors: [Color(0xFFFFF3A1), kGold, Color(0xFFB88219)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : _isAchieved
                      ? const LinearGradient(
                          colors: [kMint, kTeal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
              color: _isJackpot || _isAchieved
                  ? null
                  : _isCurrent
                      ? kWhite
                      : kWhite,
              border: Border.all(
                color: _isCurrent ? kGold : accent,
                width: _isCurrent ? 3.5 : 2.5,
              ),
              boxShadow: [
                if (_isCurrent) ...[
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: kTeal.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] else if (_isJackpot) ...[
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ] else ...[
                  BoxShadow(
                    color: kInk.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ],
            ),
            child: Icon(
              _icon,
              color: _isJackpot || _isAchieved ? kWhite : accent,
              size: effectiveSize * 0.48,
            ),
          ),
          const SizedBox(height: 6),

          // High-contrast Pill Badge Label
          Container(
            constraints: BoxConstraints(maxWidth: effectiveSize + 36),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(
                color: _isCurrent
                    ? kGold
                    : _isJackpot
                        ? kGold.withValues(alpha: 0.8)
                        : kLine,
                width: _isCurrent ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: kInk.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _isLocked
                  ? '${milestone.pointsRequired} pts'
                  : milestone.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kBodyTextStyle(
                size: 10.5,
                weight: _isCurrent || _isJackpot
                    ? FontWeight.w800
                    : FontWeight.w700,
                color: _isCurrent
                    ? kTealDark
                    : _isJackpot
                        ? Color(0xFF8C5D00)
                        : kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int toRewardInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

Map<String, dynamic> asRewardMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> asRewardMapList(dynamic value) => value is List
    ? value.whereType<Map>().map(asRewardMap).toList(growable: false)
    : const <Map<String, dynamic>>[];

String rewardMerchantName(Map<String, dynamic> reward) =>
    (reward['storeName'] ?? reward['merchant_name'] ?? reward['merchantName'] ?? '')
        .toString();
