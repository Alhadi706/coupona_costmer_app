import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/store_performance.dart';

/// Repository responsible for reading/writing store performance documents.
class StorePerformanceRepository {
  StorePerformanceRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _collection = 'brand_store_performance';

  Stream<List<StorePerformance>> watchBrandStores(String brandId) {
    return _firestore
        .collection(_collection)
        .where('brandId', isEqualTo: brandId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => StorePerformance.fromJson(doc.data())).toList());
  }

  Future<StorePerformance?> fetchStore(String brandId, String storeId) async {
    final docId = '${brandId}_$storeId';
    final doc = await _firestore.collection(_collection).doc(docId).get();
    if (!doc.exists) return null;
    return StorePerformance.fromJson(doc.data()!);
  }

  Future<void> upsertStorePerformance(StorePerformance performance) async {
    final docId = '${performance.brandId}_${performance.storeId}';
    await _firestore.collection(_collection).doc(docId).set(performance.toJson(), SetOptions(merge: true));
  }

  Future<void> appendIssue(String brandId, String storeId, String issue) {
    final docId = '${brandId}_$storeId';
    return _firestore.collection(_collection).doc(docId).update({
      'issues': FieldValue.arrayUnion([issue]),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
