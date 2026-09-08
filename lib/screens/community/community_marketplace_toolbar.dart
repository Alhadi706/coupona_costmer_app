import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'marketplace_categories.dart';

/// Scope segments, category filter and "add offer" action for the marketplace tab.
class CommunityMarketplaceToolbar extends StatelessWidget {
  final bool showMyOffers;
  final String category;
  final ValueChanged<bool> onScopeChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onCreateOffer;

  const CommunityMarketplaceToolbar({
    super.key,
    required this.showMyOffers,
    required this.category,
    required this.onScopeChanged,
    required this.onCategoryChanged,
    required this.onCreateOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text('all_offers'.tr())),
                    ButtonSegment(value: true, label: Text('my_requests'.tr())),
                  ],
                  selected: {showMyOffers},
                  onSelectionChanged: (selection) => onScopeChanged(selection.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onCreateOffer,
                tooltip: 'add_offer'.tr(),
                style: IconButton.styleFrom(backgroundColor: kTeal, foregroundColor: kWhite),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'all_categories'.tr(),
                  selected: category == 'ALL',
                  onSelected: () => onCategoryChanged('ALL'),
                ),
                ...kMarketplaceCategories.map(
                  (value) => _CategoryChip(
                    label: marketplaceCategoryLabel(value),
                    selected: category == value,
                    onSelected: () => onCategoryChanged(value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: kGold.withValues(alpha: 0.25),
      ),
    );
  }
}
