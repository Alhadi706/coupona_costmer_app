import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/community.dart';

/// Helper methods to resolve which merchant community rooms a customer can access.
class MerchantCommunityService {
	MerchantCommunityService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

	final FirebaseFirestore _firestore;

	/// Returns every community room that belongs to merchants the user interacted with.
	Future<List<CommunityRoom>> fetchAvailableRooms(String userId) async {
		try {
			final merchantSnapshot = await _firestore
					.collection('merchantCustomerRooms')
					.where('members', arrayContains: userId)
					.get();

			final merchantIds = <String>{};
			for (final doc in merchantSnapshot.docs) {
				final data = doc.data();
				final merchantId = data['merchantId']?.toString();
				if (merchantId != null && merchantId.isNotEmpty) {
					merchantIds.add(merchantId);
				}
			}

			if (merchantIds.isEmpty) {
				return const [];
			}

			final rooms = <CommunityRoom>[];
			final merchantsList = merchantIds.toList();
			const chunkSize = 10; // Firestore whereIn limit.
			for (var i = 0; i < merchantsList.length; i += chunkSize) {
				final chunk = merchantsList.sublist(i, i + chunkSize > merchantsList.length ? merchantsList.length : i + chunkSize);
				final snapshot = await _firestore
						.collection('communities')
						.where('merchantId', whereIn: chunk)
						.get();
				rooms.addAll(snapshot.docs.map(CommunityRoom.fromDoc));
			}

			// Remove duplicates in case the same merchant has multiple rooms queried in different chunks.
			final deduped = <String, CommunityRoom>{
				for (final room in rooms) room.id: room,
			};
			return deduped.values.toList();
		} on FirebaseException catch (error) {
			debugPrint('fetchAvailableRooms failed: ${error.message}');
			return const [];
		} catch (error) {
			debugPrint('fetchAvailableRooms unexpected error: $error');
			return const [];
		}
	}
}
