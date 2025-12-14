import 'supabase_service.dart';

class UserMerchantLinkService {
  /// For compatibility with previous RPC-based flow, persist a simple
  /// invoice document into Firestore under `invoices` collection.
  static Future<void> linkInvoice(String merchantUuid, Map<String, dynamic> payload) async {
    final clean = Map<String, dynamic>.from(payload)..removeWhere((k, v) => v == null);
    await SupabaseService.firestore.collection('invoices').add({
      'merchant_uuid': merchantUuid,
      'invoice_payload': clean,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
