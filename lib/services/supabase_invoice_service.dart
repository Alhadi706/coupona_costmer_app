import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class SupabaseInvoiceService {
  static Future<void> addInvoice({
    required String invoiceNumber,
    required String storeName,
    required DateTime date,
    required List<Map<String, dynamic>> products,
    required double total,
    required String userId,
    required String merchantId,
    required String uniqueHash,
  }) async {
    await FirebaseService.firestore.collection('invoices').add({
      'invoice_number': invoiceNumber,
      'store_name': storeName,
      'date': date.toIso8601String(),
      'products': products,
      'total': total,
      'user_id': userId,
      'merchant_id': merchantId,
      'unique_hash': uniqueHash,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<InvoiceRecord>> fetchInvoicesForUser(String userId) async {
    final snapshot = await FirebaseService.firestore
      .collection('invoices')
      .where('user_id', isEqualTo: userId)
      .orderBy('date', descending: true)
      .get();
    return snapshot.docs.map((d) {
      final map = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
      map['id'] = d.id;
      return InvoiceRecord.fromJson(map);
    }).toList();
  }

  static Future<List<InvoiceRecord>> fetchInvoicesForMerchant(String merchantId) async {
    final snapshot = await FirebaseService.firestore
      .collection('invoices')
      .where('merchant_id', isEqualTo: merchantId)
      .orderBy('date', descending: true)
      .get();
    return snapshot.docs.map((d) {
      final map = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
      map['id'] = d.id;
      return InvoiceRecord.fromJson(map);
    }).toList();
  }

  static Future<List<String>> fetchDistinctMerchantIdsForUser(String userId) async {
    final invoices = await fetchInvoicesForUser(userId);
    final merchantIds = <String>{};
    for (final invoice in invoices) {
      if (invoice.merchantId != null && invoice.merchantId!.isNotEmpty) {
        merchantIds.add(invoice.merchantId!);
      }
    }
    return merchantIds.toList();
  }

  static Future<List<String>> fetchDistinctCustomerIdsForMerchant(String merchantId) async {
    final invoices = await fetchInvoicesForMerchant(merchantId);
    final customerIds = <String>{};
    for (final invoice in invoices) {
      if (invoice.userId != null && invoice.userId!.isNotEmpty) {
        customerIds.add(invoice.userId!);
      }
    }
    return customerIds.toList();
  }

  /// دالة لحذف جميع العروض من Firestore (للاستخدام لمرة واحدة فقط)
  static Future<void> deleteAllOffersFromFirestore() async {
    final offers = await FirebaseFirestore.instance.collection('offers').get();
    for (var doc in offers.docs) {
      await doc.reference.delete();
    }
  }
}

class InvoiceRecord {
  final String id;
  final String? invoiceNumber;
  final String? storeName;
  final DateTime? date;
  final List<dynamic>? products;
  final double? total;
  final String? userId;
  final String? merchantId;
  final String? uniqueHash;

  InvoiceRecord({
    required this.id,
    this.invoiceNumber,
    this.storeName,
    this.date,
    this.products,
    this.total,
    this.userId,
    this.merchantId,
    this.uniqueHash,
  });

  factory InvoiceRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateValue = json['date'];
    if (dateValue is String) {
      parsedDate = DateTime.tryParse(dateValue);
    } else if (dateValue is DateTime) {
      parsedDate = dateValue;
    }

    double? parsedTotal;
    final totalValue = json['total'];
    if (totalValue is num) {
      parsedTotal = totalValue.toDouble();
    } else if (totalValue is String) {
      parsedTotal = double.tryParse(totalValue);
    }

    return InvoiceRecord(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      storeName: json['store_name']?.toString(),
      date: parsedDate,
      products: json['products'] is List ? json['products'] as List : null,
      total: parsedTotal,
      userId: json['user_id']?.toString(),
      merchantId: json['merchant_id']?.toString(),
      uniqueHash: json['unique_hash']?.toString(),
    );
  }
}
