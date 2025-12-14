import '../../models/store_performance.dart';
import 'store_performance_repository.dart';
import 'store_recommendation_engine.dart';

class StoreAnalyticsService {
  StoreAnalyticsService({
    StorePerformanceRepository? repository,
    StoreRecommendationEngine? recommendationEngine,
  })  : _repository = repository ?? StorePerformanceRepository(),
        _recommendationEngine = recommendationEngine ?? const StoreRecommendationEngine();

  final StorePerformanceRepository _repository;
  final StoreRecommendationEngine _recommendationEngine;

  Stream<List<StorePerformance>> watchBrandStores(String brandId) => _repository.watchBrandStores(brandId);

  Future<StorePerformance?> fetchStore(String brandId, String storeId) => _repository.fetchStore(brandId, storeId);

  Future<List<Recommendation>> refreshRecommendations(StorePerformance store) async {
    final recommendations = await _recommendationEngine.generateRecommendations(store);
    final updated = store.copyWith(recommendations: recommendations);
    await _repository.upsertStorePerformance(updated);
    return recommendations;
  }
}
