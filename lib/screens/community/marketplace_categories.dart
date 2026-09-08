import 'package:easy_localization/easy_localization.dart';

/// Marketplace offer categories accepted by the backend.
const List<String> kMarketplaceCategories = <String>[
  'FOOD',
  'REAL_ESTATE',
  'SERVICES',
  'RENTALS',
];

String marketplaceCategoryLabel(String category) {
  switch (category.toUpperCase()) {
    case 'FOOD':
      return 'category_food'.tr();
    case 'REAL_ESTATE':
      return 'category_real_estate'.tr();
    case 'SERVICES':
      return 'category_services'.tr();
    case 'RENTALS':
      return 'category_rentals'.tr();
    default:
      return category;
  }
}
