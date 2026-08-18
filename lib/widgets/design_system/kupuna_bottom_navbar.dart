import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

enum KupunaNavItem {
  home,
  wallet,
  communities,
  reports,
  account,
}

class KupunaBottomNavbar extends StatelessWidget {
  final KupunaNavItem activeItem;
  final ValueChanged<KupunaNavItem> onTap;

  const KupunaBottomNavbar({
    super.key,
    required this.activeItem,
    required this.onTap,
  });

  static const List<_NavMeta> _items = <_NavMeta>[
    _NavMeta(KupunaNavItem.home, Icons.home_outlined, 'الرئيسية'),
    _NavMeta(KupunaNavItem.wallet, Icons.account_balance_wallet_outlined, 'المحفظة'),
    _NavMeta(KupunaNavItem.communities, Icons.forum_outlined, 'المجتمعات'),
    _NavMeta(KupunaNavItem.reports, Icons.flag_outlined, 'بلاغات'),
    _NavMeta(KupunaNavItem.account, Icons.person_outline, 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(top: BorderSide(color: kLine, width: kBorderWidth)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: _items.map((item) {
            final bool isActive = activeItem == item.item;
            final Color color = isActive ? kTeal : kInk.withValues(alpha: kBottomNavInactiveAlpha);
            final FontWeight weight = isActive ? FontWeight.w700 : FontWeight.w500;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(item.item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: kGapTight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: color),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: kBodyTextStyle(
                          size: kBottomNavFontSize,
                          weight: weight,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _NavMeta {
  final KupunaNavItem item;
  final IconData icon;
  final String label;

  const _NavMeta(this.item, this.icon, this.label);
}
