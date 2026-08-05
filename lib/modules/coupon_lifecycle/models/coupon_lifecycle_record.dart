import '../coupon_lifecycle_rules.dart';

class CouponLifecycleRecord {
  const CouponLifecycleRecord({
    required this.offerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastReason,
    this.redeemedAt,
    this.archivedAt,
  });

  final String offerId;
  final CouponLifecycleStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastReason;
  final DateTime? redeemedAt;
  final DateTime? archivedAt;

  factory CouponLifecycleRecord.fromMap({
    required String offerId,
    required Map<String, dynamic> map,
  }) {
    return CouponLifecycleRecord(
      offerId: offerId,
      status: CouponLifecycleRules.parseStatus(map['lifecycleStatus'] as String?),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      updatedAt: DateTime.tryParse((map['lifecycleUpdatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      lastReason: map['lifecycleReason'] as String?,
      redeemedAt: DateTime.tryParse((map['redeemedAt'] ?? '').toString()),
      archivedAt: DateTime.tryParse((map['archivedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lifecycleStatus': CouponLifecycleRules.toStorageValue(status),
      'lifecycleUpdatedAt': updatedAt.toUtc().toIso8601String(),
      'lifecycleReason': lastReason,
      'redeemedAt': redeemedAt?.toUtc().toIso8601String(),
      'archivedAt': archivedAt?.toUtc().toIso8601String(),
    };
  }
}
