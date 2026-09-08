import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme/design_tokens.dart';
import '../widgets/stream_load_error.dart';
import 'store_details_screen.dart';

Widget buildDiscoverTab(dynamic state) {
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
                TextButton(onPressed: () => state.reloadStores(), child: Text('retry'.tr())),
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
        final keyword = state.searchController.text.trim().toLowerCase();
        final sourceRows = List<Map<String, dynamic>>.from(snapshot.data!);
        final categories = sourceRows
            .map((e) => (e['category'] ?? '').toString().trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final seenNames = <String>{};
        final filteredRows = <Map<String, dynamic>>[];
        for (final store in sourceRows) {
          final name = (store['name'] ?? '').toString().trim();
          final category = (store['category'] ?? '').toString();
          final matchesKeyword = keyword.isEmpty || name.toLowerCase().contains(keyword);
          final matchesCategory = state.selectedDiscoverCategory.isEmpty || category == state.selectedDiscoverCategory;
          if (matchesKeyword && matchesCategory) {
            final normalized = name.toLowerCase();
            if (normalized.isNotEmpty && seenNames.contains(normalized)) {
              continue;
            }
            seenNames.add(normalized);
            filteredRows.add(store);
          }
        }
        filteredRows.sort((a, b) {
          final distanceA = _distanceKm(state.customerLat, state.customerLng, _toDouble(a['lat']), _toDouble(a['lng']));
          final distanceB = _distanceKm(state.customerLat, state.customerLng, _toDouble(b['lat']), _toDouble(b['lng']));
          return distanceA.compareTo(distanceB);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('home_discover_all_categories'.tr()),
                  selected: state.selectedDiscoverCategory.isEmpty,
                  onSelected: (_) => state.handleCategoryChanged(''),
                ),
                ...categories.map((cat) => ChoiceChip(
                  label: Text(cat),
                  selected: state.selectedDiscoverCategory == cat,
                  onSelected: (_) => state.handleCategoryChanged(cat),
                )),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, icon: const Icon(Icons.view_list), label: Text('home_discover_list'.tr())),
                ButtonSegment<bool>(value: true, icon: const Icon(Icons.map_outlined), label: Text('home_discover_map'.tr())),
              ],
              selected: <bool>{state.discoverMapMode as bool},
              onSelectionChanged: (Set<bool> value) => state.handleMapModeChanged(value.first),
            ),
            const SizedBox(height: 10),
            if (filteredRows.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('home_discover_empty'.tr()))
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

Widget buildDiscoverMap(dynamic state, List<Map<String, dynamic>> stores) {
  final center = stores.isNotEmpty
      ? LatLng(_toDouble(stores.first['lat']), _toDouble(stores.first['lng']))
      : (state.customerLat == null || state.customerLng == null)
          ? state.tripoliDefaultCenter
          : LatLng(state.customerLat!, state.customerLng!);
  return SizedBox(
    height: 260,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 12),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.coupona_app',
            tileProvider: NetworkTileProvider(),
          ),
          MarkerLayer(
            markers: stores.map((store) => Marker(
              width: 42,
              height: 42,
              point: LatLng(_toDouble(store['lat']), _toDouble(store['lng'])),
              child: Tooltip(
                message: (store['name'] ?? '').toString(),
                child: const Icon(Icons.location_on, color: Colors.red, size: 36),
              ),
            )).toList(growable: false),
          ),
        ],
      ),
    ),
  );
}

Widget buildDiscoverList(dynamic state, List<Map<String, dynamic>> stores) {
  final sourceLat = state.customerLat;
  final sourceLng = state.customerLng;

  return FutureBuilder<Map<String, dynamic>>(
    future: (state.sourcesFuture as Future<Map<String, dynamic>>?),
    builder: (context, sourcesSnapshot) {
      final sources = sourcesSnapshot.data ?? <String, dynamic>{};
      final storeSourcesList = sources['storeSources'] is List
          ? List<Map<String, dynamic>>.from(sources['storeSources'] as List)
          : <Map<String, dynamic>>[];

      final storePointsMap = <String, int>{};
      for (final s in storeSourcesList) {
        final mId = (s['merchantId'] ?? s['storeId'] ?? s['id'] ?? '').toString();
        final pts = _toInt(s['points'] ?? s['balance']);
        if (mId.isNotEmpty) storePointsMap[mId] = pts;
      }

      return Column(
        children: stores.take(10).map((store) {
          final distance = _distanceKm(sourceLat, sourceLng, _toDouble(store['lat']), _toDouble(store['lng']));
          final coalitions = (store['coalitions'] as List?) ?? const [];
          final merchantId = (store['merchantId'] ?? store['id'] ?? '').toString();
          final userStorePoints = storePointsMap[merchantId] ?? _toInt(store['userPoints'] ?? store['myPoints']);
          final cashbackRate = (store['pointValue'] ?? store['cashbackRate'] ?? 5).toString();
          final imageUrl = (store['imageUrl'] ?? store['coverUrl'] ?? store['logoUrl'] ?? '').toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(state.context).push(MaterialPageRoute(builder: (_) => StoreDetailsScreen(store: store))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.startsWith('http') || imageUrl.startsWith('assets/')) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.startsWith('http')
                            ? Image.network(imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover)
                            : Image.asset(imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kTeal.withValues(alpha: 0.12),
                          child: const Icon(Icons.storefront, color: kTealDark, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((store['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                '📍 ${distance.toStringAsFixed(1)} كم • ${(store['category'] ?? '-').toString()}',
                                style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.65)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⚡ كاشباك $cashbackRate%',
                            style: const TextStyle(color: kTealDark, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (userStorePoints > 0)
                          _storeMetaChip(
                            Icons.workspace_premium,
                            '🥉 لديك $userStorePoints نقطة هنا (تساوي ${(userStorePoints * 0.1).toStringAsFixed(2)} د.ل)',
                            const Color(0xFFCD7F32),
                          ),
                        _storeMetaChip(Icons.loyalty_outlined, _storePointTierLabel(store['pointTier']), kGold),
                        _storeMetaChip(Icons.inventory_2_outlined, "خدمات المتجر", kIndigo),
                      ],
                    ),
                    if (coalitions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'store_coalitions_value'.tr(namedArgs: {'value': coalitions.map((item) => (item as Map)['name']?.toString() ?? '').where((name) => name.isNotEmpty).join(' • ')}),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kTealDark),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      );
    },
  );
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

Widget _storeMetaChip(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(kRadiusPill),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: kBodyTextStyle(size: 11, weight: FontWeight.w600, color: color)),
      ],
    ),
  );
}

String _storePointTierLabel(dynamic tier) {
  return switch (tier?.toString()) {
    'gold' => 'store_points_gold'.tr(),
    'silver' => 'store_points_silver'.tr(),
    _ => 'store_points_bronze'.tr(),
  };
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

double _distanceKm(double? fromLat, double? fromLng, double toLat, double toLng) {
  final originLat = fromLat ?? 32.8872;
  final originLng = fromLng ?? 13.1913;
  return Geolocator.distanceBetween(originLat, originLng, toLat, toLng) / 1000;
}

class HomeContentSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const HomeContentSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kWhite,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: kDisplayTextStyle(size: 16, weight: FontWeight.w700, color: kInk)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: kBodyTextStyle(color: kInk.withValues(alpha: 0.6), size: 12)),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
