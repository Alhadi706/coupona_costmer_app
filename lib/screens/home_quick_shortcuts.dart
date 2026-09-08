import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'customer_coalitions_screen.dart';
import 'customer_gifts_screen.dart';
import 'my_rewards_screen.dart';

Widget buildQuickShortcutActions(dynamic state) {
  final actions = <_ShortcutItem>[
    _ShortcutItem(
      icon: Icons.calculate_outlined,
      label: "حاسبة الخصم",
      color: kTeal,
      onTap: () {
        Navigator.of(state.context).push(
          MaterialPageRoute(
            builder: (_) =>
                const MyRewardsScreen(openDynamicVoucherOnLoad: true),
          ),
        );
      },
    ),
    _ShortcutItem(
      icon: Icons.camera_alt_outlined,
      label: "مسح الفاتورة",
      color: const Color(0xFFE53935),
      onTap: () {
        state.widget.onScanReceipt?.call();
      },
    ),
    _ShortcutItem(
      icon: Icons.card_giftcard_outlined,
      label: "هداياي الخاصة",
      color: kGold,
      onTap: () {
        Navigator.of(
          state.context,
        ).push(MaterialPageRoute(builder: (_) => const CustomerGiftsScreen()));
      },
    ),
    _ShortcutItem(
      icon: Icons.local_offer_outlined,
      label: "عروض الزبائن",
      color: const Color(0xFF6D4C41),
      onTap: () {
        final open =
            state.widget.onOpenCustomerOffers ?? state.widget.onOpenCommunity;
        open?.call();
      },
    ),
    _ShortcutItem(
      icon: Icons.storefront_outlined,
      label: "سوق المجتمع",
      color: const Color(0xFF1E88E5),
      onTap: () {
        final open =
            state.widget.onOpenCustomerOffers ?? state.widget.onOpenCommunity;
        open?.call();
      },
    ),
    _ShortcutItem(
      icon: Icons.account_balance_wallet_outlined,
      label: 'home_bottom_wallet'.tr(),
      color: const Color(0xFF7C3AED),
      onTap: () {
        final openRewards = state.widget.onOpenRewards;
        if (openRewards != null) {
          openRewards();
          return;
        }
        Navigator.of(
          state.context,
        ).push(MaterialPageRoute(builder: (_) => const MyRewardsScreen()));
      },
    ),
    _ShortcutItem(
      icon: Icons.hub_outlined,
      label: 'home_coalition_network'.tr(),
      color: const Color(0xFF0D9488),
      onTap: () {
        if (state.widget.onOpenCoalitions != null) {
          state.widget.onOpenCoalitions!();
          return;
        }
        Navigator.of(state.context).push(
          MaterialPageRoute(builder: (_) => const CustomerCoalitionsScreen()),
        );
      },
    ),
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
      children: actions
          .map(
            (item) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Material(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kLine),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 20, color: item.color),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: kBodyTextStyle(
                            size: 13,
                            weight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
