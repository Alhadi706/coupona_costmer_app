import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CategoryBar extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final double height;
  final double iconSize;
  final double fontSize;
  final void Function(Map<String, dynamic> category)? onCategoryTap;

  const CategoryBar({
    Key? key,
    required this.categories,
    this.height = 80,
    this.iconSize = 32,
    this.fontSize = 13,
    this.onCategoryTap,
  }) : super(key: key);

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
          return GestureDetector(
            onTap: () {
              if (onCategoryTap != null) onCategoryTap!(cat);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade50,
                  radius: iconSize / 1.5,
                  child: Icon(cat['icon'], size: iconSize, color: Colors.deepPurple),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: iconSize * 2,
                  child: Text(
                    (cat is String
                        ? cat.toString().tr()
                        : (cat['label'] is String ? cat['label'].toString().tr() : cat['label'].toString())),
                    style: TextStyle(fontSize: fontSize, color: Colors.deepPurple),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
