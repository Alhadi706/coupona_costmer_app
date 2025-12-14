class Cashier {
  final String id;
  final String merchantId;
  final String userId;
  final List<String> permissions;
  final bool isActive;

  const Cashier({
    required this.id,
    required this.merchantId,
    required this.userId,
    required this.permissions,
    required this.isActive,
  });

  factory Cashier.fromMap(String id, Map<String, dynamic> data) {
    return Cashier(
      id: id,
      merchantId: data['merchantId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      permissions: List<String>.from(data['permissions'] ?? const []),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'userId': userId,
      'permissions': permissions,
      'isActive': isActive,
    };
  }
}
