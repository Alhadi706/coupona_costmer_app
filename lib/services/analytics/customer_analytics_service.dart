import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/customer_profile.dart';
import '../firebase_service.dart';
import '../firestore/customer_repository.dart';

class CustomerAnalyticsSnapshot {
  final double totalSpend;
  final int totalInvoices;
  final int uniqueStores;
  final int registeredStores;
  final double averageInvoiceValue;
  final int monthlyInvoices;
  final double monthlySpend;
  final List<MerchantInsight> topMerchants;
  final List<InvoiceSummary> recentInvoices;

  const CustomerAnalyticsSnapshot({
    required this.totalSpend,
    required this.totalInvoices,
    required this.uniqueStores,
    required this.registeredStores,
    required this.averageInvoiceValue,
    required this.monthlyInvoices,
    required this.monthlySpend,
    required this.topMerchants,
    required this.recentInvoices,
  });
}

class MerchantInsight {
  final String merchantId;
  final String merchantName;
  final int invoicesCount;
  final double totalSpend;

  const MerchantInsight({
    required this.merchantId,
    required this.merchantName,
    required this.invoicesCount,
    required this.totalSpend,
  });
}

class InvoiceSummary {
  final String id;
  final String merchantId;
  final String merchantName;
  final double amount;
  final DateTime? createdAt;
  final String status;

  const InvoiceSummary({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.amount,
    required this.createdAt,
    required this.status,
  });

  InvoiceSummary copyWith({String? merchantName}) {
    return InvoiceSummary(
      id: id,
      merchantId: merchantId,
      merchantName: merchantName ?? this.merchantName,
      amount: amount,
      createdAt: createdAt,
      status: status,
    );
  }
}

class CustomerAnalyticsService {
  CustomerAnalyticsService({
    FirebaseFirestore? firestore,
    CustomerRepository? customerRepository,
  }) : _firestore = firestore ?? FirebaseService.firestore,
       _customerRepository =
           customerRepository ??
           CustomerRepository(
             firestore: firestore ?? FirebaseService.firestore,
           );

  final FirebaseFirestore _firestore;
  final CustomerRepository _customerRepository;

  Future<CustomerAnalyticsSnapshot> load(String customerId) async {
    final query = _firestore
        .collection('invoices')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true);

    final invoicesSnapshot = await query.get();
    final CustomerProfile? profile = await _customerRepository.fetchCustomer(
      customerId,
    );

    double totalSpend = 0;
    int monthlyInvoices = 0;
    double monthlySpend = 0;
    final merchantCounts = <String, int>{};
    final merchantSpend = <String, double>{};
    final merchantIds = <String>{};
    final recentInvoices = <InvoiceSummary>[];

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    for (final doc in invoicesSnapshot.docs) {
      final data = doc.data();
      final merchantId = data['merchantId']?.toString() ?? '';
      final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final createdAt = _timestampToDate(data['createdAt']);

      totalSpend += amount;

      if (merchantId.isNotEmpty) {
        merchantIds.add(merchantId);
        merchantCounts[merchantId] = (merchantCounts[merchantId] ?? 0) + 1;
        merchantSpend[merchantId] = (merchantSpend[merchantId] ?? 0) + amount;
      }

      if (createdAt != null && !createdAt.isBefore(monthStart)) {
        monthlyInvoices += 1;
        monthlySpend += amount;
      }

      if (recentInvoices.length < 6) {
        recentInvoices.add(
          InvoiceSummary(
            id: doc.id,
            merchantId: merchantId,
            merchantName: '',
            amount: amount,
            createdAt: createdAt,
            status: data['status']?.toString() ?? 'pending',
          ),
        );
      }
    }

    final merchantNames = await _fetchMerchantNames(merchantIds.toList());

    final sortedMerchants = merchantCounts.entries.toList()
      ..sort((a, b) {
        final spendDiff = (merchantSpend[b.key] ?? 0).compareTo(
          merchantSpend[a.key] ?? 0,
        );
        if (spendDiff != 0) return spendDiff;
        return (merchantCounts[b.key] ?? 0).compareTo(
          merchantCounts[a.key] ?? 0,
        );
      });

    final topMerchants = sortedMerchants
        .take(3)
        .map(
          (entry) => MerchantInsight(
            merchantId: entry.key,
            merchantName: merchantNames[entry.key] ?? '—',
            invoicesCount: entry.value,
            totalSpend: merchantSpend[entry.key] ?? 0,
          ),
        )
        .toList();

    final registeredStores = profile?.merchantPoints.length ?? 0;

    return CustomerAnalyticsSnapshot(
      totalSpend: totalSpend,
      totalInvoices: invoicesSnapshot.docs.length,
      uniqueStores: merchantIds.length,
      registeredStores: registeredStores,
      averageInvoiceValue: invoicesSnapshot.docs.isNotEmpty
          ? totalSpend / invoicesSnapshot.docs.length
          : 0,
      monthlyInvoices: monthlyInvoices,
      monthlySpend: monthlySpend,
      topMerchants: topMerchants,
      recentInvoices: recentInvoices
          .map(
            (invoice) => invoice.copyWith(
              merchantName: merchantNames[invoice.merchantId] ?? '—',
            ),
          )
          .toList(),
    );
  }

  Future<Map<String, String>> _fetchMerchantNames(
    List<String> merchantIds,
  ) async {
    if (merchantIds.isEmpty) return const <String, String>{};
    final Map<String, String> result = {};
    const chunkSize = 10;
    for (var i = 0; i < merchantIds.length; i += chunkSize) {
      final end = math.min(i + chunkSize, merchantIds.length);
      final chunk = merchantIds.sublist(i, end);
      final snap = await _firestore
          .collection('merchants')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = doc.data()['name']?.toString() ?? '—';
      }
    }
    return result;
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
}
