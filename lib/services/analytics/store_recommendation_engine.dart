import '../../models/store_performance.dart';

class StoreRecommendationEngine {
  const StoreRecommendationEngine();

  Future<List<Recommendation>> generateRecommendations(StorePerformance store) async {
    final recs = <Recommendation>[];

    if (store.growthRate < -10) {
      recs.add(
        Recommendation(
          type: RecommendationType.issue,
          title: 'انخفاض حاد في المبيعات',
          description: 'المحل يعاني من انخفاض ${store.growthRate.abs().toStringAsFixed(1)}%',
          severity: Severity.high,
          suggestedAction: 'إطلاق عرض تحفيزي خلال الأسبوع القادم',
          estimatedImpact: 'زيادة متوقعة 15-20%',
        ),
      );
    }

    if (store.marketShare < 30) {
      recs.add(
        Recommendation(
          type: RecommendationType.opportunity,
          title: 'فرصة لزيادة الحصة السوقية',
          description: 'الحصة الحالية ${store.marketShare.toStringAsFixed(1)}% ويمكن التوسع فيها',
          severity: Severity.medium,
          suggestedAction: 'تدريب الفريق وتوفير مواد ترويجية جديدة',
          estimatedImpact: 'زيادة متوقعة 10-15%',
        ),
      );
    }

    final underPerforming = store.products.values.where((product) => product.growthRate < -5).toList();
    if (underPerforming.isNotEmpty) {
      recs.add(
        Recommendation(
          type: RecommendationType.product,
          title: 'منتجات تحتاج إلى دعم',
          description: '${underPerforming.length} منتج في تراجع',
          severity: Severity.medium,
          suggestedAction: 'تشغيل حملات ترويجية مخصصة لهذه المنتجات',
          estimatedImpact: 'زيادة مبيعات المنتجات حتى 25%',
        ),
      );
    }

    return recs;
  }
}
