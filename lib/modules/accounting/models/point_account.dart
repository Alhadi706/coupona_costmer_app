class PointAccount {
  PointAccount({
    required this.ownerId,
    required this.availablePoints,
    required this.lifetimePoints,
    required this.updatedAt,
  });

  final String ownerId;
  final int availablePoints;
  final int lifetimePoints;
  final DateTime updatedAt;

  factory PointAccount.fromMap(Map<String, dynamic> map) {
    return PointAccount(
      ownerId: map['ownerId'] as String? ?? '',
      availablePoints: (map['availablePoints'] as num?)?.toInt() ?? 0,
      lifetimePoints: (map['lifetimePoints'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'availablePoints': availablePoints,
      'lifetimePoints': lifetimePoints,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
