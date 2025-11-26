import 'supabase_service.dart';

class UserMerchantLinkService {
  static Future<void> linkInvoice(String merchantUuid, Map<String, dynamic> payload) async {
    final client = SupabaseService.client;
    await client.rpc('process_and_link_scanned_invoice', params: {
      'merchant_uuid': merchantUuid,
      'invoice_payload': payload,
    });
  }
}
