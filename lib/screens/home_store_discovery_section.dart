import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../widgets/stream_load_error.dart';
import 'home_content_screen_discover.dart';
import 'home_store_category_filter_chips.dart';

Widget buildStoreDiscoverySection(dynamic state) {
  return HomeContentSectionCard(
    title: 'home_discover_section_title'.tr(),
    subtitle: 'home_list_live_subtitle'.tr(),
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: state.storesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StreamLoadError(),
                TextButton(
                  onPressed: () => state.reloadStores(),
                  child: Text('retry'.tr()),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final sourceRows = List<Map<String, dynamic>>.from(snapshot.data!);
        final categories =
            sourceRows
                .map((store) => (store['category'] ?? '').toString().trim())
                .where((category) => category.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final filteredRows = _filterStoresByCategory(
          sourceRows,
          state.selectedDiscoverCategory as String,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeStoreCategoryFilterChips(
              categories: categories,
              selectedCategory: state.selectedDiscoverCategory as String,
              onCategoryChanged: state.handleCategoryChanged,
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.view_list),
                  label: Text('home_discover_list'.tr()),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.map_outlined),
                  label: Text('home_discover_map'.tr()),
                ),
              ],
              selected: <bool>{state.discoverMapMode as bool},
              onSelectionChanged: (Set<bool> value) =>
                  state.handleMapModeChanged(value.first),
            ),
            const SizedBox(height: 10),
            if (filteredRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('home_discover_empty'.tr()),
              )
            else if (state.discoverMapMode)
              buildDiscoverMap(state, filteredRows)
            else
              buildDiscoverList(state, filteredRows),
          ],
        );
      },
    ),
  );
}

List<Map<String, dynamic>> _filterStoresByCategory(
  List<Map<String, dynamic>> sourceRows,
  String selectedCategory,
) {
  final seenNames = <String>{};
  final filteredRows = <Map<String, dynamic>>[];
  for (final store in sourceRows) {
    final name = (store['name'] ?? '').toString().trim();
    final category = (store['category'] ?? '').toString();
    if (selectedCategory.isNotEmpty && category != selectedCategory) {
      continue;
    }
    final normalized = name.toLowerCase();
    if (normalized.isNotEmpty && seenNames.contains(normalized)) {
      continue;
    }
    seenNames.add(normalized);
    filteredRows.add(store);
  }
  return filteredRows;
}
