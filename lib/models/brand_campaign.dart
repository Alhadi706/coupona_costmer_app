import 'package:cloud_firestore/cloud_firestore.dart';

class BrandCampaign {
  final String id;
  final String name;
  final String status;
  final double budget;
  final String goal;
  final Timestamp createdAt;

  const BrandCampaign({
    required this.id,
    required this.name,
    required this.status,
    required this.budget,
    required this.goal,
    required this.createdAt,
  });

  factory BrandCampaign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BrandCampaign(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      budget: (data['budget'] as num?)?.toDouble() ?? 0,
      goal: data['goal']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
    );
  }
}
