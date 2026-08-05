import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'offer_detail_screen.dart';
import '../services/company_server_service.dart';

class CategoryOffersScreen extends StatelessWidget {
  final String categoryName;
  const CategoryOffersScreen({super.key, required this.categoryName});

  Widget _buildOfferImage(String imageUrl) {
    final String trimmed = imageUrl.trim();
    final bool isAsset = trimmed.startsWith('assets/');
    if (trimmed.isEmpty) {
      return Container(
        height: 180,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 52),
      );
    }
    if (isAsset) {
      return Image.asset(
        trimmed,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      trimmed,
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 180,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 52),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('offers_for_category'.tr(namedArgs: {'category': categoryName.tr()})),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 6))
            .asyncMap((_) => CompanyServerService.getOffers(category: categoryName))
            .startWithFuture(CompanyServerService.getOffers(category: categoryName)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return Center(child: Text('no_offers_for_category'.tr()));
          }
          final offers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              final imageUrl = (offer['imageUrl'] ?? offer['image'] ?? '').toString();
              final storeName = (offer['storeName'] ?? 'featured_offer'.tr()).toString();
              final offerType = (offer['offerType'] ?? '').toString();
              final percent = (offer['percent'] ?? '').toString();
              final endDate = (offer['endDate'] ?? '').toString();
              final location = (offer['location'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Stack(
                        children: [
                          _buildOfferImage(imageUrl),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                offerType.isEmpty ? 'offer'.tr() : offerType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (percent.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    percent,
                                    style: TextStyle(
                                      color: Colors.deepPurple.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (endDate.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'ends_on'.tr(namedArgs: {'date': endDate}),
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OfferDetailScreen(offer: offer),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('view_details'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
