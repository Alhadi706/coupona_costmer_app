import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

class MerchantMapScreen extends StatefulWidget {
  final String initialMerchantCode;
  const MerchantMapScreen({Key? key, this.initialMerchantCode = 'TRPCF2'}) : super(key: key);

  @override
  State<MerchantMapScreen> createState() => _MerchantMapScreenState();
}

class _MerchantMapScreenState extends State<MerchantMapScreen> {
  late TextEditingController _codeCtrl;
  String _merchantCode = '';

  @override
  void initState() {
    super.initState();
    _merchantCode = widget.initialMerchantCode;
    _codeCtrl = TextEditingController(text: widget.initialMerchantCode);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خريطة المتاجر حسب رمز التاجر')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رمز التاجر',
                      hintText: 'مثال: TRPCF2',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _merchantCode = _codeCtrl.text.trim(); });
                  },
                  child: const Text('تحميل'),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stores')
                  .where('merchant_code', isEqualTo: _merchantCode)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                final markers = <Marker>[];
                LatLng center = const LatLng(32.8872, 13.1913); // طرابلس افتراضي
                if (docs.isNotEmpty) {
                  final first = docs.first.data() as Map<String, dynamic>;
                  final gp = first['location'];
                  if (gp is GeoPoint) {
                    center = LatLng(gp.latitude, gp.longitude);
                  }
                }
                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '') as String;
                  final gp = data['location'];
                  if (gp is GeoPoint) {
                    markers.add(
                      Marker(
                        point: LatLng(gp.latitude, gp.longitude),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    );
                  }
                }

                return Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(center: center, zoom: 13.0),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          if (markers.isNotEmpty) MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                    Container(
                      height: 140,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey.shade100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          return Container(
                            width: 220,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('العلامة: ${data['brand'] ?? '-'}'),
                                Text('رمز التاجر: ${data['merchant_code'] ?? '-'}'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
