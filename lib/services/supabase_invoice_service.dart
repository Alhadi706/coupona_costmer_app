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
    String? merchantCode,
  }) async {
    final data = {
      'invoice_number': invoiceNumber,
      'store_name': storeName,
      'date': date.toIso8601String(),
      'products': products,
      'total': total,
      'user_id': userId,
      'merchant_id': merchantId,
      'unique_hash': uniqueHash,
      if (merchantCode != null && merchantCode.isNotEmpty) 'merchant_code': merchantCode,
    };
    try {
      await SupabaseService.client.from('invoices').insert(data);
    } catch (e) {
      // إذا الجدول لا يحتوي العمود الجديد تجاهل الخطأ المتعلق بالحقل فقط
      if (e.toString().contains('merchant_code')) {
        final fallback = Map<String, dynamic>.from(data)..remove('merchant_code');
        await SupabaseService.client.from('invoices').insert(fallback);
      } else {
        rethrow;
      }
    }
  }

  /// دالة لحذف جميع العروض من Firestore (للاستخدام لمرة واحدة فقط)
  static Future<void> deleteAllOffersFromFirestore() async {
    final offers = await FirebaseFirestore.instance.collection('offers').get();
    for (var doc in offers.docs) {
      await doc.reference.delete();
    }
  }
}
