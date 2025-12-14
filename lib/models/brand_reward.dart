import 'package:cloud_firestore/cloud_firestore.dart';

class BrandReward {
  final String id;
  final String title;
  final int points;
  final String status;
  final Timestamp startsAt;
  final Timestamp endsAt;

  const BrandReward({
    required this.id,
    required this.title,
    required this.points,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });

  factory BrandReward.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BrandReward(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      status: data['status']?.toString() ?? 'active',
      startsAt: data['startsAt'] is Timestamp ? data['startsAt'] as Timestamp : Timestamp.now(),
      endsAt: data['endsAt'] is Timestamp ? data['endsAt'] as Timestamp : Timestamp.now(),
    );
  }
}
