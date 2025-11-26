import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../../services/firebase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/map_item.dart';
import '../../models/map_sample_data.dart';
import '../../screens/full_map_screen.dart';

class MapBar extends StatefulWidget {
  final VoidCallback? onExpand;
  const MapBar({Key? key, this.onExpand}) : super(key: key);

  @override
  State<MapBar> createState() => _MapBarState();
}

class _MapBarState extends State<MapBar> {
  String searchText = '';
  String selectedCategory = '';
  List<MapItem> mapItems = [];
  bool isLoading = true;
  bool isUsingFallback = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadMapItems();
  }

  Future<void> _loadMapItems() async {
    setState(() {
      isLoading = true;
      isUsingFallback = false;
      loadError = null;
    });
    try {
      final merchantsSnap = await FirebaseService.firestore.collection('merchants').get();
      final offersSnap = await FirebaseService.firestore.collection('offers').get();

      var merchants = merchantsSnap.docs.map((d) => Map<String, dynamic>.from(d.data() as Map<String, dynamic>)).toList();
      var offers = offersSnap.docs.map((d) => Map<String, dynamic>.from(d.data() as Map<String, dynamic>)).toList();

      var stores = merchants
          .whereType<Map<String, dynamic>>()
          .map((m) => MapItem.fromMap(m, MapItemType.store))
          .whereType<MapItem>()
          .toList();

        var offersList = offers
          .whereType<Map<String, dynamic>>()
          .map((o) => MapItem.fromMap(o, MapItemType.offer))
          .whereType<MapItem>()
          .toList();

      var usedFallback = false;

      if (stores.isEmpty && offers.isEmpty) {
        stores = List<MapItem>.from(sampleStoreItems);
        offersList = List<MapItem>.from(sampleOfferItems);
        usedFallback = true;
      }

      setState(() {
        mapItems = [...stores, ...offersList];
        isLoading = false;
        isUsingFallback = usedFallback;
      });
    } catch (error, stackTrace) {
      debugPrint('[MapBar] Failed to load map data: $error\n$stackTrace');
      setState(() {
        mapItems = [...sampleStoreItems, ...sampleOfferItems];
        isLoading = false;
        isUsingFallback = true;
        loadError = error.toString();
      });
    }
  }

  void _expandMap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FullMapScreen()),
    );
  }

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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // فلترة حسب البحث والتصنيف
    final filteredItems = mapItems.where((item) {
      final matchesSearch = item.matchesSearch(searchText);
      final matchesCategory = item.matchesCategory(selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();
    // قائمة التصنيفات المخصصة (مفاتيح ترجمة)
    final List<String> categories = [
      'restaurants',
      'cars',
      'jewelry',
      'hotels',
      'real_estate',
      'clothing',
      'clinics',
      'electronics',
      'activities',
      'other',
    ];
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
                      center: filteredItems.isNotEmpty
                          ? filteredItems.first.position
                          : LatLng(24.7136, 46.6753),
                      zoom: 12.0,
                      interactiveFlags: InteractiveFlag.none,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.coupona_app',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          for (final item in filteredItems)
                            Marker(
                              width: 40,
                              height: 40,
                              point: item.position,
                              child: GestureDetector(
                                onTap: () => _showItemDetails(item),
                                child: Icon(
                                  item.type == MapItemType.store ? Icons.store : Icons.local_offer,
                                  color: item.type == MapItemType.store ? Colors.deepPurple : Colors.orange,
                                  size: 34,
                                ),
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
                        icon: Icon(Icons.fullscreen, color: Colors.deepPurple),
                        onPressed: _expandMap,
                        tooltip: 'تكبير الخريطة',
                      ),
                    ),
                  ),
                  if (isUsingFallback)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Card(
                        color: Colors.white.withOpacity(0.95),
                        elevation: 3,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            loadError != null
                                ? 'تعذر تحميل البيانات الحالية، لذلك نعرض بيانات تجريبية.'
                                : 'يتم عرض بيانات تجريبية للتجربة فقط.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                                    onSelected: (_) => setState(() => selectedCategory = selectedCategory == cat ? '' : cat),
                                  ),
                                ),
                              FilterChip(
                                label: Text('all_categories'.tr()),
                                selected: selectedCategory == '',
                                onSelected: (_) => setState(() => selectedCategory = ''),
                              ),
                            ],
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
  }
}