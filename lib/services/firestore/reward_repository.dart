import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/reward.dart';

class RewardRepository {
  RewardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('rewards');

  Stream<List<Reward>> watchRewards(String merchantId, {bool onlyActive = false}) {
    Query<Map<String, dynamic>> query = _collection.where('merchantId', isEqualTo: merchantId);
    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map(Reward.fromDoc).toList());
  }

  Stream<List<Reward>> watchActiveRewards() {
    return _collection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Reward.fromDoc).toList());
  }

  Future<void> saveReward(Reward reward) {
    return _collection.doc(reward.id).set(reward.toMap(), SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>> createReward(Map<String, dynamic> data) {
    return _collection.add(data);
  }

  Future<void> deleteReward(String rewardId) => _collection.doc(rewardId).delete();
}
