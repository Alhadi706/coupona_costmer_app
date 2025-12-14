import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MerchantPublicProfileScreen extends StatelessWidget {
  const MerchantPublicProfileScreen({super.key, required this.merchantId, this.placeholderName, this.coverImage});

  final String merchantId;
  final String? placeholderName;
  final String? coverImage;

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadMerchant() {
    return FirebaseFirestore.instance.collection('merchants').doc(merchantId).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(placeholderName ?? 'community_view_merchant'.tr()),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadMerchant(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('community_no_groups'.tr()));
          }
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if ((data['logoUrl'] ?? coverImage) != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    (data['logoUrl'] ?? coverImage) as String,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.store, size: 48),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                data['name']?.toString() ?? placeholderName ?? 'community_view_merchant'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (data['description'] != null)
                Text(data['description'].toString(), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (data['categories'] is List && (data['categories'] as List).isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (data['categories'] as List)
                      .map((cat) => Chip(label: Text(cat.toString())))
                      .toList(),
                ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text('contact_us'.tr()),
                  subtitle: Text(data['phone']?.toString() ?? '-'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.mail),
                  title: Text('email'.tr()),
                  subtitle: Text(data['email']?.toString() ?? '-'),
                ),
              ),
              if (data['merchantCode'] != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.confirmation_number),
                    title: Text('merchant_id_label'.tr()),
                    subtitle: Text(data['merchantCode'].toString()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
