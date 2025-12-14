import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen> {
  // ملاحظة: يجب لاحقًا استبدال منطق جلب العروض بمنطق Firestore
  late Future<List<Map<String, dynamic>>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = fetchOffers();
  }

  Future<List<Map<String, dynamic>>> fetchOffers() async {
    try {
      final snapshot = await FirebaseService.firestore
          .collection('offers')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        if (data['createdAt'] is Timestamp) data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Fetch offers error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة العروض'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: \n${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا يوجد عروض'));
          }
          final offers = snapshot.data!;
          return ListView.separated(
            itemCount: offers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return ListTile(
                leading: const Icon(Icons.local_offer),
                title: Text(offer['title'] ?? 'بدون عنوان'),
                subtitle: Text(offer['description'] ?? ''),
                trailing: Text(offer['id'].toString()),
              );
            },
          );
        },
      ),
    );
  }
}
