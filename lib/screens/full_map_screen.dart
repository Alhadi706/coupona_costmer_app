import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/map_item.dart';
import '../models/map_sample_data.dart';

class FullMapScreen extends StatefulWidget {
  const FullMapScreen({Key? key}) : super(key: key);

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  String searchText = '';
  String selectedCategory = '';
  bool showStores = true;
  bool showOffers = true;

  void _showItemDetails(MapItem item) {
    final phone = item.data['phone']?.toString();
    final addressValue = item.data['location']?.toString() ?? item.data['address']?.toString();
    final offerValue = (item.data['discountValue'] ?? item.data['percent'] ?? '').toString();

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
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            if (item.category != null && item.category!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(item.category!.tr()),
                backgroundColor: item.type == MapItemType.offer ? Colors.orange.shade100 : Colors.deepPurple.shade50,
                labelStyle: TextStyle(
                  color: item.type == MapItemType.offer ? Colors.orange.shade800 : Colors.deepPurple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.subtitle!),
            ],
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.phone, size: 18), const SizedBox(width: 6), Text(phone)]),
            ],
            if (addressValue != null && addressValue.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(addressValue, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (item.type == MapItemType.offer && offerValue.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.local_offer, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 6),
                Text(
                  'تفاصيل العرض: $offerValue',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade700,
        title: const Text('خريطة المحلات'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<MapItem>>(
        future: _fetchMapItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var usedFallback = false;
          String? fallbackMessage;
          var allItems = snapshot.data ?? [];

          if (snapshot.hasError) {
            allItems = [...sampleStoreItems, ...sampleOfferItems];
            usedFallback = true;
            fallbackMessage = 'تعذر تحميل بيانات الخريطة من الخادم.';
          }

          if (allItems.isEmpty) {
            allItems = [...sampleStoreItems, ...sampleOfferItems];
            usedFallback = true;
            fallbackMessage ??= 'لا توجد بيانات نشطة حاليًا، نعرض بيانات تجريبية.';
          }

          final filteredItems = allItems.where((item) {
            final matchesType = (item.type == MapItemType.store && showStores) || (item.type == MapItemType.offer && showOffers);
            if (!matchesType) {
              return false;
            }
            final matchesSearch = item.matchesSearch(searchText);
            final matchesCategory = item.matchesCategory(selectedCategory);
            return matchesSearch && matchesCategory;
          }).toList();

          final markersToShow = filteredItems;
          final initialCenter = markersToShow.isNotEmpty
              ? markersToShow.first.position
              : const LatLng(24.7136, 46.6753);

              final List<String> categories = const [
                'restaurants',
                'cars',
                'jewelry',
                'hotels',
                'real_estate',
                'resthouses',
                'clothing',
                'clinics',
                'electronics',
                'activities',
                'other',
              ];

              return Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      center: initialCenter,
                      zoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.coupona_app',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          for (final item in markersToShow)
                            Marker(
                              width: 40,
                              height: 40,
                              point: item.position,
                              child: GestureDetector(
                                onTap: () => _showItemDetails(item),
                                child: Icon(
                                  item.type == MapItemType.store ? Icons.store : Icons.local_offer,
                                  color: item.type == MapItemType.store ? Colors.deepPurple : Colors.orange,
                                  size: 36,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (usedFallback)
                    Positioned(
                      top: 16,
                      left: 24,
                      right: 24,
                      child: Card(
                        color: Colors.white.withOpacity(0.95),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Text(
                            fallbackMessage ?? 'يتم عرض بيانات تجريبية للتجربة فقط.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  if (markersToShow.isEmpty)
                    Positioned(
                      top: 160,
                      left: 24,
                      right: 24,
                      child: Card(
                        color: Colors.white,
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'لا توجد نتائج مطابقة للبحث المحدد.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.98),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                autofocus: false,
                                decoration: InputDecoration(
                                  hintText: 'search_hint'.tr(),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) => setState(() => searchText = val),
                              ),
                            ),
                            if (searchText.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () => setState(() => searchText = ''),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // مرشحات التصنيفات وأنواع العناصر
                  Positioned(
                    top: 100,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.98),
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
                                        label: Text(cat.tr()),
                                        selected: selectedCategory == cat,
                                        onSelected: (_) => setState(() {
                                          selectedCategory = selectedCategory == cat ? '' : cat;
                                        }),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: FilterChip(
                                      label: Text('all_categories'.tr()),
                                      selected: selectedCategory.isEmpty,
                                      onSelected: (_) => setState(() => selectedCategory = ''),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.98),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('إظهار المحلات'),
                                  selected: showStores,
                                  onSelected: (value) => setState(() => showStores = value),
                                ),
                                FilterChip(
                                  label: const Text('إظهار العروض'),
                                  selected: showOffers,
                                  onSelected: (value) => setState(() => showOffers = value),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<List<MapItem>> _fetchMapItems() async {
    try {
      final client = SupabaseService.client;

      final merchantsResponse = await client.from('merchants').select();
      final offersResponse = await client.from('offers').select();

      final merchants = (merchantsResponse as List?) ?? [];
      final offers = (offersResponse as List?) ?? [];

      final storeItems = merchants
          .whereType<Map<String, dynamic>>()
          .map((m) => MapItem.fromMap(m, MapItemType.store))
          .whereType<MapItem>()
          .toList();

      final offerItems = offers
          .whereType<Map<String, dynamic>>()
          .map((o) => MapItem.fromMap(o, MapItemType.offer))
          .whereType<MapItem>()
          .toList();

      return [...storeItems, ...offerItems];
    } catch (err, st) {
      debugPrint('[FullMapScreen] fetch error: $err\n$st');
      return [];
    }
  }
}
