import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfferDetailScreen extends StatefulWidget {
  final Map<String, dynamic> offer;
  const OfferDetailScreen({Key? key, required this.offer}) : super(key: key);

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  String? address;
  bool isLoadingAddress = false;
  bool isLocatingUser = false;
  LatLng? _offerLatLng;
  LatLng? _userLatLng;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _getAddressFromLatLng();
    _parseOfferLatLng();
    _initUserLocation();
    if (_offerLatLng == null) {
      // حاول إيجاد موقع المتجر من مجموعة stores إذا لم يكن مخزناً في العرض
      _lookupStoreLocationByName();
    }
  }

  Future<void> _getAddressFromLatLng() async {
    final locationStr = widget.offer['location'];
    if (locationStr != null && locationStr.contains(',')) {
      final parts = locationStr.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        setState(() => isLoadingAddress = true);
        try {
          // استخدم Nominatim (OpenStreetMap) API المجاني
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&accept-language=ar',
          );
          final response = await http.get(url, headers: {
            'User-Agent': 'coupona-app/1.0 (your@email.com)'
          });
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final displayName = data['display_name'];
            if (displayName != null && displayName.isNotEmpty) {
              setState(() {
                address = displayName;
              });
            }
          }
        } catch (e) {
          setState(() => address = null);
        } finally {
          setState(() => isLoadingAddress = false);
        }
      }
    }
  }

  void _parseOfferLatLng() {
    final locationStr = widget.offer['location'];
    if (locationStr is String && locationStr.contains(',')) {
      final parts = locationStr.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        _offerLatLng = LatLng(lat, lng);
        _recomputeDistance();
      }
    }
  }

  Future<void> _lookupStoreLocationByName() async {
    final storeName = widget.offer['storeName'];
    if (storeName == null || storeName.toString().isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('name', isEqualTo: storeName)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final loc = data['location'];
        if (loc is GeoPoint) {
          setState(() {
            _offerLatLng = LatLng(loc.latitude, loc.longitude);
            _recomputeDistance();
          });
        } else if (loc is String && loc.contains(',')) {
          final parts = loc.split(',');
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
            if (lat != null && lng != null) {
              setState(() {
                _offerLatLng = LatLng(lat, lng);
                _recomputeDistance();
              });
            }
        }
      }
    } catch (_) {}
  }

  void _recomputeDistance() {
    if (_offerLatLng != null && _userLatLng != null) {
      final dist = const Distance();
      final meters = dist.as(LengthUnit.Meter, _userLatLng!, _offerLatLng!);
      _distanceKm = meters / 1000.0;
    }
  }

  Future<void> _initUserLocation() async {
    setState(() => isLocatingUser = true);
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission finalPerm = perm;
      if (perm == LocationPermission.denied) {
        finalPerm = await Geolocator.requestPermission();
      }
      if (finalPerm == LocationPermission.deniedForever || finalPerm == LocationPermission.denied) {
        setState(() => isLocatingUser = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _userLatLng = LatLng(pos.latitude, pos.longitude));
  _recomputeDistance();
    } catch (_) {
      // تجاهل الأخطاء الصامتة
    } finally {
      if (mounted) setState(() => isLocatingUser = false);
    }
  }

  Future<void> _openDirections() async {
    if (_offerLatLng == null) return;
    final origin = _userLatLng != null ? '${_userLatLng!.latitude},${_userLatLng!.longitude}' : '';
    final dest = '${_offerLatLng!.latitude},${_offerLatLng!.longitude}';
    // Google Maps directions fallback to universal lat,lng link
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest&origin=$origin&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String getEndDateText(String? endDate) {
    if (endDate == null || endDate.isEmpty) return '';
    try {
      // محاولة استخراج التاريخ فقط من النص
      final dateStr = endDate.split('T').first;
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff < 0) return 'انتهى';
      if (diff == 0) return 'ينتهي اليوم';
      if (diff == 1) return 'ينتهي غدًا';
      if (diff < 7) return 'ينتهي بعد $diff أيام';
      if (diff < 30) return 'ينتهي بعد $diff يومًا';
      if (diff < 365) return 'ينتهي بعد ${(diff / 30).floor()} شهر';
      return 'ينتهي بعد ${(diff / 365).floor()} سنة';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل العرض'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (offer['image'] != null && offer['image'] != '')
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                offer['image'],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(offer['storeName'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (offer['offerType'] != null && offer['offerType'] != '')
                Chip(label: Text(offer['offerType'])),
              if (offer['percent'] != null && offer['percent'] != '') ...[
                const SizedBox(width: 8),
                Chip(label: Text(offer['percent'])),
              ],
              const SizedBox(width: 8),
              if (offer['endDate'] != null && offer['endDate'] != '')
                Text(getEndDateText(offer['endDate']), style: const TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          if (offer['description'] != null && offer['description'] != '') ...[
            Text('الوصف:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(offer['description']),
            const SizedBox(height: 12),
          ],
          if (offer['conditions'] != null && offer['conditions'] != '') ...[
            Text('الشروط:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(offer['conditions']),
            const SizedBox(height: 12),
          ],
          if (offer['location'] != null && offer['location'] != '') ...[
            Text('الموقع:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (isLoadingAddress)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (address != null && address!.isNotEmpty)
              Text(address!, style: const TextStyle(color: Colors.blue))
            else
              Text(offer['location']),
            const SizedBox(height: 8),
            if (_offerLatLng != null)
              Container(
                height: 200,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.deepPurple.shade100)),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(
                    center: _offerLatLng,
                    zoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a','b','c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(point: _offerLatLng!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
                        if (_userLatLng != null)
                          Marker(point: _userLatLng!, width: 34, height: 34, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 34)),
                      ],
                    ),
                    if (_userLatLng != null && _offerLatLng != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_userLatLng!, _offerLatLng!],
                            color: Colors.blueAccent.withOpacity(0.6),
                            strokeWidth: 3,
                          )
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_distanceKm != null)
              Text('المسافة التقريبية: ${_distanceKm!.toStringAsFixed(2)} كم', style: const TextStyle(color: Colors.black87)),
            Row(
              children: [
                if (_offerLatLng != null)
                  ElevatedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions),
                    label: const Text('المسار'),
                  ),
                const SizedBox(width: 8),
                if (_userLatLng == null && !isLocatingUser)
                  OutlinedButton.icon(
                    onPressed: _initUserLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('موقعي'),
                  )
                else if (isLocatingUser)
                  const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (offer['phone'] != null && offer['phone'].toString().isNotEmpty) ...[
            Text('رقم الهاتف:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text(offer['phone']),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final phone = offer['phone'].toString();
                    final url = 'tel:$phone';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح الاتصال')),
                      );
                    }
                  },
                  icon: Icon(Icons.phone),
                  label: Text('اتصال'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    textStyle: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    builder: (context) => _ShareOptions(offer: offer),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('مشاركة العرض'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareOptions extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _ShareOptions({Key? key, required this.offer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shareText = 'عرض من كوبونا:\n${offer['storeName']}\n${offer['description']}\n${offer['location']}';
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مشاركة عبر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.green, size: 32), // بديل واتساب
                onPressed: () async {
                  final url = 'https://wa.me/?text=${Uri.encodeComponent(shareText)}';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } else {
                    Share.share(shareText);
                  }
                },
                tooltip: 'واتساب',
              ),
              IconButton(
                icon: const Icon(Icons.facebook, color: Colors.blue, size: 32),
                onPressed: () {
                  Share.share(shareText);
                },
                tooltip: 'فيسبوك',
              ),
              IconButton(
                icon: const Icon(Icons.telegram, color: Colors.blueAccent, size: 32),
                onPressed: () {
                  Share.share(shareText);
                },
                tooltip: 'تليجرام',
              ),
              IconButton(
                icon: const Icon(Icons.groups, color: Colors.deepPurple, size: 32),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت المشاركة في مجتمع كوبونا!')),
                  );
                },
                tooltip: 'مجتمع كوبونا',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

