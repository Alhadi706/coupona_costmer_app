import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

class OfferDetailScreen extends StatefulWidget {
  final Map<String, dynamic> offer;
  const OfferDetailScreen({Key? key, required this.offer}) : super(key: key);

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  String? address;
  bool isLoadingAddress = false;

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

  String _getEndDateText(String? endDate) {
    if (endDate == null || endDate.isEmpty) return '';
    try {
      final dateStr = endDate.split('T').first;
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff < 0) return 'offer_expired'.tr();
      if (diff == 0) return 'offer_expires_today'.tr();
      if (diff == 1) return 'offer_expires_tomorrow'.tr();
      if (diff < 7) return 'offer_expires_in_days'.tr(namedArgs: {'days': diff.toString()});
      if (diff < 30) return 'offer_expires_in_days'.tr(namedArgs: {'days': diff.toString()});
      if (diff < 365) return 'offer_expires_in_months'.tr(namedArgs: {'months': (diff ~/ 30).toString()});
      return 'offer_expires_in_years'.tr(namedArgs: {'years': (diff ~/ 365).toString()});
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Scaffold(
      appBar: AppBar(
        title: Text('offer_details_title'.tr()),
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
                Chip(label: Text((offer['offerType']?.toString().trim() ?? '').tr(), style: const TextStyle(color: Colors.white))),
              if (offer['percent'] != null && offer['percent'] != '') ...[
                const SizedBox(width: 8),
                Chip(label: Text(offer['percent'])),
              ],
              const SizedBox(width: 8),
              if (offer['endDate'] != null && offer['endDate'] != '')
                Text(_getEndDateText(offer['endDate']), style: const TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          if (offer['description'] != null && offer['description'] != '') ...[
            Text(tr('offer_description') + ':', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(offer['description']),
            const SizedBox(height: 12),
          ],
          if (offer['conditions'] != null && offer['conditions'] != '') ...[
            Text(tr('offer_conditions') + ':', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(offer['conditions']),
            const SizedBox(height: 12),
          ],
          if (offer['location'] != null && offer['location'] != '') ...[
            Text(tr('offer_location') + ':', style: TextStyle(fontWeight: FontWeight.bold)),
            if (isLoadingAddress)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (address != null && address!.isNotEmpty)
              Text(address!, style: const TextStyle(color: Colors.blue))
            else
              Text(offer['location']),
            const SizedBox(height: 12),
          ],
          if (offer['phone'] != null && offer['phone'].toString().isNotEmpty) ...[
            Text(tr('offer_phone') + ':', style: TextStyle(fontWeight: FontWeight.bold)),
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

