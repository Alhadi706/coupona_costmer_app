import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/design_tokens.dart';

class MenuIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final double iconSize;
  const MenuIcon({super.key, required this.onTap, this.iconSize = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: kSand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu, color: kTealDark, size: iconSize),
            SizedBox(height: 4),
            Text('menu_tooltip'.tr(), style: TextStyle(color: kTealDark, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}