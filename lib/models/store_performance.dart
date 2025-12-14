import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents performance analytics for a single store selling a specific brand.
class StorePerformance extends Equatable {
  const StorePerformance({
    required this.storeId,
    required this.storeName,
    required this.brandId,
    required this.location,
    required this.products,
    required this.totalSales,
    required this.totalTransactions,
    required this.growthRate,
    required this.marketShare,
    required this.lastSaleDate,
    required this.rating,
    required this.issues,
    required this.recommendations,
    required this.storeAverage,
    required this.brandAverage,
    required this.difference,
  });

  final String storeId;
  final String storeName;
  final String brandId;
  final GeoPoint location;
  final Map<String, ProductPerformance> products;

  // Store stats
  final double totalSales;
  final int totalTransactions;
  final double growthRate;
  final double marketShare;
  final DateTime lastSaleDate;

  // Analytics insights
  final PerformanceRating rating;
  final List<String> issues;
  final List<Recommendation> recommendations;

  // Comparative stats
  final double storeAverage;
  final double brandAverage;
  final double difference;

  StorePerformance copyWith({
    String? storeId,
    String? storeName,
    String? brandId,
    GeoPoint? location,
    Map<String, ProductPerformance>? products,
    double? totalSales,
    int? totalTransactions,
    double? growthRate,
    double? marketShare,
    DateTime? lastSaleDate,
    PerformanceRating? rating,
    List<String>? issues,
    List<Recommendation>? recommendations,
    double? storeAverage,
    double? brandAverage,
    double? difference,
  }) {
    return StorePerformance(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      brandId: brandId ?? this.brandId,
      location: location ?? this.location,
      products: products ?? this.products,
      totalSales: totalSales ?? this.totalSales,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      growthRate: growthRate ?? this.growthRate,
      marketShare: marketShare ?? this.marketShare,
      lastSaleDate: lastSaleDate ?? this.lastSaleDate,
      rating: rating ?? this.rating,
      issues: issues ?? this.issues,
      recommendations: recommendations ?? this.recommendations,
      storeAverage: storeAverage ?? this.storeAverage,
      brandAverage: brandAverage ?? this.brandAverage,
      difference: difference ?? this.difference,
    );
  }

  factory StorePerformance.fromJson(Map<String, dynamic> json) {
    final productMap = (json['products'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, ProductPerformance.fromJson(value as Map<String, dynamic>)),
    );
    return StorePerformance(
      storeId: json['storeId'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      brandId: json['brandId'] as String? ?? '',
      location: json['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      products: productMap,
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      growthRate: (json['growthRate'] as num?)?.toDouble() ?? 0,
      marketShare: (json['marketShare'] as num?)?.toDouble() ?? 0,
      lastSaleDate: (json['lastSaleDate'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      rating: PerformanceRatingX.fromString(json['rating'] as String?),
      issues: (json['issues'] as List<dynamic>? ?? const []).cast<String>(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .map((item) => Recommendation.fromJson(item as Map<String, dynamic>))
          .toList(),
      storeAverage: (json['storeAverage'] as num?)?.toDouble() ?? 0,
      brandAverage: (json['brandAverage'] as num?)?.toDouble() ?? 0,
      difference: (json['difference'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'storeName': storeName,
      'brandId': brandId,
      'location': location,
      'products': products.map((key, value) => MapEntry(key, value.toJson())),
      'totalSales': totalSales,
      'totalTransactions': totalTransactions,
      'growthRate': growthRate,
      'marketShare': marketShare,
      'lastSaleDate': Timestamp.fromDate(lastSaleDate),
      'rating': rating.name,
      'issues': issues,
      'recommendations': recommendations.map((rec) => rec.toJson()).toList(),
      'storeAverage': storeAverage,
      'brandAverage': brandAverage,
      'difference': difference,
    };
  }

  @override
  List<Object?> get props => [
        storeId,
        storeName,
        brandId,
        location,
        products,
        totalSales,
        totalTransactions,
        growthRate,
        marketShare,
        lastSaleDate,
        rating,
        issues,
        recommendations,
        storeAverage,
        brandAverage,
        difference,
      ];
}

class ProductPerformance extends Equatable {
  const ProductPerformance({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
    required this.growthRate,
    required this.customerCount,
    required this.seasonality,
    required this.peakDays,
    required this.peakHours,
  });

  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  final double growthRate;
  final int customerCount;
  final Seasonality seasonality;
  final List<String> peakDays;
  final List<String> peakHours;

  factory ProductPerformance.fromJson(Map<String, dynamic> json) {
    return ProductPerformance(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      unitsSold: json['unitsSold'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      growthRate: (json['growthRate'] as num?)?.toDouble() ?? 0,
      customerCount: json['customerCount'] as int? ?? 0,
      seasonality: SeasonalityX.fromString(json['seasonality'] as String?),
      peakDays: (json['peakDays'] as List<dynamic>? ?? const []).cast<String>(),
      peakHours: (json['peakHours'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'unitsSold': unitsSold,
      'revenue': revenue,
      'growthRate': growthRate,
      'customerCount': customerCount,
      'seasonality': seasonality.name,
      'peakDays': peakDays,
      'peakHours': peakHours,
    };
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        unitsSold,
        revenue,
        growthRate,
        customerCount,
        seasonality,
        peakDays,
        peakHours,
      ];
}

enum PerformanceRating {
  excellent,
  good,
  average,
  poor,
  critical,
}

enum Seasonality {
  evergreen,
  seasonal,
  occasional,
}

extension PerformanceRatingX on PerformanceRating {
  static PerformanceRating fromString(String? value) {
    return PerformanceRating.values.firstWhere(
      (rating) => rating.name == value,
      orElse: () => PerformanceRating.average,
    );
  }
}

extension SeasonalityX on Seasonality {
  static Seasonality fromString(String? value) {
    return Seasonality.values.firstWhere(
      (season) => season.name == value,
      orElse: () => Seasonality.evergreen,
    );
  }
}

class Recommendation extends Equatable {
  const Recommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.suggestedAction,
    required this.estimatedImpact,
  });

  final RecommendationType type;
  final String title;
  final String description;
  final Severity severity;
  final String suggestedAction;
  final String estimatedImpact;

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: RecommendationTypeX.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      severity: SeverityX.fromString(json['severity'] as String?),
      suggestedAction: json['suggestedAction'] as String? ?? '',
      estimatedImpact: json['estimatedImpact'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'description': description,
      'severity': severity.name,
      'suggestedAction': suggestedAction,
      'estimatedImpact': estimatedImpact,
    };
  }

  @override
  List<Object?> get props => [type, title, description, severity, suggestedAction, estimatedImpact];
}

enum RecommendationType { issue, opportunity, product, location }

enum Severity { low, medium, high }

extension RecommendationTypeX on RecommendationType {
  static RecommendationType fromString(String? value) {
    return RecommendationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => RecommendationType.opportunity,
    );
  }
}

extension SeverityX on Severity {
  static Severity fromString(String? value) {
    return Severity.values.firstWhere(
      (severity) => severity.name == value,
      orElse: () => Severity.medium,
    );
  }
}
