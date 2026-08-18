import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class KupunaTopTabs extends StatelessWidget {
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const KupunaTopTabs({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kGapTight,
      runSpacing: kGapTight,
      children: List<Widget>.generate(tabs.length, (index) {
        final bool isActive = index == activeIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(kRadiusPill),
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: kTopTabPaddingHorizontal,
              vertical: kTopTabPaddingVertical,
            ),
            decoration: BoxDecoration(
              color: isActive ? kInk : kWhite,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(
                color: isActive ? kInk : kLine,
                width: kBorderWidth,
              ),
            ),
            child: Text(
              tabs[index],
              style: kBodyTextStyle(
                size: 12,
                weight: FontWeight.w600,
                color: isActive ? kWhite : kInk,
              ),
            ),
          ),
        );
      }),
    );
  }
}
