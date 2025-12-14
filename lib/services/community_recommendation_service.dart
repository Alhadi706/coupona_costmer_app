import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityRecommendationHint {
  const CommunityRecommendationHint({
    this.preferredCategories = const <String>[],
    this.preferredMerchantIds = const <String>[],
  });

  final List<String> preferredCategories;
  final List<String> preferredMerchantIds;

  CommunityRecommendationHint merge(CommunityRecommendationHint other) {
    return CommunityRecommendationHint(
      preferredCategories: _mergeLists(preferredCategories, other.preferredCategories),
      preferredMerchantIds: _mergeLists(preferredMerchantIds, other.preferredMerchantIds),
    );
  }

  static List<String> _mergeLists(List<String> a, List<String> b, {int maxLength = 4}) {
    final seen = <String>{};
    final merged = <String>[];
    for (final value in [...a, ...b]) {
      if (value.isEmpty) continue;
      if (seen.add(value) && merged.length < maxLength) {
        merged.add(value);
      }
    }
    return merged;
  }
}

class CommunityRecommendationService {
  CommunityRecommendationService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<CommunityRecommendationHint> loadHints({required String userId}) async {
    final hints = await Future.wait([
      _loadUserPreferences(userId),
      _loadRecentSignals(),
    ]);
    return hints.reduce((value, element) => value.merge(element));
  }

  Future<CommunityRecommendationHint> _loadUserPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return const CommunityRecommendationHint();
      final data = doc.data() ?? <String, dynamic>{};
      final categories = List<String>.from(
        data['preferredCategories'] ?? data['favoriteCategories'] ?? const <String>[],
      );
      final merchants = List<String>.from(
        data['favoriteMerchants'] ?? data['followingMerchants'] ?? const <String>[],
      );
      return CommunityRecommendationHint(
        preferredCategories: categories.take(4).toList(),
        preferredMerchantIds: merchants.take(5).toList(),
      );
    } catch (_) {
      return const CommunityRecommendationHint();
    }
  }

  Future<CommunityRecommendationHint> _loadRecentSignals() async {
    try {
      final snapshot = await _firestore
          .collection('community_posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final Map<String, int> categoryWeights = {};
      final Map<String, _MerchantScore> merchantScores = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final categories = (data['categories'] as List<dynamic>? ?? const <dynamic>[]).cast<String>();
        final merchantId = data['merchantId']?.toString();
        final merchantName = data['merchantName']?.toString();
        final likes = (data['likes'] as num?)?.toInt() ?? 0;
        final comments = (data['comments'] as num?)?.toInt() ?? 0;
        final shares = (data['shares'] as num?)?.toInt() ?? 0;
        final score = likes + (comments * 2) + (shares * 3);

        for (final category in categories) {
          if (category.isEmpty) continue;
          categoryWeights[category] = (categoryWeights[category] ?? 0) + max(score, 1);
        }

        if ((merchantId ?? '').isNotEmpty) {
          final existing = merchantScores.putIfAbsent(merchantId!, () => _MerchantScore(name: merchantName ?? '', score: 0));
          existing.score += max(score, 1);
        }
      }

      final sortedCategories = categoryWeights.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedMerchants = merchantScores.entries.toList()
        ..sort((a, b) => b.value.score.compareTo(a.value.score));

      return CommunityRecommendationHint(
        preferredCategories: sortedCategories.take(3).map((e) => e.key).toList(),
        preferredMerchantIds: sortedMerchants.take(5).map((e) => e.key).toList(),
      );
    } catch (_) {
      return const CommunityRecommendationHint();
    }
  }
}

class _MerchantScore {
  _MerchantScore({required this.name, required this.score});

  final String name;
  int score;
}
