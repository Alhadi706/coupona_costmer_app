import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CategoryBar extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final double height;
  final double iconSize;
  final double fontSize;
  final void Function(Map<String, dynamic> category)? onCategoryTap;

  const CategoryBar({
    super.key,
    required this.categories,
    this.height = 80,
    this.iconSize = 32,
    this.fontSize = 13,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final avatarRadius = ((height - 30) / 3).clamp(11.0, 16.0).toDouble();
          return GestureDetector(
            onTap: () {
              if (onCategoryTap != null) onCategoryTap!(cat);
            },
            child: SizedBox(
              height: height - 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    radius: avatarRadius,
                    child: Icon(cat['icon'], size: iconSize.clamp(16.0, 24.0), color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: iconSize * 2,
                    child: Text(
                      cat['label'].toString().tr(),
                      style: TextStyle(fontSize: fontSize.clamp(10.0, 12.0), color: Colors.deepPurple),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
