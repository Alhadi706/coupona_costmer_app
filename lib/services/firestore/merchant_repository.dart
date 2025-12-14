import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/merchant.dart';

class MerchantRepository {
  MerchantRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('merchants');

  Stream<Merchant?> watchMerchant(String merchantId) {
    return _collection.doc(merchantId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return Merchant.fromDoc(snapshot);
    });
  }

  Future<Merchant?> fetchMerchant(String merchantId) async {
    final doc = await _collection.doc(merchantId).get();
    if (!doc.exists) return null;
    return Merchant.fromDoc(doc);
  }

  Future<void> upsertMerchant(Merchant merchant) {
    return _collection.doc(merchant.id).set({
      ...merchant.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': merchant.createdAt,
    }, SetOptions(merge: true));
  }

  Future<void> updateMerchantFields(String merchantId, Map<String, dynamic> data) {
    return _collection.doc(merchantId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
