import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ReportIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final double iconSize;
  const ReportIcon({super.key, required this.onTap, this.iconSize = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_problem, color: Colors.orange, size: iconSize),
            SizedBox(height: 4),
            Text('report_icon'.tr(), style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}