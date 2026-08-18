import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../screens/full_map_screen.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class MapBar extends StatefulWidget {
  final VoidCallback? onExpand;
  final ValueChanged<String>? onTargetLocationChanged;

  const MapBar({super.key, this.onExpand, this.onTargetLocationChanged});

  @override
  State<MapBar> createState() => _MapBarState();
}

class _MapBarState extends State<MapBar> {
  static const LatLng _tripoliDefaultCenter = LatLng(32.8872, 13.1913);
  late final Future<List<Map<String, dynamic>>> _storesFuture;

  String searchText = '';
  String selectedCategory = '';
  String selectedLocation = '';
  Map<String, dynamic>? selectedStore;

  @override
  void initState() {
    super.initState();
    _storesFuture = CompanyServerService.getStores();
  }

  void _expandMap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FullMapScreen()),
    );
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    setState(() {
      selectedStore = store;
    });
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            if (store['category'] != null) ...[
              const SizedBox(height: 8),
              Chip(label: Text(_localizeCategory(store['category']))),
            ],
            if (store['description'] != null) ...[
              const SizedBox(height: 8),
              Text(store['description']),
            ],
            if (store['phone'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.phone, size: 18), SizedBox(width: 6), Text(store['phone'])]),
            ],
            if (store['location'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.location_on, size: 18), SizedBox(width: 6), Text(store['location'])]),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _storesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stores = snapshot.data!;
        // فلترة حسب البحث والتصنيف
        final filteredStores = stores.where((store) {
          final matchesSearch = searchText.isEmpty || (store['name']?.toString().contains(searchText) ?? false);
          final matchesCategory = selectedCategory.isEmpty || (store['category'] == selectedCategory);
          final matchesLocation = selectedLocation.isEmpty || (store['location']?.toString() == selectedLocation);
          return matchesSearch && matchesCategory && matchesLocation;
        }).toList();
        final categories = stores
            .map((store) => (store['category'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final locations = stores
            .map((store) => (store['location'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: _expandMap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.28,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: filteredStores.isNotEmpty
                              ? LatLng(_toDouble(filteredStores[0]['lat']), _toDouble(filteredStores[0]['lng']))
                              : _tripoliDefaultCenter,
                          initialZoom: 12.0,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.coupona_app',
                            tileProvider: NetworkTileProvider(),
                          ),
                          MarkerLayer(
                            markers: [
                              for (final store in filteredStores)
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: LatLng(_toDouble(store['lat']), _toDouble(store['lng'])),
                                  child: GestureDetector(
                                    onTap: () => _showStoreDetails(store),
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.fullscreen, color: kTealDark),
                            onPressed: _expandMap,
                            tooltip: 'expand_map'.tr(),
                          ),
                        ),
                      ),
                      // شريط التصنيفات
                      Positioned(
                        top: 95,
                        left: 24,
                        right: 24,
                        child: IgnorePointer(
                          ignoring: false,
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: Duration(milliseconds: 200),
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.98),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final cat in categories)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: FilterChip(
                                            label: Text(_localizeCategory(cat)),
                                            selected: selectedCategory == cat,
                                            onSelected: (_) => setState(() => selectedCategory = selectedCategory == cat ? '' : cat),
                                          ),
                                        ),
                                      FilterChip(
                                        label: Text('all_categories'.tr()),
                                        selected: selectedCategory == '',
                                        onSelected: (_) => setState(() => selectedCategory = ''),
                                      ),
                                      const SizedBox(width: 8),
                                      for (final loc in locations)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: FilterChip(
                                            label: Text(loc),
                                            selected: selectedLocation == loc,
                                            onSelected: (_) {
                                              setState(() {
                                                selectedLocation = selectedLocation == loc ? '' : loc;
                                              });
                                              widget.onTargetLocationChanged?.call(selectedLocation);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _localizeCategory(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'مطاعم':
      case 'restaurants':
        return 'restaurants'.tr();
      case 'عقارات':
      case 'real_estate':
      case 'real estate':
        return 'real_estate'.tr();
      case 'ملابس':
      case 'clothes':
        return 'clothes'.tr();
      case 'إلكترونيات':
      case 'electronics':
        return 'electronics'.tr();
      case 'استراحات':
      case 'resthouses':
        return 'resthouses'.tr();
      case 'صحة':
      case 'health':
        return 'health'.tr();
      case 'أنشطة':
      case 'activities':
        return 'activities'.tr();
      case 'أخرى':
      case 'other':
        return 'other'.tr();
      case 'مجوهرات':
      case 'jewelry':
        return 'jewelry'.tr();
      case 'سيارات':
      case 'cars':
        return 'cars'.tr();
      case 'إقامة':
      case 'accommodation':
        return 'accommodation'.tr();
      default:
        return (value ?? '').toString();
    }
  }
}
