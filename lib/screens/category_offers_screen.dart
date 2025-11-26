import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'offer_detail_screen.dart';

class CategoryOffersScreen extends StatelessWidget {
  final String categoryName;
  const CategoryOffersScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('عروض $categoryName'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchOffersFromSupabase(categoryName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد عروض متاحة لهذه الفئة'));
          }
          final offers = snapshot.data!;
          return ListView.builder(
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              final imageUrl = (offer['image'] ?? offer['imageUrl'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 210,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 210,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
                              ),
                            )
                          : Container(
                              height: 210,
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image, color: Colors.grey, size: 60),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  offer['storeName'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                ),
                                const SizedBox(height: 4),
                                if (offer['offerType'] != null && offer['offerType'] != '')
                                  Text('نوع العرض: ${offer['offerType']}', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13)),
                                if (offer['percent'] != null && offer['percent'] != '')
                                  Text('النسبة: ${offer['percent']}', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OfferDetailScreen(offer: offer),
                                ),
                              );
                            },
                            child: const Text('التفاصيل'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
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

  Future<List<Map<String, dynamic>>> _fetchOffersFromSupabase(String category) async {
    try {
      final snapshot = await FirebaseService.firestore
          .collection('offers')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        data['id'] = d.id;
        // convert Firestore Timestamp to DateTime if needed
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        }
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Firestore fetch offers error: $e');
      return [];
    }
  }
}
