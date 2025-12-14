import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/discover_feed.dart';

class DiscoverFeedRepository {
  DiscoverFeedRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<DiscoverFeedBundle> watchFeed({required DiscoverFeedFilter filter, int limit = 20}) async* {
    final query = _buildPostsQuery(filter, limit);
    await for (final snapshot in query.snapshots()) {
      final posts = snapshot.docs.map(DiscoverFeedPost.fromDoc).toList();
      final spotlights = await _loadSpotlights(limit: 5);
      final offers = await _loadExclusiveOffers(limit: 3, categories: filter.categories);
      yield DiscoverFeedBundle(posts: posts, spotlights: spotlights, exclusiveOffers: offers);
    }
  }

  Query<Map<String, dynamic>> _buildPostsQuery(DiscoverFeedFilter filter, int limit) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('community_posts')
        .where('status', isEqualTo: 'published');

    if (filter.categories.isNotEmpty) {
      query = query.where('categories', arrayContainsAny: filter.categories);
    }

    if (filter.preferredMerchantIds.isNotEmpty) {
      query = query.where('merchantId', whereIn: filter.preferredMerchantIds.take(10).toList());
    }

    if (filter.query != null && filter.query!.isNotEmpty) {
      query = query.where('keywords', arrayContains: filter.query!.toLowerCase());
    }

    return query.orderBy('createdAt', descending: true).limit(limit);
  }

  Future<List<MerchantSpotlight>> _loadSpotlights({required int limit}) async {
    try {
      final snapshot = await _firestore
          .collection('merchantSpotlights')
          .orderBy('priority', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(MerchantSpotlight.fromDoc).toList();
    } on FirebaseException {
      return const [];
    }
  }

  Future<List<ExclusiveOffer>> _loadExclusiveOffers({required int limit, required List<String> categories}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('offers')
          .where('isCommunityExclusive', isEqualTo: true)
          .orderBy('endDate')
          .limit(limit);

      if (categories.isNotEmpty) {
        query = query.where('categories', arrayContainsAny: categories);
      }

      final snapshot = await query.get();
      return snapshot.docs.map(ExclusiveOffer.fromDoc).toList();
    } on FirebaseException {
      return const [];
    }
  }
}
