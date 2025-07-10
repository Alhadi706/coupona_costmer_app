import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

class FullMapScreen extends StatefulWidget {
  const FullMapScreen({Key? key}) : super(key: key);

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  String searchText = '';
  String selectedCategory = '';
  Map<String, dynamic>? selectedStore;

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade700,
        title: const Text('خريطة المحلات'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
          // قائمة التصنيفات المخصصة
          final List<String> categories = [
            'غذائية',
            'عيادات',
            'ملابس',
            'مجوهرات',
            'مطاعم',
            'إلكترونيات',
            'استراحات',
            'صحة',
            'أنشطة',
            'أخرى',
          ];
          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  center: filteredStores.isNotEmpty
                      ? LatLng(filteredStores[0]['lat'], filteredStores[0]['lng'])
                      : LatLng(24.7136, 46.6753),
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
                      color: Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey),
                        SizedBox(width: 8),
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
                                onSelected: (_) => setState(() => selectedCategory == cat ? selectedCategory = '' : selectedCategory = cat),
                              ),
                            ),
                          FilterChip(
                            label: const Text('جميع الفئات'),
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
          );
        },
      ),
    );
  }
}
