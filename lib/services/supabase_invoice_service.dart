import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    await SupabaseService.client.from('invoices').insert({
      'invoice_number': invoiceNumber,
      'store_name': storeName,
      'date': date.toIso8601String(),
      'products': products,
      'total': total,
      'user_id': userId,
      'merchant_id': merchantId,
      'unique_hash': uniqueHash,
    });
  }

  /// دالة لحذف جميع العروض من Firestore (للاستخدام لمرة واحدة فقط)
  static Future<void> deleteAllOffersFromFirestore() async {
    final offers = await FirebaseFirestore.instance.collection('offers').get();
    for (var doc in offers.docs) {
      await doc.reference.delete();
    }
  }
}
