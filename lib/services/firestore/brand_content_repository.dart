import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/brand_campaign.dart';
import '../../models/brand_product.dart';
import '../../models/brand_reward.dart';
import '../../models/brand_community_post.dart';

class BrandContentRepository {
  BrandContentRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _brandDoc(String brandId, String segment) {
    return _firestore.collection('brands').doc(brandId).collection(segment);
  }

  // Products
  Stream<List<BrandProduct>> watchProducts(String brandId) {
    return _brandDoc(brandId, 'products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BrandProduct.fromDoc).toList());
  }

  Future<void> addProduct({
    required String brandId,
    required String name,
    required double price,
    required int pointsPerUnit,
    String? imageUrl,
  }) {
    return _brandDoc(brandId, 'products').add({
      'name': name,
      'price': price,
      'pointsPerUnit': pointsPerUnit,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'salesCount': 0,
      'averageRating': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct({
    required String brandId,
    required String productId,
    required Map<String, dynamic> data,
  }) {
    return _brandDoc(brandId, 'products').doc(productId).update(data);
  }

  // Rewards
  Stream<List<BrandReward>> watchRewards(String brandId) {
    return _brandDoc(brandId, 'rewards')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BrandReward.fromDoc).toList());
  }

  Future<void> addReward({
    required String brandId,
    required String title,
    required int points,
    required String status,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    return _brandDoc(brandId, 'rewards').add({
      'title': title,
      'points': points,
      'status': status,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Campaigns
  Stream<List<BrandCampaign>> watchCampaigns(String brandId) {
    return _brandDoc(brandId, 'campaigns')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BrandCampaign.fromDoc).toList());
  }

  Future<void> addCampaign({
    required String brandId,
    required String name,
    required String status,
    required double budget,
    required String goal,
  }) {
    return _brandDoc(brandId, 'campaigns').add({
      'name': name,
      'status': status,
      'budget': budget,
      'goal': goal,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Community posts
  Stream<List<BrandCommunityPost>> watchCommunityPosts(String brandId) {
    return _brandDoc(brandId, 'communityPosts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BrandCommunityPost.fromDoc).toList());
  }

  Future<void> addCommunityPost({
    required String brandId,
    required String type,
    required String content,
  }) {
    return _brandDoc(brandId, 'communityPosts').add({
      'type': type,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
