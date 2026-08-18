import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class CategoryShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconSize;
  final double fontSize;
  final double width;

  const CategoryShortcut({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconSize = 24,
    this.fontSize = 10,
    this.width = 60,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        width: width,
        height: width, // تصغير ارتفاع وعرض الكونتينر ليطابق حجم الأيقونة
        margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2), // تقليل الهوامش
        decoration: BoxDecoration(
          color: kSand,
          borderRadius: BorderRadius.circular(8), // تقليل نصف القطر
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32, // حجم الدائرة صغير وثابت
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, size: iconSize, color: kTealDark),
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: fontSize, color: kTealDark),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}