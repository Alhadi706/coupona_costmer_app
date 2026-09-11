import 'package:flutter/material.dart';

import 'category_offers_screen.dart';

class CategoryProductsScreen extends StatelessWidget {
  final String categoryId;

  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return CategoryOffersScreen(categoryName: categoryId);
  }
}