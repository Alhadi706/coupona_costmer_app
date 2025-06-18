import 'package:flutter/material.dart';

class MenuIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final double iconSize;
  const MenuIcon({Key? key, required this.onTap, this.iconSize = 40}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu, color: Colors.deepPurple, size: iconSize),
            SizedBox(height: 4),
            Text('القائمة', style: TextStyle(color: Colors.deepPurple, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}