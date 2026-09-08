import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'full_rewards_map_modal.dart';
import 'map_node_widget.dart';
import 'map_path_painter.dart';

/// Home-screen preview of the gamified rewards journey: a short winding
/// path with the last achieved milestone, the current position, and the
/// next 2 upcoming gifts, plus a CTA to open the full interactive map.
class HomeRewardsPathWidget extends StatelessWidget {
  final int balance;
  final List<Map<String, dynamic>> rewards;

  const HomeRewardsPathWidget({
    super.key,
    required this.balance,
    required this.rewards,
  });

  static const double _nodeSize = 54;
  static const double _nodeSpacing = 110;
  static const double _topY = 10;
  static const double _bottomY = 54;
  static const double _containerHeight = 154;

  List<RewardMilestone> _buildMilestones() {
    final sorted = [...rewards]
      ..sort((a, b) => toRewardInt(a['value']).compareTo(toRewardInt(b['value'])));
    final unlocked = sorted.where((r) => toRewardInt(r['value']) <= balance).toList();
    final upcoming = sorted.where((r) => toRewardInt(r['value']) > balance).toList();

    final milestones = <RewardMilestone>[];

    if (unlocked.isNotEmpty) {
      final claimed = unlocked.last;
      milestones.add(RewardMilestone(
        title: (claimed['reward_name'] ?? 'home_mission_next_reward_fallback'.tr()).toString(),
        subtitle: 'roadmap_claimed_subtitle'.tr(),
        pointsRequired: toRewardInt(claimed['value']),
        status: RewardNodeStatus.achieved,
        reward: claimed,
      ));
    } else {
      milestones.add(RewardMilestone(
        title: 'roadmap_welcome_bonus_title'.tr(),
        subtitle: 'roadmap_claimed_subtitle'.tr(),
        pointsRequired: 0,
        status: RewardNodeStatus.achieved,
      ));
    }

    milestones.add(RewardMilestone(
      title: 'home_reward_path_you_label'.tr(namedArgs: {'points': '$balance'}),
      subtitle: '$balance pts',
      pointsRequired: balance,
      status: RewardNodeStatus.current,
    ));

    for (final locked in upcoming.take(2)) {
      milestones.add(RewardMilestone(
        title: (locked['reward_name'] ?? 'home_mission_next_reward_fallback'.tr()).toString(),
        subtitle: 'roadmap_locked_subtitle'.tr(namedArgs: {'value': '${toRewardInt(locked['value'])}'}),
        pointsRequired: toRewardInt(locked['value']),
        status: RewardNodeStatus.locked,
        reward: locked,
      ));
    }

    return milestones;
  }

  List<Offset> _centers(int count) => List<Offset>.generate(count, (i) {
        final x = _nodeSize / 2 + 16 + i * _nodeSpacing;
        final y = (i.isEven ? _topY : _bottomY) + _nodeSize / 2;
        return Offset(x, y);
      });

  void _openFullMap(BuildContext context) {
    showFullRewardsMapModal(context, balance: balance, rewards: rewards);
  }

  @override
  Widget build(BuildContext context) {
    final milestones = _buildMilestones();
    final centers = _centers(milestones.length);
    final totalWidth = milestones.isEmpty
        ? 0.0
        : centers.last.dx + _nodeSize / 2 + 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_outlined, color: kTeal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'roadmap_title'.tr(),
                style: kDisplayTextStyle(size: 18, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _openFullMap(context),
          child: SizedBox(
            height: _containerHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: totalWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(totalWidth, _containerHeight),
                      painter: HomePathPainter(centers: centers),
                    ),
                    for (int i = 0; i < milestones.length; i++)
                      Positioned(
                        left: centers[i].dx - _nodeSize / 2,
                        top: centers[i].dy - _nodeSize / 2,
                        child: MapNodeWidget(
                          milestone: milestones[i],
                          size: _nodeSize,
                          onTap: () => _openFullMap(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _openFullMap(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: kGold,
              side: const BorderSide(color: kGold, width: 1.4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(
              'home_reward_path_open_full_map'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// Resolves points/rewards futures from [state] and renders the
/// [HomeRewardsPathWidget]. `state` exposes `pointsFuture` and `rewardsFuture`.
Widget buildHomeRewardsPath(dynamic state) {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait<dynamic>([
      state.pointsFuture,
      state.rewardsFuture,
    ]).catchError((_) => <dynamic>[]),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()));
      }
      final results = snapshot.hasError ? const <dynamic>[] : (snapshot.data ?? const <dynamic>[]);
      final points = asRewardMap(results.isNotEmpty ? results[0] : null);
      final rewards = asRewardMapList(results.length > 1 ? results[1] : null);
      final balance = toRewardInt(points['availablePoints']);

      return HomeRewardsPathWidget(balance: balance, rewards: rewards);
    },
  );
}
