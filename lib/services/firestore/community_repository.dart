import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/community.dart';

class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('communities');

  Future<DocumentReference<Map<String, dynamic>>> createRoom({
    required String merchantId,
    required String name,
    String? description,
    List<String>? initialMembers,
  }) {
    final members = <String>[];
    if (initialMembers != null) {
      members.addAll(initialMembers.where((member) => member.isNotEmpty));
    }
    if (!members.contains(merchantId)) {
      members.add(merchantId);
    }

    return _collection.add({
      'merchantId': merchantId,
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addMemberToMerchantRooms({
    required String merchantId,
    required String memberId,
  }) async {
    if (merchantId.isEmpty || memberId.isEmpty) return;
    try {
      final snapshot = await _collection
          .where('merchantId', isEqualTo: merchantId)
          .get();
      if (snapshot.docs.isEmpty) return;
      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'members': FieldValue.arrayUnion([memberId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('addMemberToMerchantRooms failed: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('addMemberToMerchantRooms unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> addMembers({
    required String communityId,
    required List<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;
    const chunkSize = 250;
    final docRef = _collection.doc(communityId);
    for (var i = 0; i < memberIds.length; i += chunkSize) {
      final chunk = memberIds.sublist(
        i,
        i + chunkSize > memberIds.length ? memberIds.length : i + chunkSize,
      );
      await docRef.update({
        'members': FieldValue.arrayUnion(chunk),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<List<CommunityRoom>> watchRooms(String merchantId) {
    return _collection
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityRoom.fromDoc).toList());
  }

  Stream<List<CommunityMessage>> watchMessages(String communityId) {
    return _collection
        .doc(communityId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String communityId,
    required String senderId,
    required String body,
    String? parentMessageId,
    List<String>? privateRecipients,
  }) {
    final payload = <String, dynamic>{
      'senderId': senderId,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (parentMessageId != null && parentMessageId.isNotEmpty) {
      payload['parentMessageId'] = parentMessageId;
    }
    if (privateRecipients != null && privateRecipients.isNotEmpty) {
      payload['privateRecipients'] = privateRecipients;
    }
    return _collection.doc(communityId).collection('messages').add(payload);
  }
}
