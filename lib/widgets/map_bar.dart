import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
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
  Map<String, dynamic>? selectedStore;

  void _expandMap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FullMapScreen()),
    );
  }

  void _shrinkMap() {
    setState(() {
      selectedStore = null;
    });
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
              Chip(label: Text(store['category'])),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('stores').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('لا توجد بيانات متاحة'));
        }
        List<Map<String, dynamic>> stores = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        // فلترة حسب البحث والتصنيف
        final filteredStores = stores.where((store) {
          final matchesSearch = searchText.isEmpty || (store['name']?.toString().contains(searchText) ?? false);
          final matchesCategory = selectedCategory.isEmpty || (store['category'] == selectedCategory);
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
                          center: filteredStores.isNotEmpty
                              ? LatLng(filteredStores[0]['lat'], filteredStores[0]['lng'])
                              : LatLng(24.7136, 46.6753),
                          zoom: 12.0,
                          interactiveFlags: InteractiveFlag.none,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.coupona_app',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final store in filteredStores)
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: LatLng(store['lat'], store['lng']),
                                  child: GestureDetector(
                                    onTap: () => _showStoreDetails(store),
                                    child: Icon(Icons.location_on, color: Colors.red, size: 36),
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
                      // شريط التصنيفات
                      Positioned(
                        top: 95,
                        left: 24,
                        right: 24,
                        child: IgnorePointer(
                          ignoring: false,
                          child: AnimatedOpacity(
                            opacity: true ? 1.0 : 0.0,
                            duration: Duration(milliseconds: 200),
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
}