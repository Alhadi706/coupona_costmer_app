class Product {
  final String id;
  final String merchantId;
  final String name;
  final String? description;
  final double price;
  final String category;
  final String? brandId;
  final double pointsPerUnit;
  final bool isActive;

  const Product({
    required this.id,
    required this.merchantId,
    required this.name,
    this.description,
    required this.price,
    required this.category,
    this.brandId,
    required this.pointsPerUnit,
    required this.isActive,
  });

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      merchantId: data['merchantId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      category: data['category']?.toString() ?? '',
      brandId: data['brandId']?.toString(),
      pointsPerUnit: (data['pointsPerUnit'] as num?)?.toDouble() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      'category': category,
      if (brandId != null) 'brandId': brandId,
      'pointsPerUnit': pointsPerUnit,
      'isActive': isActive,
    };
  }
}
