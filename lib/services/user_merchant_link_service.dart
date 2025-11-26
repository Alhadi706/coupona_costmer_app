	import 'package:cloud_firestore/cloud_firestore.dart';
	import 'firebase_service.dart';

	/// Utilities for maintaining relationships between merchants and customers
	/// using Firestore as the backing store.
	class UserMerchantLinkService {
	  /// Persist a scanned invoice into Firestore and return a simple status message.
	  static Future<String> sendDataToLinkAgent({
	    required String merchantUuid,
	    required Map<String, dynamic> invoicePayload,
	  }) async {
	    final cleanPayload = Map<String, dynamic>.from(invoicePayload)
	      ..removeWhere((key, value) => value == null);

	    try {
	      await FirebaseService.firestore.collection('invoices').add({
	        'merchant_uuid': merchantUuid,
	        'invoice_payload': cleanPayload,
	        'createdAt': DateTime.now().toIso8601String(),
	      });
	      return 'invoice_link_success';
	    } catch (e) {
	      return 'invoice_link_failed';
	    }
	  }

	  static Future<List<String>> fetchDistinctCustomerIdsForMerchant(String merchantId) async {
	    final snapshot = await FirebaseService.firestore
	        .collection('invoices')
	        .where('merchant_id', isEqualTo: merchantId)
	        .get();
	    final ids = <String>{};
	    for (final doc in snapshot.docs) {
	      final userId = (doc.data() as Map<String, dynamic>)['user_id'];
	      if (userId is String && userId.isNotEmpty) ids.add(userId);
	    }
	    return ids.toList();
	  }

	  static Future<List<String>> fetchDistinctMerchantIdsForUser(String userId) async {
	    final snapshot = await FirebaseService.firestore
	        .collection('invoices')
	        .where('user_id', isEqualTo: userId)
	        .get();
	    final ids = <String>{};
	    for (final doc in snapshot.docs) {
	      final merchantId = (doc.data() as Map<String, dynamic>)['merchant_id'];
	      if (merchantId is String && merchantId.isNotEmpty) ids.add(merchantId);
	    }
	    return ids.toList();
	  }

	  static Future<List<Map<String, dynamic>>> fetchMerchantsByIds(List<String> merchantIds,
	      {String collectionName = 'merchants'}) async {
	    if (merchantIds.isEmpty) return [];
	    final results = <Map<String, dynamic>>[];
	    for (final id in merchantIds) {
	      final doc = await FirebaseService.firestore.collection(collectionName).doc(id).get();
	      if (doc.exists) {
	        final map = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
	        map['id'] = doc.id;
	        results.add(map);
	      }
	    }
	    return results;
	  }

	  static Future<List<Map<String, dynamic>>> fetchCustomerProfiles(List<String> customerIds,
	      {String collectionName = 'profiles'}) async {
	    if (customerIds.isEmpty) return [];
	    final results = <Map<String, dynamic>>[];
	    for (final id in customerIds) {
	      final doc = await FirebaseService.firestore.collection(collectionName).doc(id).get();
	      if (doc.exists) {
	        final map = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
	        map['id'] = doc.id;
	        results.add(map);
	      }
	    }
	    return results;
	  }
	}
