import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MerchantCustomerRoomRepository {
  MerchantCustomerRoomRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('merchantCustomerRooms');

  Future<void> ensureRoomExists({
    required String merchantId,
    required String customerId,
  }) async {
    final docId = '${merchantId}_$customerId';
    final docRef = _collection.doc(docId);

    String? merchantName;
    String? merchantLogo;
    String? customerName;
    String? customerAvatar;
    try {
      final merchantDoc = await _firestore.collection('merchants').doc(merchantId).get();
      final data = merchantDoc.data();
      if (data != null) {
        merchantName = data['name']?.toString();
        merchantLogo = data['logoUrl']?.toString();
      }
    } catch (error, stackTrace) {
      debugPrint('merchant room lookup failed for $merchantId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final customerDoc = await _firestore.collection('customers').doc(customerId).get();
      final data = customerDoc.data();
      if (data != null) {
        customerName = data['name']?.toString();
        customerAvatar = data['photoUrl']?.toString();
      }
    } catch (error, stackTrace) {
      debugPrint('customer room lookup failed for $customerId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _firestore.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      final hasName = (merchantName ?? '').isNotEmpty;
      final hasLogo = (merchantLogo ?? '').isNotEmpty;
      final hasCustomerName = (customerName ?? '').isNotEmpty;
      final hasCustomerAvatar = (customerAvatar ?? '').isNotEmpty;
      if (snapshot.exists) {
        txn.update(docRef, {
          'merchantId': merchantId,
          'customerId': customerId,
          'members': FieldValue.arrayUnion([merchantId, customerId]),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastInvoiceAt': FieldValue.serverTimestamp(),
          if (hasName) 'merchantName': merchantName,
          if (hasLogo) 'merchantLogo': merchantLogo,
          if (hasCustomerName) 'customerName': customerName,
          if (hasCustomerAvatar) 'customerAvatar': customerAvatar,
        });
      } else {
        txn.set(docRef, {
          'merchantId': merchantId,
          'customerId': customerId,
          if (hasName) 'merchantName': merchantName,
          if (hasLogo) 'merchantLogo': merchantLogo,
          if (hasCustomerName) 'customerName': customerName,
          if (hasCustomerAvatar) 'customerAvatar': customerAvatar,
          'members': [merchantId, customerId],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastInvoiceAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
