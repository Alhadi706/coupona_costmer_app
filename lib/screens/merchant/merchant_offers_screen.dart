import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../add_coupon_screen.dart';

class MerchantOffersScreen extends StatelessWidget {
  final String merchantId;
  const MerchantOffersScreen({super.key, required this.merchantId});

  void _openAddOffer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddCouponScreen(merchantId: merchantId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('offers')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text('merchant_offers_title'.tr()),
        actions: [
          IconButton(
            onPressed: () => _openAddOffer(context),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'merchant_offers_add'.tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOffer(context),
        icon: const Icon(Icons.add),
        label: Text('merchant_offers_add'.tr()),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_offers_error'.tr()));
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(child: Text('merchant_offers_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final data = docs[index].data();
              final offerKey = data['offerType']?.toString() ?? 'merchant_offers_unknown';
              final offerLabel = offerKey.contains('_') ? offerKey.tr() : offerKey;
              return Card(
                child: ListTile(
                  title: Text(offerLabel),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description']?.toString() ?? ''),
                      if (data['startDate'] != null && data['endDate'] != null)
                        Text(
                          'merchant_offers_date_fmt'.tr(args: [
                            _formatDate(data['startDate']),
                            _formatDate(data['endDate']),
                          ]),
                        ),
                    ],
                  ),
                  trailing: Text(data['discountValue']?.toString() ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat.yMd().format(value.toDate());
    }
    return '';
  }
}
