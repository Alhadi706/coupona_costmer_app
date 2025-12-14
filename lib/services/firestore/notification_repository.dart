import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('notifications');

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots().map(
      (snap) {
        final notifications = snap.docs.map(AppNotification.fromDoc).toList();
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notifications;
      },
    );
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'generic',
    Map<String, dynamic>? metadata,
    String? createdByUserId,
  }) {
    final senderId = createdByUserId ?? _auth.currentUser?.uid;
    if (senderId == null) {
      throw StateError('Cannot create notification without an authenticated sender.');
    }
    return _collection.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': senderId,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  Future<void> markAsRead(String notificationId) {
    return _collection.doc(notificationId).update({'isRead': true});
  }
}
