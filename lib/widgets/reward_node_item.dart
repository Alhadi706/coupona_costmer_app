import 'package:flutter/material.dart';

import 'map_node_widget.dart';

export 'map_node_widget.dart';

/// Backward-compatible alias mapping RewardNodeItem to MapNodeWidget.
class RewardNodeItem extends StatelessWidget {
  final RewardMilestone milestone;
  final double size;
  final VoidCallback? onTap;

  const RewardNodeItem({
    super.key,
    required this.milestone,
    this.size = 56,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MapNodeWidget(
      milestone: milestone,
      size: size,
      onTap: onTap,
    );
  }
}

