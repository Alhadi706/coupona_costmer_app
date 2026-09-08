import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HomeStoreCategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const HomeStoreCategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('home_discover_all_categories'.tr()),
          selected: selectedCategory.isEmpty,
          onSelected: (_) => onCategoryChanged(''),
        ),
        ...categories.map(
          (category) => ChoiceChip(
            label: Text(category),
            selected: selectedCategory == category,
            onSelected: (_) => onCategoryChanged(category),
          ),
        ),
      ],
    );
  }
}
