import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/merchant_point_rules.dart';

class MerchantPointRulesRepository {
  MerchantPointRulesRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String merchantId) {
    return _firestore.collection('merchants').doc(merchantId).collection('pointRules').doc('default');
  }

  Future<MerchantPointRules?> fetchRules(String merchantId) async {
    final doc = await _doc(merchantId).get();
    if (!doc.exists) return null;
    return MerchantPointRules.fromDoc(doc);
  }

  Stream<MerchantPointRules?> watchRules(String merchantId) {
    return _doc(merchantId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return MerchantPointRules.fromDoc(snapshot);
    });
  }

  Future<void> saveRules(String merchantId, MerchantPointRules rules) {
    return _doc(merchantId).set(rules.toMap(), SetOptions(merge: true));
  }
}
