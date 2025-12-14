import 'package:cloud_firestore/cloud_firestore.dart';

class RewardRedemption {
  final String id;
  final String merchantId;
  final String merchantName;
  final String rewardId;
  final String rewardTitle;
  final int requiredPoints;
  final String customerId;
  final String customerName;
  final String status;
  final String redeemCode;
  final Timestamp createdAt;
  final Timestamp? expiresAt;
  final Timestamp? completedAt;
  final Timestamp? cancelledAt;
  final String? cashierId;

  const RewardRedemption({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.rewardId,
    required this.rewardTitle,
    required this.requiredPoints,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.redeemCode,
    required this.createdAt,
    this.expiresAt,
    this.completedAt,
    this.cancelledAt,
    this.cashierId,
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory RewardRedemption.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RewardRedemption(
      id: doc.id,
      merchantId: data['merchantId']?.toString() ?? '',
      merchantName: data['merchantName']?.toString() ?? '',
      rewardId: data['rewardId']?.toString() ?? '',
      rewardTitle: data['rewardTitle']?.toString() ?? '',
      requiredPoints: (data['requiredPoints'] as num?)?.toInt() ?? 0,
      customerId: data['customerId']?.toString() ?? '',
      customerName: data['customerName']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      redeemCode: data['redeemCode']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      expiresAt: data['expiresAt'] is Timestamp
          ? data['expiresAt'] as Timestamp
          : null,
      completedAt: data['completedAt'] is Timestamp
          ? data['completedAt'] as Timestamp
          : null,
      cancelledAt: data['cancelledAt'] is Timestamp
          ? data['cancelledAt'] as Timestamp
          : null,
      cashierId: data['cashierId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'merchantId': merchantId,
      'merchantName': merchantName,
      'rewardId': rewardId,
      'rewardTitle': rewardTitle,
      'requiredPoints': requiredPoints,
      'customerId': customerId,
      'customerName': customerName,
      'status': status,
      'redeemCode': redeemCode,
      'createdAt': createdAt,
      if (expiresAt != null) 'expiresAt': expiresAt,
      if (completedAt != null) 'completedAt': completedAt,
      if (cancelledAt != null) 'cancelledAt': cancelledAt,
      if ((cashierId ?? '').isNotEmpty) 'cashierId': cashierId,
    };
  }
}
