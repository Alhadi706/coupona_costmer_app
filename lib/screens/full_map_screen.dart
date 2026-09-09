import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/company_server_service.dart';
import 'package:coupona_app/theme/design_tokens.dart';
import 'store_details_screen.dart';

class FullMapScreen extends StatefulWidget {
  final bool embedded;

  const FullMapScreen({super.key, this.embedded = false});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  static const LatLng _tripoliDefaultCenter = LatLng(32.8872, 13.1913);

  final MapController _mapController = MapController();
  String searchText = '';
  String selectedCategory = '';
  Map<String, dynamic>? selectedStore;
  LatLng _mapCenter = _tripoliDefaultCenter;
  double _mapZoom = 12.0;
  Future<List<Map<String, dynamic>>>? _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = CompanyServerService.getStores();
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    final LatLng storePoint = LatLng(
      _toDouble(store['lat']),
      _toDouble(store['lng']),
    );
    _mapController.move(storePoint, _mapZoom);

    setState(() {
      selectedStore = store;
      _mapCenter = storePoint;
    });
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store['name'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
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
                Row(
                  children: [
                    const Icon(Icons.phone, size: 18),
                    SizedBox(width: 6),
                    Text(store['phone']),
                  ],
                ),
              ],
              if (store['location'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 18),
                    SizedBox(width: 6),
                    Text(store['location']),
                  ],
                ),
              ],
              if (store['merchantId'] != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _storeFact(
                      Icons.loyalty_outlined,
                      _pointTierLabel(store['pointTier']),
                      kGold,
                    ),
                    _storeFact(
                      Icons.add_circle_outline,
                      'store_points_rate'.tr(
                        namedArgs: {'value': '${store['pointValue'] ?? 0}'},
                      ),
                      kTeal,
                    ),
                    _storeFact(
                      Icons.local_offer_outlined,
                      'store_offers_count'.tr(
                        namedArgs: {'count': '${store['offersCount'] ?? 0}'},
                      ),
                      kTeal,
                    ),
                    _storeFact(
                      Icons.card_giftcard_outlined,
                      'store_rewards_count'.tr(
                        namedArgs: {'count': '${store['rewardsCount'] ?? 0}'},
                      ),
                      kTeal,
                    ),
                    _storeFact(
                      Icons.inventory_2_outlined,
                      'store_products_count'.tr(
                        namedArgs: {'count': '${store['productsCount'] ?? 0}'},
                      ),
                      kTeal,
                    ),
                  ],
                ),
                if ((store['coalitions'] as List?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    (store['coalitions'] as List)
                        .map((item) => (item as Map)['name']?.toString() ?? '')
                        .where((name) => name.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(
                      color: kTealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: store['merchantId'] == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoreDetailsScreen(store: store),
                                ),
                              );
                            },
                      icon: const Icon(Icons.storefront_outlined),
                      label: Text('store_open_page'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDirections(store),
                      icon: const Icon(Icons.directions_outlined),
                      label: Text('store_directions'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storeFact(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }

  String _pointTierLabel(dynamic tier) {
    return switch (tier?.toString()) {
      'gold' => 'store_points_gold'.tr(),
      'silver' => 'store_points_silver'.tr(),
      _ => 'store_points_bronze'.tr(),
    };
  }

  Future<void> _openDirections(Map<String, dynamic> store) async {
    final lat = _toDouble(store['lat']);
    final lng = _toDouble(store['lng']);
    final destination = lat != 0 && lng != 0
        ? '$lat,$lng'
        : Uri.encodeComponent(
            (store['location'] ?? store['name'] ?? '').toString(),
          );
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<Map<String, dynamic>>>(
      future: _storesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stores = snapshot.data!;
        // فلترة حسب البحث والتصنيف
        final filteredStores = stores.where((store) {
          final matchesSearch =
              searchText.isEmpty ||
              (store['name']?.toString().contains(searchText) ?? false);
          final matchesCategory =
              selectedCategory.isEmpty ||
              (store['category'] == selectedCategory);
          return matchesSearch && matchesCategory;
        }).toList();
        final categories =
            stores
                .map((store) => (store['category'] ?? '').toString().trim())
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _mapZoom,
                onPositionChanged: (position, hasGesture) {
                  final LatLng? center = position.center;
                  if (center == null) return;
                  _mapCenter = center;
                  _mapZoom = position.zoom ?? _mapZoom;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kupuna.coupona',
                ),
                MarkerLayer(
                  markers: [
                    for (final store in filteredStores)
                      Marker(
                        width: 40,
                        height: 40,
                        point: LatLng(
                          _toDouble(store['lat']),
                          _toDouble(store['lng']),
                        ),
                        child: GestureDetector(
                          onTap: () => _showStoreDetails(store),
                          child: const Icon(
                            Icons.location_on,
                            color: kGold,
                            size: 36,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'search_store_or_category_hint'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.96),
                  ),
                  onChanged: (value) => setState(() => searchText = value),
                ),
              ),
            ),
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('all_categories'.tr()),
                      selected: selectedCategory.isEmpty,
                      onSelected: (_) => setState(() => selectedCategory = ''),
                    ),
                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: Text(_localizeCategory(category)),
                          selected: selectedCategory == category,
                          onSelected: (_) => setState(
                            () => selectedCategory =
                                selectedCategory == category ? '' : category,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kTeal,
        title: Text('stores_map_title'.tr()),
        leading: const BackButton(),
      ),
      body: body,
      /* legacy map layout removed in favor of the shared embedded map body. */
      /* builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snapshot.data!;
          // فلترة حسب البحث والتصنيف
          final filteredStores = stores.where((store) {
            final matchesSearch = searchText.isEmpty || (store['name']?.toString().contains(searchText) ?? false);
            final matchesCategory = selectedCategory.isEmpty || (store['category'] == selectedCategory);
            return matchesSearch && matchesCategory;
          }).toList();
          final categories = stores
              .map((store) => (store['category'] ?? '').toString().trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: _mapZoom,
                  onPositionChanged: (position, hasGesture) {
                    final LatLng? center = position.center;
                    if (center == null) {
                      return;
                    }
                    _mapCenter = center;
                    _mapZoom = position.zoom ?? _mapZoom;
                  },
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
                            child: Icon(Icons.location_on, color: kGold, size: 36),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // شريط البحث
              Positioned(
                top: 40,
                left: 24,
                right: 24,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kWhite.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: kInk.withValues(alpha: 0.6)),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            autofocus: false,
                            decoration: InputDecoration(
                              hintText: 'search_store_or_category_hint'.tr(),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) => setState(() => searchText = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // شريط التصنيفات
              Positioned(
                top: 95,
                left: 24,
                right: 24,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kWhite.withValues(alpha: 0.98),
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
                                backgroundColor: kSand,
                                selectedColor: kTeal,
                                checkmarkColor: kWhite,
                                labelStyle: TextStyle(
                                  color: selectedCategory == cat ? kWhite : kInk,
                                ),
                                onSelected: (_) => setState(() => selectedCategory == cat ? selectedCategory = '' : selectedCategory = cat),
                              ),
                            ),
                          FilterChip(
                            label: Text('all_categories'.tr()),
                            selected: selectedCategory == '',
                            backgroundColor: kSand,
                            selectedColor: kTeal,
                            checkmarkColor: kWhite,
                            labelStyle: TextStyle(
                              color: selectedCategory == '' ? kWhite : kInk,
                            ),
                            onSelected: (_) => setState(() => selectedCategory = ''),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }, */
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
