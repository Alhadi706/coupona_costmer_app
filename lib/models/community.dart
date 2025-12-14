import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityRoom {
  final String id;
  final String merchantId;
  final String name;
  final String? description;
  final List<String> members;

  const CommunityRoom({
    required this.id,
    required this.merchantId,
    required this.name,
    this.description,
    required this.members,
  });

  factory CommunityRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CommunityRoom(
      id: doc.id,
      merchantId: data['merchantId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString(),
      members: List<String>.from(data['members'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'name': name,
      if (description != null) 'description': description,
      'members': members,
    };
  }
}

class CommunityMessage {
  final String id;
  final String senderId;
  final String body;
  final Timestamp createdAt;

  const CommunityMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory CommunityMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CommunityMessage(
      id: doc.id,
      senderId: data['senderId']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'body': body,
      'createdAt': createdAt,
    };
  }
}
