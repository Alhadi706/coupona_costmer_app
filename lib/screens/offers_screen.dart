// filepath: lib/screens/offers_screen.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offer_detail_screen.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('offers_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: () async {
          try {
            final snapshot = await FirebaseService.firestore.collection('offers').orderBy('createdAt', descending: true).get();
            return snapshot.docs.map((d) {
              final map = Map<String, dynamic>.from(d.data());
              map['id'] = d.id;
              map['createdAt'] = _timestampToDate(map['createdAt']);
              map['startDate'] = _timestampToDate(map['startDate']);
              map['endDate'] = _timestampToDate(map['endDate']);
              return map;
            }).toList();
          } catch (e) {
            debugPrint('Fetch offers error: $e');
            return <Map<String, dynamic>>[];
          }
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('offers_no_offers'.tr()));
          }
          final offers = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 900
                  ? 4
                  : width >= 600
                      ? 3
                      : 2;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: offers.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, i) => _OfferGridCard(offer: offers[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferGridCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _OfferGridCard({required this.offer});

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer['imageUrl']?.toString();
    final storeName = offer['storeName']?.toString() ?? '';
    final offerType = offer['offerType']?.toString() ?? '';
    final discount = offer['percent']?.toString() ?? offer['discountValue']?.toString() ?? '';
    final expires = _formatDate(offer['endDate']);
    return Material(
      elevation: 0,
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _OfferPlaceholder(),
                      )
                    : const _OfferPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (offerType.isNotEmpty)
                        _OfferChip(label: offerType),
                      if (discount.isNotEmpty)
                        _OfferChip(label: discount),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          expires.isEmpty ? '—' : 'offers_expires'.tr(namedArgs: {'date': expires}),
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () => _openDetails(context),
                      child: Text('offers_details_btn'.tr(), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferPlaceholder extends StatelessWidget {
  const _OfferPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.photo_size_select_actual_outlined, color: Colors.grey.shade500, size: 36),
    );
  }
}

class _OfferChip extends StatelessWidget {
  final String label;
  const _OfferChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepPurple),
      ),
    );
  }
}

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

String _formatDate(dynamic value) {
  final date = _timestampToDate(value);
  if (date == null) return '';
  return DateFormat.yMd().format(date);
}

