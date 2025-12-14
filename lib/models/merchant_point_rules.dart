import 'package:cloud_firestore/cloud_firestore.dart';


enum MerchantPointsMode { perItem, perAmount }

class MerchantPointBoost {
  const MerchantPointBoost({required this.productId, required this.extraPoints});

  final String productId;
  final double extraPoints;

  factory MerchantPointBoost.fromMap(Map<String, dynamic> data) {
    return MerchantPointBoost(
      productId: data['productId']?.toString() ?? '',
      extraPoints: (data['extraPoints'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'extraPoints': extraPoints,
    };
  }
}


class MerchantPointRules {
  const MerchantPointRules({
    this.enablePerItem = true,
    this.enablePerAmount = false,
    this.enableBoosts = false,
    required this.pointsPerItem,
    required this.amountStep,
    required this.pointsPerAmountStep,
    required this.boosts,
    required this.updatedAt,
  });

  final bool enablePerItem;
  final bool enablePerAmount;
  final bool enableBoosts;
  final double pointsPerItem;
  final double amountStep;
  final double pointsPerAmountStep;
  final List<MerchantPointBoost> boosts;
  final Timestamp? updatedAt;

  factory MerchantPointRules.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final boosts = (data['boosts'] as List<dynamic>? ?? const [])
        .map((entry) => MerchantPointBoost.fromMap(Map<String, dynamic>.from(entry as Map)))
        .where((boost) => boost.productId.isNotEmpty)
        .toList();
    // Backward compatibility: if enable* fields are missing, infer from mode/boosts
    final mode = (data['mode']?.toString() ?? 'per_item');
    final enablePerItem = data.containsKey('enablePerItem') ? data['enablePerItem'] == true : mode == 'per_item';
    final enablePerAmount = data.containsKey('enablePerAmount') ? data['enablePerAmount'] == true : mode == 'per_amount';
    final enableBoosts = data.containsKey('enableBoosts') ? data['enableBoosts'] == true : (boosts.isNotEmpty);
    return MerchantPointRules(
      enablePerItem: enablePerItem,
      enablePerAmount: enablePerAmount,
      enableBoosts: enableBoosts,
      pointsPerItem: (data['pointsPerItem'] as num?)?.toDouble() ?? 1,
      amountStep: (data['amountStep'] as num?)?.toDouble() ?? 10,
      pointsPerAmountStep: (data['pointsPerAmountStep'] as num?)?.toDouble() ?? 1,
      boosts: boosts,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enablePerItem': enablePerItem,
      'enablePerAmount': enablePerAmount,
      'enableBoosts': enableBoosts,
      'pointsPerItem': pointsPerItem,
      'amountStep': amountStep,
      'pointsPerAmountStep': pointsPerAmountStep,
      'boosts': boosts.map((e) => e.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MerchantPointRules copyWith({
    bool? enablePerItem,
    bool? enablePerAmount,
    bool? enableBoosts,
    double? pointsPerItem,
    double? amountStep,
    double? pointsPerAmountStep,
    List<MerchantPointBoost>? boosts,
  }) {
    return MerchantPointRules(
      enablePerItem: enablePerItem ?? this.enablePerItem,
      enablePerAmount: enablePerAmount ?? this.enablePerAmount,
      enableBoosts: enableBoosts ?? this.enableBoosts,
      pointsPerItem: pointsPerItem ?? this.pointsPerItem,
      amountStep: amountStep ?? this.amountStep,
      pointsPerAmountStep: pointsPerAmountStep ?? this.pointsPerAmountStep,
      boosts: boosts ?? this.boosts,
      updatedAt: updatedAt,
    );
  }
}

MerchantPointRules defaultMerchantPointRules() {
  return const MerchantPointRules(
    enablePerItem: true,
    enablePerAmount: false,
    enableBoosts: false,
    pointsPerItem: 1,
    amountStep: 10,
    pointsPerAmountStep: 1,
    boosts: <MerchantPointBoost>[],
    updatedAt: null,
  );
}
