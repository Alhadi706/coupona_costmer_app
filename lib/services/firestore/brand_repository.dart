import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/brand.dart';

class BrandRepository {
  BrandRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('brands');

  Stream<Brand?> watchBrand(String brandId) {
    return _collection.doc(brandId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return Brand.fromDoc(snapshot);
    });
  }

  Future<Brand?> fetchBrand(String brandId) async {
    final doc = await _collection.doc(brandId).get();
    if (!doc.exists) return null;
    return Brand.fromDoc(doc);
  }

  Future<void> upsertBrand(Brand brand) {
    return _collection.doc(brand.id).set({
      ...brand.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': brand.createdAt,
    }, SetOptions(merge: true));
  }

  Future<void> updateMetrics(String brandId, Map<String, dynamic> data) {
    return _collection.doc(brandId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementCounter(String brandId, String field, int value) {
    return _collection.doc(brandId).update({
      field: FieldValue.increment(value),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
