import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceItem {
  final String productId;
  final int quantity;
  final double price;
  final double points;
  final String? brandId;

  const InvoiceItem({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.points,
    this.brandId,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> data) {
    return InvoiceItem(
      productId: data['productId']?.toString() ?? '',
      quantity: data['quantity'] as int? ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      points: (data['points'] as num?)?.toDouble() ?? 0,
      brandId: data['brandId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'quantity': quantity,
      'price': price,
      'points': points,
      if ((brandId ?? '').isNotEmpty) 'brandId': brandId,
    };
  }
}

class Invoice {
  final String id;
  final String merchantId;
  final String customerId;
  final String? merchantCode;
  final String invoiceNumber;
  final double totalAmount;
  final List<InvoiceItem> items;
  final String status;
  final String? ocrText;
  final Timestamp createdAt;

  const Invoice({
    required this.id,
    required this.merchantId,
    required this.customerId,
    required this.invoiceNumber,
    this.merchantCode,
    required this.totalAmount,
    required this.items,
    required this.status,
    this.ocrText,
    required this.createdAt,
  });

  factory Invoice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>? ?? const [])
        .map((item) => InvoiceItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    return Invoice(
      id: doc.id,
      merchantId: data['merchantId']?.toString() ?? '',
      customerId: data['customerId']?.toString() ?? '',
      merchantCode: data['merchantCode']?.toString(),
      invoiceNumber: data['invoiceNumber']?.toString() ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      items: rawItems,
      status: data['status']?.toString() ?? 'pending',
      ocrText: data['ocrText']?.toString(),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
  }
}
