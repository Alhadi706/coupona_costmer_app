import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/customer_profile.dart';

class CustomerRepository {
  CustomerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('customers');

  Future<CustomerProfile?> fetchCustomer(String customerId) async {
    final doc = await _collection.doc(customerId).get();
    if (!doc.exists) return null;
    return CustomerProfile.fromMap(doc.id, doc.data()!);
  }

  Stream<CustomerProfile?> watchCustomer(String customerId) {
    return _collection.doc(customerId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CustomerProfile.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  Stream<List<CustomerProfile>> searchCustomersByPhone(String query) {
    return _collection
        .where('phone', isGreaterThanOrEqualTo: query)
        .where('phone', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CustomerProfile.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<CustomerProfile>> watchCustomersForMerchant(
    String merchantId, {
    int limit = 50,
  }) {
    final fieldPath = FieldPath(['merchantPoints', merchantId]);
    return _collection
        .where(fieldPath, isGreaterThan: 0)
        .orderBy(fieldPath, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CustomerProfile.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> incrementPoints({
    required String customerId,
    required String merchantId,
    required double points,
    Map<String, double> brandPointBreakdown = const <String, double>{},
    String source = 'transaction',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final docRef = _collection.doc(customerId);
    final newBalance = await _firestore.runTransaction<double>((txn) async {
      final doc = await txn.get(docRef);
      final Map<String, dynamic> data = doc.exists
          ? (doc.data() ?? <String, dynamic>{})
          : <String, dynamic>{};
      final totalPoints =
          (data['totalPoints'] as num? ?? 0).toDouble() + points;
      final merchantPoints = Map<String, num>.from(
        data['merchantPoints'] ?? <String, num>{},
      );
      merchantPoints[merchantId] =
          (merchantPoints[merchantId]?.toDouble() ?? 0) + points;
      final brandPoints = Map<String, num>.from(
        data['brandPoints'] ?? <String, num>{},
      );
      brandPointBreakdown.forEach((brandId, delta) {
        if (delta == 0) return;
        brandPoints[brandId] = (brandPoints[brandId]?.toDouble() ?? 0) + delta;
      });
      txn.set(docRef, {
        'totalPoints': totalPoints,
        'merchantPoints': merchantPoints,
        'brandPoints': brandPoints,
      }, SetOptions(merge: true));
      return totalPoints;
    });

    final historyMetadata = <String, dynamic>{};
    metadata.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      historyMetadata[key] = value;
    });

    await docRef.collection('pointsHistory').add({
      'amount': points,
      'balance': newBalance,
      'merchantId': merchantId,
      'source': source,
      'direction': points >= 0 ? 'credit' : 'debit',
      'createdAt': FieldValue.serverTimestamp(),
      if (historyMetadata.isNotEmpty) 'metadata': historyMetadata,
    });
  }
}
