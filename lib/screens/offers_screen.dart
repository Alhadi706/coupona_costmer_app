// filepath: lib/screens/offers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offer_detail_screen.dart';
import 'home_screen.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض المتوفرة حاليًا'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('offers').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد عروض متاحة حالياً'));
          }
          final offers = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, i) {
              final offer = offers[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: offer['imageUrl'] != null && offer['imageUrl'] != ''
                          ? Image.network(
                              offer['imageUrl'],
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 140,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
                              ),
                            )
                          : Container(
                              height: 140,
                              color: Colors.grey.shade200,
                              child: Icon(Icons.image, color: Colors.grey, size: 60),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer['storeName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Chip(label: Text(offer['offerType'] ?? '')),
                              if ((offer['percent'] ?? '').isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Chip(label: Text(offer['percent'] ?? '')),
                              ],
                              const SizedBox(width: 8),
                              Text('ينتهي: ${offer['endDate'] ?? ''}', style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                              child: const Text('عرض التفاصيل'),
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

