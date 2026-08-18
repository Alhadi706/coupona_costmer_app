import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../theme/design_tokens.dart';

class OfferDetailScreen extends StatefulWidget {
  final Map<String, dynamic> offer;
  const OfferDetailScreen({super.key, required this.offer});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  String? address;
  bool isLoadingAddress = false;

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  LatLng? _extractLatLng() {
    final double? directLat = _toDouble(widget.offer['lat']) ?? _toDouble(widget.offer['latitude']);
    final double? directLng = _toDouble(widget.offer['lng']) ?? _toDouble(widget.offer['longitude']);
    if (directLat != null && directLng != null) {
      return LatLng(directLat, directLng);
    }

    final String locationRaw = (widget.offer['location'] ?? '').toString().trim();
    final parts = locationRaw.split(',');
    if (parts.length == 2) {
      final maybeLat = _toDouble(parts[0]);
      final maybeLng = _toDouble(parts[1]);
      if (maybeLat != null && maybeLng != null) {
        return LatLng(maybeLat, maybeLng);
      }
    }

    return null;
  }

  Widget _buildOfferImage(String imageUrl) {
    final String trimmed = imageUrl.trim();
    final bool isAsset = trimmed.startsWith('assets/');
    if (trimmed.isEmpty) {
      return Container(
        height: 220,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 58),
      );
    }
    if (isAsset) {
      return Image.asset(
        trimmed,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      trimmed,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 220,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 58),
      ),
    );
  }

  Future<void> _openMap(LatLng position) async {
    final geoUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMapByQuery(String query) async {
    final geoUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildMapCard(BuildContext context) {
    final LatLng? point = _extractLatLng();
    final String locationText = (widget.offer['location'] ?? '').toString().trim();

    if (point == null && locationText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: kTeal),
                SizedBox(width: 6),
                Text(
                  'location_on_map',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (point != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'coupona_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 34,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'no_precise_coordinates_offer'.tr(),
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            if (locationText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationText,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (point != null) {
                    await _openMap(point);
                  } else if (locationText.isNotEmpty) {
                    await _openMapByQuery(locationText);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('open_in_maps'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getAddressFromLatLng();
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
    final imageUrl = (widget.offer['imageUrl'] ?? widget.offer['image'] ?? '').toString();
    final storeName = (widget.offer['storeName'] ?? '').toString();
    final offerType = (widget.offer['offerType'] ?? '').toString();
    final percent = (widget.offer['percent'] ?? '').toString();
    final endDate = (widget.offer['endDate'] ?? '').toString();
    final description = (widget.offer['description'] ?? '').toString();
    final conditions = (widget.offer['conditions'] ?? '').toString();
    final location = (widget.offer['location'] ?? '').toString();
    final phone = (widget.offer['phone'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('offer_details_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _buildOfferImage(imageUrl),
          ),
          const SizedBox(height: 16),
          Text(
            storeName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (offerType.isNotEmpty)
                Chip(
                  backgroundColor: kSand,
                  label: Text(offerType),
                ),
              if (percent.isNotEmpty)
                Chip(
                  backgroundColor: Colors.green.shade50,
                  label: Text(percent),
                ),
              if (endDate.isNotEmpty)
                Chip(
                  backgroundColor: Colors.red.shade50,
                  label: Text('ends_on'.tr(namedArgs: {'date': endDate})),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('description'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 12),
          ],
          if (conditions.isNotEmpty) ...[
            Text('conditions'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(conditions),
            const SizedBox(height: 12),
          ],
          if (location.isNotEmpty) ...[
            Text('location'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(location),
            const SizedBox(height: 12),
          ],
          _buildMapCard(context),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('phone_number'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(phone),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final url = 'tel:$phone';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('could_not_open_call'.tr())),
                      );
                    }
                  },
                  icon: Icon(Icons.phone),
                  label: Text('call'.tr()),
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
                    builder: (context) => _ShareOptions(offer: widget.offer),
                  );
                },
                icon: const Icon(Icons.share),
                label: Text('share_offer'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: kWhite,
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
  const _ShareOptions({required this.offer});

  @override
  Widget build(BuildContext context) {
    final shareText = 'share_offer_text'.tr(namedArgs: {
      'storeName': '${offer['storeName']}',
      'description': '${offer['description']}',
      'location': '${offer['location']}',
    });
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('share_via'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                tooltip: 'whatsapp'.tr(),
              ),
              IconButton(
                icon: const Icon(Icons.facebook, color: Colors.blue, size: 32),
                onPressed: () {
                  Share.share(shareText);
                },
                tooltip: 'facebook'.tr(),
              ),
              IconButton(
                icon: const Icon(Icons.telegram, color: Colors.blueAccent, size: 32),
                onPressed: () {
                  Share.share(shareText);
                },
                tooltip: 'telegram'.tr(),
              ),
              IconButton(
                icon: const Icon(Icons.groups, color: kTeal, size: 32),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('shared_in_community_success'.tr())),
                  );
                },
                tooltip: 'community_title'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

