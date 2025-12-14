import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/invoice.dart';
import 'customer_repository.dart';

class InvoiceRepository {
  InvoiceRepository({
    FirebaseFirestore? firestore,
    CustomerRepository? customerRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _customerRepository =
           customerRepository ?? CustomerRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final CustomerRepository _customerRepository;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('invoices');

  Stream<List<Invoice>> watchInvoices(String merchantId) {
    return _collection
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Invoice.fromDoc).toList());
  }

  Future<List<Invoice>> fetchRecentInvoices(
    String merchantId, {
    int limit = 10,
  }) async {
    final snap = await _collection
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(Invoice.fromDoc).toList();
  }

  Future<DocumentReference<Map<String, dynamic>>> createInvoice({
    required String merchantId,
    required String customerId,
    required String invoiceNumber,
    required double totalAmount,
    required List<InvoiceItem> items,
    String status = 'pending',
    String? ocrText,
    String? merchantCode,
    double? merchantPointsOverride,
    Map<String, double> brandPointBreakdown = const <String, double>{},
  }) async {
    final createdAt = FieldValue.serverTimestamp();
    final payload = {
      'merchantId': merchantId,
      'customerId': customerId,
      if ((merchantCode ?? '').isNotEmpty) 'merchantCode': merchantCode,
      'invoiceNumber': invoiceNumber,
      'totalAmount': totalAmount,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status,
      if (ocrText != null) 'ocrText': ocrText,
      'createdAt': createdAt,
    };

    final docRef = await _collection.add(payload);

    final derivedBrandPoints = <String, double>{};
    for (final item in items) {
      final brandId = item.brandId;
      if ((brandId ?? '').isEmpty || item.points <= 0) continue;
      derivedBrandPoints[brandId!] =
          (derivedBrandPoints[brandId] ?? 0) + item.points;
    }
    final combinedBrandPoints = Map<String, double>.from(brandPointBreakdown);
    derivedBrandPoints.forEach((key, value) {
      combinedBrandPoints[key] = (combinedBrandPoints[key] ?? 0) + value;
    });

    double totalPoints = items.fold<double>(
      0,
      (acc, item) => acc + item.points,
    );
    if (merchantPointsOverride != null && merchantPointsOverride > 0) {
      totalPoints += merchantPointsOverride;
    }

    if (totalPoints > 0) {
      await _collection.doc(docRef.id).set({
        'pointsAwarded': totalPoints,
        if (combinedBrandPoints.isNotEmpty)
          'brandPointsBreakdown': combinedBrandPoints,
      }, SetOptions(merge: true));
      await _customerRepository.incrementPoints(
        customerId: customerId,
        merchantId: merchantId,
        points: totalPoints,
        brandPointBreakdown: combinedBrandPoints,
        source: 'invoice',
        metadata: {'invoiceId': docRef.id, 'invoiceNumber': invoiceNumber},
      );
    }

    return docRef;
  }

  Future<void> updateInvoiceStatus({
    required String invoiceId,
    required String status,
  }) {
    return _collection.doc(invoiceId).update({'status': status});
  }

  Stream<List<Invoice>> watchInvoicesBetween({
    required String merchantId,
    required Timestamp start,
    required Timestamp end,
  }) {
    return _collection
        .where('merchantId', isEqualTo: merchantId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Invoice.fromDoc).toList());
  }
}
