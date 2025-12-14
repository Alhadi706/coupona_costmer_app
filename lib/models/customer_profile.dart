class CustomerProfile {
  final String id;
  final String name;
  final String phone;
  final int? age;
  final String gender;
  final double totalPoints;
  final Map<String, num> merchantPoints;
  final Map<String, num> brandPoints;

  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.age,
    this.gender = '',
    required this.totalPoints,
    required this.merchantPoints,
    this.brandPoints = const <String, num>{},
  });

  factory CustomerProfile.fromMap(String id, Map<String, dynamic> data) {
    return CustomerProfile(
      id: id,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      age: (data['age'] as num?)?.toInt(),
      gender: data['gender']?.toString() ?? '',
      totalPoints: (data['totalPoints'] as num?)?.toDouble() ?? 0,
      merchantPoints: Map<String, num>.from(data['merchantPoints'] ?? const {}),
      brandPoints: Map<String, num>.from(data['brandPoints'] ?? const {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (age != null) 'age': age,
      if (gender.isNotEmpty) 'gender': gender,
      'totalPoints': totalPoints,
      'merchantPoints': merchantPoints,
      'brandPoints': brandPoints,
    };
  }
}
