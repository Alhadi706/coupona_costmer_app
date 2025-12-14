import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.lastActive,
    required this.totalPoints,
  });

  final String id;
  final String displayName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final double totalPoints;

  String get displayRole => switch (role) {
        'customer' => 'زبون',
        'merchant' => 'تاجر',
        'brand' => 'علامة',
        'admin' => 'مسؤول',
        _ => role,
      };

  factory AdminUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final dynamic created = data['createdAt'];
    // createdAt historically stored as ISO string, so handle both cases.
    DateTime? createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created);
    }
    final dynamic lastSeen = data['lastActive'];
    DateTime? lastActive;
    if (lastSeen is Timestamp) {
      lastActive = lastSeen.toDate();
    } else if (lastSeen is String) {
      lastActive = DateTime.tryParse(lastSeen);
    }

    return AdminUser(
      id: doc.id,
      displayName: data['displayName']?.toString().trim().isNotEmpty == true
          ? data['displayName'].toString()
          : data['name']?.toString() ?? 'مستخدم بدون اسم',
      email: data['email']?.toString() ?? '',
      role: data['role']?.toString() ?? 'customer',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: createdAt,
      lastActive: lastActive,
      totalPoints: (data['totalPoints'] as num?)?.toDouble() ?? 0,
    );
  }

  AdminUser copyWith({double? totalPoints, bool? isActive}) {
    return AdminUser(
      id: id,
      displayName: displayName,
      email: email,
      role: role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastActive: lastActive,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }
}

class AdminUserStats {
  const AdminUserStats({
    required this.active,
    required this.suspended,
    required this.needsReview,
  });

  final int active;
  final int suspended;
  final int needsReview;
}
