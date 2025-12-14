import 'package:cloud_firestore/cloud_firestore.dart';

class BrandCommunityPost {
  final String id;
  final String type;
  final String content;
  final Timestamp createdAt;

  const BrandCommunityPost({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  factory BrandCommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BrandCommunityPost(
      id: doc.id,
      type: data['type']?.toString() ?? 'post',
      content: data['content']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
    );
  }
}
