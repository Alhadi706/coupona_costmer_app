import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Utilities for exploring and maintaining the bidirectional relationship
/// between merchants and customers that emerges after an invoice is scanned.
class UserMerchantLinkService {
	static final SupabaseClient _client = SupabaseService.client;

	/// Invokes the Supabase edge function / RPC responsible for persisting a
	/// scanned invoice and linking the merchant and customer together.
	///
	/// [merchantUuid] is the identifier extracted from the invoice that maps to
	/// the merchant in Supabase. [invoicePayload] contains the parsed fields
	/// (e.g. totals, raw text). The payload is sanitized to drop null values so
	/// the stored JSON stays compact.
	static Future<String> sendDataToLinkAgent({
		required String merchantUuid,
		required Map<String, dynamic> invoicePayload,
	}) async {
		final cleanPayload = Map<String, dynamic>.from(invoicePayload)
			..removeWhere((key, value) => value == null);

		final response = await _client.rpc('process_and_link_scanned_invoice',
				params: {
					'merchant_uuid': merchantUuid,
					'invoice_payload': cleanPayload,
				});

		if (response is Map<String, dynamic>) {
			return response['message']?.toString() ?? 'invoice_link_success';
		}

		if (response is String && response.isNotEmpty) {
			return response;
		}

		return 'invoice_link_success';
	}

	/// Returns the unique set of customers (user IDs) that have submitted an
	/// invoice for [merchantId].
	static Future<List<String>> fetchDistinctCustomerIdsForMerchant(
			String merchantId) async {
				final result = await _client
					.from('invoices')
					.select('user_id')
					.eq('merchant_id', merchantId);

				final rows = (result as List?) ?? const [];
				final customerIds = rows
						.whereType<Map<String, dynamic>>()
						.map((row) => row['user_id'])
						.whereType<String>()
						.where((id) => id.isNotEmpty)
						.toSet();
				return customerIds.toList();
	}

	/// Returns the unique set of merchants that a given [userId] has interacted
	/// with via scanned invoices.
	static Future<List<String>> fetchDistinctMerchantIdsForUser(
			String userId) async {
				final result = await _client
					.from('invoices')
					.select('merchant_id')
					.eq('user_id', userId);

				final rows = (result as List?) ?? const [];
				final merchantIds = rows
						.whereType<Map<String, dynamic>>()
						.map((row) => row['merchant_id'])
						.whereType<String>()
						.where((id) => id.isNotEmpty)
						.toSet();
				return merchantIds.toList();
	}

	/// Convenience helper to fetch merchant records for a set of IDs so the UI
	/// can display names, logos, etc.
	static Future<List<Map<String, dynamic>>> fetchMerchantsByIds(
		List<String> merchantIds, {
		String tableName = 'merchants',
	}) async {
		if (merchantIds.isEmpty) return [];

				final builder = _client.from(tableName).select();
				final response = merchantIds.length == 1
						? await builder.eq('id', merchantIds.first)
						: await builder.or(
								merchantIds.map((id) => 'id.eq.$id').join(','),
							);

				final rows = (response as List?) ?? const [];
				return rows.whereType<Map<String, dynamic>>().toList();
	}

	/// Convenience helper to fetch customer profile records so merchants can see
	/// who interacted with them.
	static Future<List<Map<String, dynamic>>> fetchCustomerProfiles(
		List<String> customerIds, {
		String tableName = 'profiles',
	}) async {
		if (customerIds.isEmpty) return [];

				final builder = _client.from(tableName).select();
				final response = customerIds.length == 1
						? await builder.eq('id', customerIds.first)
						: await builder.or(
								customerIds.map((id) => 'id.eq.$id').join(','),
							);

				final rows = (response as List?) ?? const [];
				return rows.whereType<Map<String, dynamic>>().toList();
	}
}
