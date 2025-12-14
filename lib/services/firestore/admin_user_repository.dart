import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/admin_user.dart';

class AdminUserRepository {
  AdminUserRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('users');

  Stream<List<AdminUser>> watchUsers({String? roleFilter, String? searchTerm, int limit = 50}) {
    Query<Map<String, dynamic>> query = _collection.orderBy('displayName', descending: false).limit(limit);
    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.where('role', isEqualTo: roleFilter);
    }

    final normalizedSearch = searchTerm?.trim().toLowerCase();

    return query.snapshots().map((snapshot) {
      final users = snapshot.docs.map(AdminUser.fromFirestore).toList();
      if (normalizedSearch == null || normalizedSearch.isEmpty) {
        return users;
      }
      return users
          .where((user) => user.displayName.toLowerCase().contains(normalizedSearch) || user.email.toLowerCase().contains(normalizedSearch))
          .toList();
    });
  }

  Stream<AdminUserStats> watchStats() {
    return _collection.snapshots().map((snapshot) {
      int active = 0;
      int suspended = 0;
      int needsReview = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isActive = data['isActive'] as bool? ?? true;
        final requiresReview = data['needsReview'] as bool? ?? false;
        if (requiresReview) {
          needsReview += 1;
        }
        if (isActive) {
          active += 1;
        } else {
          suspended += 1;
        }
      }
      return AdminUserStats(active: active, suspended: suspended, needsReview: needsReview);
    });
  }

  Future<void> updateUserStatus(String userId, bool isActive) {
    return _collection.doc(userId).set({'isActive': isActive}, SetOptions(merge: true));
  }

  Future<void> flagUserForReview(String userId, {required bool needsReview}) {
    return _collection.doc(userId).set({'needsReview': needsReview}, SetOptions(merge: true));
  }
}
