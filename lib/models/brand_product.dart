import 'package:cloud_firestore/cloud_firestore.dart';

class BrandProduct {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final int salesCount;
  final double averageRating;
  final int pointsPerUnit;

  const BrandProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.salesCount,
    required this.averageRating,
    required this.pointsPerUnit,
  });

  factory BrandProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BrandProduct(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl']?.toString(),
      salesCount: (data['salesCount'] as num?)?.toInt() ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0,
      pointsPerUnit: (data['pointsPerUnit'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      'salesCount': salesCount,
      'averageRating': averageRating,
      'pointsPerUnit': pointsPerUnit,
    };
  }
}
