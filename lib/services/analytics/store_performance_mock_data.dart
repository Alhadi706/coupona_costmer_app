import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/store_performance.dart';

class StorePerformanceMockData {
  static final List<StorePerformance> _stores = [
    StorePerformance(
      storeId: 'store_001',
      storeName: 'محل المدينة',
      brandId: 'brand_demo',
      location: const GeoPoint(32.8872, 13.1913),
      products: {
        'prod_1': ProductPerformance(
          productId: 'prod_1',
          productName: 'منتج أساسي',
          unitsSold: 120,
          revenue: 4800,
          growthRate: 12,
          customerCount: 80,
          seasonality: Seasonality.evergreen,
          peakDays: const ['الاثنين', 'الخميس'],
          peakHours: const ['10:00', '19:00'],
        ),
        'prod_2': ProductPerformance(
          productId: 'prod_2',
          productName: 'منتج موسمي',
          unitsSold: 60,
          revenue: 3600,
          growthRate: -4,
          customerCount: 45,
          seasonality: Seasonality.seasonal,
          peakDays: const ['الجمعة'],
          peakHours: const ['21:00'],
        ),
      },
      totalSales: 11200,
      totalTransactions: 260,
      growthRate: 8.5,
      marketShare: 35,
      lastSaleDate: DateTime.now().subtract(const Duration(hours: 4)),
      rating: PerformanceRating.good,
      issues: const ['نقص مخزون منتج موسمي'],
      recommendations: const [],
      storeAverage: 9000,
      brandAverage: 7500,
      difference: 15,
    ),
    StorePerformance(
      storeId: 'store_002',
      storeName: 'سوق الضواحي',
      brandId: 'brand_demo',
      location: const GeoPoint(32.5, 12.9),
      products: {
        'prod_1': ProductPerformance(
          productId: 'prod_1',
          productName: 'منتج أساسي',
          unitsSold: 80,
          revenue: 3200,
          growthRate: -12,
          customerCount: 60,
          seasonality: Seasonality.evergreen,
          peakDays: const ['الثلاثاء'],
          peakHours: const ['18:00'],
        ),
      },
      totalSales: 5600,
      totalTransactions: 140,
      growthRate: -9.2,
      marketShare: 18,
      lastSaleDate: DateTime.now().subtract(const Duration(days: 1)),
      rating: PerformanceRating.poor,
      issues: const ['انخفاض مستمر في المبيعات'],
      recommendations: const [],
      storeAverage: 6000,
      brandAverage: 7500,
      difference: -7,
    ),
  ];

  static Stream<List<StorePerformance>> watchBrand(String brandId) async* {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    yield _stores.where((store) => store.brandId == brandId).toList();
  }

  static List<StorePerformance> listForBrand(String brandId) {
    return _stores.where((store) => store.brandId == brandId).toList();
  }
}
