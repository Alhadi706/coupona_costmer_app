import 'package:cloud_firestore/cloud_firestore.dart';

class Merchant {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? logoUrl;
  final GeoPoint? location;
  final String? merchantCode;
  final Timestamp? merchantCodeAssignedAt;
  final List<String> categories;
  final bool isActive;
  final double? pointsPerCurrency;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Merchant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.logoUrl,
    required this.location,
    required this.merchantCode,
    required this.merchantCodeAssignedAt,
    required this.categories,
    required this.isActive,
    this.pointsPerCurrency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Merchant.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Merchant(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      logoUrl: data['logoUrl']?.toString(),
      location: data['location'] is GeoPoint ? data['location'] as GeoPoint : null,
      merchantCode: data['merchantCode']?.toString(),
      merchantCodeAssignedAt: data['merchantCodeAssignedAt'] is Timestamp ? data['merchantCodeAssignedAt'] as Timestamp : null,
      categories: List<String>.from(data['categories'] ?? const []),
      isActive: data['isActive'] as bool? ?? true,
      pointsPerCurrency: (data['pointsPerCurrency'] as num?)?.toDouble(),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (location != null) 'location': location,
      if ((merchantCode ?? '').isNotEmpty) 'merchantCode': merchantCode,
      if (merchantCodeAssignedAt != null) 'merchantCodeAssignedAt': merchantCodeAssignedAt,
      'categories': categories,
      'isActive': isActive,
      if (pointsPerCurrency != null) 'pointsPerCurrency': pointsPerCurrency,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Merchant copyWith({
    String? name,
    String? email,
    String? phone,
    String? logoUrl,
    GeoPoint? location,
    String? merchantCode,
    Timestamp? merchantCodeAssignedAt,
    List<String>? categories,
    bool? isActive,
    double? pointsPerCurrency,
    Timestamp? updatedAt,
  }) {
    return Merchant(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      location: location ?? this.location,
      merchantCode: merchantCode ?? this.merchantCode,
      merchantCodeAssignedAt: merchantCodeAssignedAt ?? this.merchantCodeAssignedAt,
      categories: categories ?? this.categories,
      isActive: isActive ?? this.isActive,
      pointsPerCurrency: pointsPerCurrency ?? this.pointsPerCurrency,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
