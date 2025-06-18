import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('offers')
            .where('category', isEqualTo: categoryName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد عروض متاحة لهذه الفئة'));
          }
          final offers = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          return ListView.builder(
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: offer['image'] != null && offer['image'] != ''
                          ? Image.network(
                              offer['image'],
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
}
