import 'package:cloud_firestore/cloud_firestore.dart';

class Brand {
  final String id;
  final String name;
  final String email;
  final String? description;
  final String? contactNumber;
  final String? logoUrl;
  final String? website;
  final int totalProducts;
  final int activeRewards;
  final int runningCampaigns;
  final int communityMembers;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.email,
    this.description,
    this.contactNumber,
    this.logoUrl,
    this.website,
    required this.totalProducts,
    required this.activeRewards,
    required this.runningCampaigns,
    required this.communityMembers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Brand.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Brand(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      description: data['description']?.toString(),
      contactNumber: data['contactNumber']?.toString(),
      logoUrl: data['logoUrl']?.toString(),
      website: data['website']?.toString(),
      totalProducts: (data['totalProducts'] as num?)?.toInt() ?? 0,
      activeRewards: (data['activeRewards'] as num?)?.toInt() ?? 0,
      runningCampaigns: (data['runningCampaigns'] as num?)?.toInt() ?? 0,
      communityMembers: (data['communityMembers'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (contactNumber != null && contactNumber!.isNotEmpty) 'contactNumber': contactNumber,
      if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
      if (website != null && website!.isNotEmpty) 'website': website,
      'totalProducts': totalProducts,
      'activeRewards': activeRewards,
      'runningCampaigns': runningCampaigns,
      'communityMembers': communityMembers,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
