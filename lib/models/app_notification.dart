import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final Timestamp createdAt;
  final Map<String, dynamic> metadata;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: data['type']?.toString() ?? 'generic',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
      metadata: data['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['metadata'] as Map<String, dynamic>)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
