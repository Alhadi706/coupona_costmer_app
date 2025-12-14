import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/customer_profile.dart';
import '../../services/firestore/customer_repository.dart';

class MerchantCustomersScreen extends StatefulWidget {
  final String merchantId;
  const MerchantCustomersScreen({super.key, required this.merchantId});

  @override
  State<MerchantCustomersScreen> createState() => _MerchantCustomersScreenState();
}

class _MerchantCustomersScreenState extends State<MerchantCustomersScreen> {
  late final CustomerRepository _customerRepository;

  @override
  void initState() {
    super.initState();
    _customerRepository = CustomerRepository();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_customers_title'.tr())),
      body: StreamBuilder<List<CustomerProfile>>(
        stream: _customerRepository.watchCustomersForMerchant(widget.merchantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_customers_error'.tr()));
          }
          final customers = snapshot.data ?? const [];
          if (customers.isEmpty) {
            return Center(child: Text('merchant_customers_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final customer = customers[index];
              final points = customer.merchantPoints[widget.merchantId] ?? 0;
                final trimmedName = customer.name.trim();
                final initial = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade50,
                    child: Text(initial),
                  ),
                  title: Text(customer.name.isNotEmpty ? customer.name : customer.phone),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.phone),
                      Text('merchant_customers_points_fmt'.tr(args: [points.toString()])),
                      Text('merchant_customers_total_fmt'.tr(args: [customer.totalPoints.toStringAsFixed(1)])),
                    ],
                  ),
                  trailing: Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
