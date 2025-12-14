import 'package:cloud_firestore/cloud_firestore.dart';

class DiscoverFeedBundle {
  const DiscoverFeedBundle({
    required this.posts,
    required this.spotlights,
    required this.exclusiveOffers,
  });

  final List<DiscoverFeedPost> posts;
  final List<MerchantSpotlight> spotlights;
  final List<ExclusiveOffer> exclusiveOffers;
}

class DiscoverFeedPost {
  DiscoverFeedPost({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.merchantName,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.images,
    required this.categories,
    required this.createdAt,
    this.merchantId,
    this.userId,
  });

  factory DiscoverFeedPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return DiscoverFeedPost(
      id: doc.id,
      userName: data['userName']?.toString() ?? '',
      userAvatar: data['userAvatar']?.toString(),
      content: data['content']?.toString() ?? '',
      merchantName: data['merchantName']?.toString() ?? '',
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      comments: (data['comments'] as num?)?.toInt() ?? 0,
      shares: (data['shares'] as num?)?.toInt() ?? 0,
      images: (data['images'] as List<dynamic>? ?? const []).cast<String>(),
      categories: (data['categories'] as List<dynamic>? ?? const []).cast<String>(),
      createdAt: _parseDate(data['createdAt']),
      merchantId: data['merchantId']?.toString(),
      userId: data['userId']?.toString(),
    );
  }

  final String id;
  final String userName;
  final String? userAvatar;
  final String content;
  final String merchantName;
  final String? merchantId;
  final String? userId;
  final int likes;
  final int comments;
  final int shares;
  final List<String> images;
  final List<String> categories;
  final DateTime createdAt;
}

class MerchantSpotlight {
  MerchantSpotlight({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.priority,
    required this.deepLink,
  });

  factory MerchantSpotlight.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return MerchantSpotlight(
      id: doc.id,
      merchantId: data['merchantId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      subtitle: data['subtitle']?.toString() ?? '',
      coverImage: data['coverImage']?.toString(),
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      deepLink: data['deepLink']?.toString(),
    );
  }

  final String id;
  final String merchantId;
  final String title;
  final String subtitle;
  final String? coverImage;
  final int priority;
  final String? deepLink;
}

class ExclusiveOffer {
  ExclusiveOffer({
    required this.id,
    required this.storeName,
    required this.description,
    required this.imageUrl,
    required this.merchantId,
    required this.expiresAt,
    required this.rawData,
  });

  factory ExclusiveOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ExclusiveOffer(
      id: doc.id,
      storeName: data['storeName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      merchantId: data['merchantId']?.toString(),
      expiresAt: _parseDate(data['endDate']),
      rawData: Map<String, dynamic>.from(data)..['id'] = doc.id,
    );
  }

  final String id;
  final String storeName;
  final String description;
  final String? imageUrl;
  final String? merchantId;
  final DateTime expiresAt;
  final Map<String, dynamic> rawData;

  Map<String, dynamic> toMap() {
    return {
      ...rawData,
      'id': rawData['id'] ?? id,
      'storeName': storeName,
      'description': description,
      'image': rawData['image'] ?? imageUrl,
      'imageUrl': imageUrl,
      'merchantId': merchantId ?? rawData['merchantId'],
      'endDate': rawData['endDate'] ?? expiresAt,
    };
  }
}

class DiscoverFeedFilter {
  const DiscoverFeedFilter({
    required this.userId,
    this.categories = const [],
    this.query,
    this.onlyNearby = false,
    this.preferredMerchantIds = const [],
  });

  DiscoverFeedFilter copyWith({
    List<String>? categories,
    String? query,
    bool? onlyNearby,
    List<String>? preferredMerchantIds,
  }) {
    return DiscoverFeedFilter(
      userId: userId,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      onlyNearby: onlyNearby ?? this.onlyNearby,
      preferredMerchantIds: preferredMerchantIds ?? this.preferredMerchantIds,
    );
  }

  final String userId;
  final List<String> categories;
  final String? query;
  final bool onlyNearby;
  final List<String> preferredMerchantIds;
}

DateTime _parseDate(dynamic raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  if (raw is String) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  return DateTime.now();
}
