import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../models/reward.dart';
import '../../models/reward_redemption.dart';

class RewardRedemptionRepository {
  RewardRedemptionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('rewardRedemptions');

  Future<RewardRedemption> createOrReuseRedemption({
    required Reward reward,
    required String merchantName,
    required String customerId,
    required String customerName,
  }) async {
    final existing = await _collection
        .where('customerId', isEqualTo: customerId)
        .where('rewardId', isEqualTo: reward.id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return RewardRedemption.fromDoc(existing.docs.first);
    }

    final redeemCode = _uuid.v4();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 30)),
    );
    final docRef = await _collection.add({
      'merchantId': reward.merchantId,
      'merchantName': merchantName,
      'rewardId': reward.id,
      'rewardTitle': reward.title,
      'requiredPoints': reward.requiredPoints,
      'customerId': customerId,
      'customerName': customerName,
      'status': 'pending',
      'redeemCode': redeemCode,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });
    final snapshot = await docRef.get();
    return RewardRedemption.fromDoc(snapshot);
  }

  Future<RewardRedemption?> fetchRedemption(String id) async {
    final snapshot = await _collection.doc(id).get();
    if (!snapshot.exists) return null;
    return RewardRedemption.fromDoc(snapshot);
  }

  Future<void> cancelRedemption({
    required String redemptionId,
    required String customerId,
  }) {
    final docRef = _collection.doc(redemptionId);
    return docRef.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': customerId,
    });
  }

  Future<void> completeRedemption({
    required RewardRedemption redemption,
    required String merchantId,
    required String cashierId,
  }) async {
    final redemptionRef = _collection.doc(redemption.id);
    final customerRef = _firestore
        .collection('customers')
        .doc(redemption.customerId);
    final rewardRef = _firestore.collection('rewards').doc(redemption.rewardId);

    await _firestore.runTransaction((txn) async {
      final redemptionSnap = await txn.get(redemptionRef);
      if (!redemptionSnap.exists) {
        throw StateError('redemption_missing');
      }
      final redemptionData = redemptionSnap.data()!;
      if (redemptionData['status'] != 'pending') {
        throw StateError('redemption_not_pending');
      }
      if (redemptionData['merchantId'] != merchantId) {
        throw StateError('unauthorized');
      }
      final expiresAt = redemptionData['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        throw StateError('redemption_expired');
      }

      final customerSnap = await txn.get(customerRef);
      if (!customerSnap.exists) {
        throw StateError('customer_missing');
      }
      final customerData = Map<String, dynamic>.from(customerSnap.data()!);
      final merchantPoints = Map<String, num>.from(
        customerData['merchantPoints'] ?? <String, num>{},
      );
      final totalPoints =
          (customerData['totalPoints'] as num?)?.toDouble() ?? 0;
      final currentBalance = merchantPoints[merchantId]?.toDouble() ?? 0;
      if (currentBalance < redemption.requiredPoints) {
        throw StateError('insufficient_points');
      }
      final newBalance = currentBalance - redemption.requiredPoints;
      merchantPoints[merchantId] = newBalance;
      final overallBalance = (totalPoints - redemption.requiredPoints).clamp(
        0,
        double.infinity,
      );

      txn.update(customerRef, {
        'merchantPoints': merchantPoints,
        'totalPoints': overallBalance,
      });

      final historyRef = customerRef.collection('pointsHistory').doc();
      txn.set(historyRef, {
        'amount': -redemption.requiredPoints,
        'balance': overallBalance,
        'merchantId': merchantId,
        'source': 'reward_redeem',
        'direction': 'debit',
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'rewardId': redemption.rewardId,
          'rewardTitle': redemption.rewardTitle,
        },
      });

      txn.update(rewardRef, {'claimedCount': FieldValue.increment(1)});

      txn.update(redemptionRef, {
        'status': 'completed',
        'cashierId': cashierId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String buildQrPayload(RewardRedemption redemption) {
    final payload = {
      'type': 'reward_redeem',
      'id': redemption.id,
      'code': redemption.redeemCode,
      'merchantId': redemption.merchantId,
    };
    return jsonEncode(payload);
  }
}
