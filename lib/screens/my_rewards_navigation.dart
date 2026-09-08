part of 'package:coupona_app/screens/my_rewards_screen.dart';

class RewardsSectionTabs extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onChanged;

  const RewardsSectionTabs({
    super.key,
    required this.selectedTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        ButtonSegment(
          value: 0,
          icon: const Icon(Icons.card_giftcard_outlined),
          label: const Text("المكافآت المتاحة"),
        ),
        ButtonSegment(
          value: 1,
          icon: const Icon(Icons.confirmation_number_outlined),
          label: Text('my_coupons'.tr()),
        ),
        ButtonSegment(
          value: 2,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text("سجل النشاطات"),
        ),
      ],
      selected: <int>{selectedTab},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class RewardsCategoryFilterChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const RewardsCategoryFilterChips({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'الكل',
      'مطاعم',
      'مواد غذائية',
      'غسيل سيارات',
      'صيدليات',
      'ملابس',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat;
          return FilterChip(
            selected: isSelected,
            label: Text(cat),
            selectedColor: const Color(0xFF0A5C43),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.white,
            elevation: isSelected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF0A5C43)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            onSelected: (_) => onSelected(cat),
          );
        },
      ),
    );
  }
}
