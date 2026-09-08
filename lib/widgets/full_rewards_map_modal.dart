import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'map_background_decorations.dart';
import 'map_node_widget.dart';
import 'map_path_painter.dart';

const int kJackpotThreshold = 500;

/// Opens the full-screen gamified rewards map as a modal route.
Future<void> showFullRewardsMapModal(
  BuildContext context, {
  required int balance,
  required List<Map<String, dynamic>> rewards,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => FullRewardsMapScreen(balance: balance, rewards: rewards),
    ),
  );
}

/// Full-screen interactive rewards journey map: a continuous winding path
/// from bottom to top through every milestone on a clean branded light background.
class FullRewardsMapScreen extends StatelessWidget {
  final int balance;
  final List<Map<String, dynamic>> rewards;

  const FullRewardsMapScreen({
    super.key,
    required this.balance,
    required this.rewards,
  });

  static const double _nodeSize = 64;
  static const double _rowHeight = 140;

  List<RewardMilestone> _buildMilestones() {
    final sorted = [...rewards]
      ..sort((a, b) => toRewardInt(a['value']).compareTo(toRewardInt(b['value'])));

    final milestones = <RewardMilestone>[];

    // Always include a welcome/starting milestone if first reward > 0
    if (sorted.isEmpty || toRewardInt(sorted.first['value']) > 0) {
      milestones.add(
        RewardMilestone(
          title: 'roadmap_welcome_bonus_title'.tr(),
          subtitle: 'roadmap_claimed_subtitle'.tr(),
          pointsRequired: 0,
          status: RewardNodeStatus.achieved,
        ),
      );
    }

    var currentSet = false;
    for (final reward in sorted) {
      final target = toRewardInt(reward['value']);
      final merchant = rewardMerchantName(reward);
      final name = (reward['reward_name'] ?? 'home_mission_next_reward_fallback'.tr()).toString();

      RewardNodeStatus status;
      String subtitle;
      double progress = 0;

      if (target <= balance) {
        status = target >= kJackpotThreshold ? RewardNodeStatus.jackpot : RewardNodeStatus.achieved;
        subtitle = merchant.isNotEmpty ? merchant : 'roadmap_claimed_subtitle'.tr();
      } else if (!currentSet) {
        status = RewardNodeStatus.current;
        currentSet = true;
        final remaining = target - balance;
        subtitle = 'roadmap_remaining_subtitle'.tr(namedArgs: {'remaining': '$remaining'});
        progress = target <= 0 ? 1 : (balance / target).clamp(0.0, 1.0);
      } else {
        status = target >= kJackpotThreshold ? RewardNodeStatus.jackpot : RewardNodeStatus.locked;
        subtitle = 'roadmap_locked_subtitle'.tr(namedArgs: {'value': '$target'});
      }

      milestones.add(RewardMilestone(
        title: name,
        subtitle: subtitle,
        pointsRequired: target,
        status: status,
        progress: progress,
        reward: reward,
      ));
    }

    // Ensure there is always a grand prize milestone at top
    if (milestones.every((m) => m.status != RewardNodeStatus.jackpot)) {
      milestones.add(
        RewardMilestone(
          title: 'home_reward_map_grand_prize'.tr(),
          subtitle: 'roadmap_locked_subtitle'.tr(namedArgs: {'value': '$kJackpotThreshold'}),
          pointsRequired: kJackpotThreshold,
          status: RewardNodeStatus.jackpot,
        ),
      );
    }

    return milestones;
  }

  List<Offset> _calculateCenters(int count, double totalWidth, double totalHeight) {
    final centerX = totalWidth / 2;
    final horizontalOffset = (totalWidth * 0.22).clamp(60.0, 110.0);

    return List<Offset>.generate(count, (i) {
      // Progress from bottom (i = 0) up to top (i = count - 1)
      final x = i.isEven ? centerX - horizontalOffset : centerX + horizontalOffset;
      final y = totalHeight - 110.0 - (i * _rowHeight);
      return Offset(x, y);
    });
  }

  void _showMilestoneDetails(BuildContext context, RewardMilestone milestone) {
    final reward = milestone.reward;
    final merchant = reward != null ? rewardMerchantName(reward) : '';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: milestone.status == RewardNodeStatus.jackpot
                            ? kGold.withValues(alpha: 0.18)
                            : kTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        milestone.status == RewardNodeStatus.jackpot
                            ? Icons.emoji_events_rounded
                            : Icons.card_giftcard_rounded,
                        color: milestone.status == RewardNodeStatus.jackpot ? kGold : kTeal,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            milestone.title,
                            style: kDisplayTextStyle(size: 18, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            milestone.subtitle,
                            style: kBodyTextStyle(
                              size: 13,
                              weight: FontWeight.w700,
                              color: kTealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: kLine),
                const SizedBox(height: 16),

                _infoRow(
                  Icons.stars_rounded,
                  'home_reward_map_points_required'.tr(
                    namedArgs: {'points': '${milestone.pointsRequired}'},
                  ),
                  kGold,
                ),

                if (merchant.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.storefront_rounded,
                    'home_reward_map_participating_merchant'.tr(
                      namedArgs: {'merchant': merchant},
                    ),
                    kTeal,
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: kWhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusPill),
                      ),
                    ),
                    child: Text(
                      'common_close'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: kBodyTextStyle(size: 13, color: kInk),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final milestones = _buildMilestones();
    final count = milestones.length;
    final totalHeight = count <= 1 ? 400.0 : 220.0 + (count - 1) * _rowHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5), // Branded App Theme Light Background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: kInk),
        title: Text(
          'home_reward_map_title'.tr(),
          style: kDisplayTextStyle(size: 19, weight: FontWeight.w800, color: kInk),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final centers = _calculateCenters(count, totalWidth, totalHeight);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 60),
            child: SizedBox(
              height: totalHeight,
              width: totalWidth,
              child: Stack(
                children: [
                  // 1. Subtle 3D Floating Background Illustrations
                  MapBackgroundDecorations(totalHeight: totalHeight),

                  // 2. Winding Bézier Path line from bottom to top
                  CustomPaint(
                    size: Size(totalWidth, totalHeight),
                    painter: MapPathPainter(centers: centers),
                  ),

                  // 3. Interactive Milestone Nodes
                  for (int i = 0; i < count; i++)
                    Positioned(
                      left: centers[i].dx - (_nodeSize * (milestones[i].status == RewardNodeStatus.jackpot ? 1.25 : 1.0)) / 2,
                      top: centers[i].dy - (_nodeSize * (milestones[i].status == RewardNodeStatus.jackpot ? 1.25 : 1.0)) / 2,
                      child: MapNodeWidget(
                        milestone: milestones[i],
                        size: _nodeSize,
                        onTap: () => _showMilestoneDetails(context, milestones[i]),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

