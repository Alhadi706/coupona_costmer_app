import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  final String id;
  final String merchantId;
  final String title;
  final String description;
  final String type;
  final int requiredPoints;
  final Timestamp startDate;
  final Timestamp endDate;
  final bool isActive;
  final int claimedCount;
  final String ownerType;
  final String ownerName;
  final String? brandId;
  final String? imageUrl;

  const Reward({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.description,
    required this.type,
    required this.requiredPoints,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.claimedCount,
    this.ownerType = 'merchant',
    this.ownerName = '',
    this.brandId,
    this.imageUrl,
  });

  factory Reward.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final explicitOwnerType = data['ownerType']?.toString();
    final inferredType = data['type']?.toString();
    final resolvedOwnerType = (explicitOwnerType != null && explicitOwnerType.isNotEmpty)
        ? explicitOwnerType
        : inferredType == 'brand'
            ? 'brand'
            : 'merchant';
    return Reward(
      id: doc.id,
      merchantId: data['merchantId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      type: data['type']?.toString() ?? 'discount',
      requiredPoints: data['requiredPoints'] as int? ?? 0,
      startDate: data['startDate'] is Timestamp ? data['startDate'] as Timestamp : Timestamp.now(),
      endDate: data['endDate'] is Timestamp ? data['endDate'] as Timestamp : Timestamp.now(),
      isActive: data['isActive'] as bool? ?? true,
      claimedCount: data['claimedCount'] as int? ?? 0,
      ownerType: resolvedOwnerType,
      ownerName: data['ownerName']?.toString() ?? '',
      brandId: data['brandId']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'title': title,
      'description': description,
      'type': type,
      'requiredPoints': requiredPoints,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
      'claimedCount': claimedCount,
      'ownerType': ownerType,
      'ownerName': ownerName,
      if ((brandId ?? '').isNotEmpty) 'brandId': brandId,
      if ((imageUrl ?? '').isNotEmpty) 'imageUrl': imageUrl,
    };
  }
}
