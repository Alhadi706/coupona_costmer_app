import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/cashier.dart';

class CashierRepository {
  CashierRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('cashiers');

  Stream<List<Cashier>> watchCashiers(String merchantId) {
    return _collection
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Cashier.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> saveCashier(Cashier cashier) {
    return _collection.doc(cashier.id).set(cashier.toMap(), SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>> addCashier(Cashier cashier) {
    return _collection.add(cashier.toMap());
  }

  Future<void> deactivateCashier(String cashierId) {
    return _collection.doc(cashierId).update({'isActive': false});
  }
}
