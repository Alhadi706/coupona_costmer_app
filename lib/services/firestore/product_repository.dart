import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/product.dart';

class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('products');

  Stream<List<Product>> watchProducts(String merchantId) {
    return _collection.where('merchantId', isEqualTo: merchantId).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<List<Product>> fetchProducts(String merchantId) async {
    final snap = await _collection.where('merchantId', isEqualTo: merchantId).get();
    return snap.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> saveProduct(Product product) {
    return _collection.doc(product.id).set(product.toMap(), SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>> addProduct(Product product) {
    return _collection.add(product.toMap());
  }

  Future<void> deleteProduct(String productId) => _collection.doc(productId).delete();
}
