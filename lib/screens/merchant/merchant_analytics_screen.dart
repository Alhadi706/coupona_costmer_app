import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../services/firestore/invoice_repository.dart';
import '../../services/firestore/product_repository.dart';

class MerchantAnalyticsScreen extends StatefulWidget {
  final String merchantId;
  const MerchantAnalyticsScreen({super.key, required this.merchantId});

  @override
  State<MerchantAnalyticsScreen> createState() => _MerchantAnalyticsScreenState();
}

class _MerchantAnalyticsScreenState extends State<MerchantAnalyticsScreen> {
  late final InvoiceRepository _invoiceRepository;
  late final ProductRepository _productRepository;
  final Map<String, _CustomerDemographic> _demographicCache = {};

  @override
  void initState() {
    super.initState();
    _invoiceRepository = InvoiceRepository();
    _productRepository = ProductRepository();
  }

  Future<Map<String, _CustomerDemographic>> _ensureDemographics(List<String> customerIds) async {
    final ids = customerIds.where((id) => id.isNotEmpty).toSet().toList();
    final missing = ids.where((id) => !_demographicCache.containsKey(id)).toList();

    for (final customerId in missing) {
      try {
        final doc = await FirebaseFirestore.instance.collection('customers').doc(customerId).get();
        if (doc.exists) {
          final data = doc.data() ?? const <String, dynamic>{};
          _demographicCache[customerId] = _CustomerDemographic(
            displayName: data['name']?.toString(),
            gender: data['gender']?.toString(),
            age: (data['age'] as num?)?.toInt(),
          );
        } else {
          _demographicCache[customerId] = const _CustomerDemographic();
        }
      } on FirebaseException {
        // Permission-denied or missing documents shouldn't break analytics; cache empty entry.
        _demographicCache[customerId] = const _CustomerDemographic();
      }
    }

    return {
      for (final id in ids)
        if (_demographicCache.containsKey(id)) id: _demographicCache[id]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_analytics_title'.tr())),
      body: StreamBuilder<List<Invoice>>(
        stream: _invoiceRepository.watchInvoices(widget.merchantId),
        builder: (context, invoiceSnapshot) {
          if (invoiceSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (invoiceSnapshot.hasError) {
            return _AnalyticsEmptyState(message: invoiceSnapshot.error.toString());
          }
          return StreamBuilder<List<Product>>(
            stream: _productRepository.watchProducts(widget.merchantId),
            builder: (context, productSnapshot) {
              if (productSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (productSnapshot.hasError) {
                return _AnalyticsEmptyState(message: productSnapshot.error.toString());
              }

              final invoices = invoiceSnapshot.data ?? const [];
              final products = productSnapshot.data ?? const [];

              if (invoices.isEmpty) {
                final analytics = _buildAnalytics(
                  invoices,
                  products,
                  const <String, _CustomerDemographic>{},
                  context.locale,
                );
                return _buildAnalyticsView(analytics);
              }

              return FutureBuilder<Map<String, _CustomerDemographic>>(
                future: _ensureDemographics(invoices.map((invoice) => invoice.customerId).toList()),
                builder: (context, demoSnapshot) {
                  if (demoSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final analytics = _buildAnalytics(
                    invoices,
                    products,
                    demoSnapshot.data ?? const <String, _CustomerDemographic>{},
                    context.locale,
                  );
                  return _buildAnalyticsView(
                    analytics,
                    showDemographicWarning: demoSnapshot.hasError,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsView(_AnalyticsBundle analytics, {bool showDemographicWarning = false}) {
    if (!analytics.hasData) {
      return _AnalyticsEmptyState(message: 'merchant_analytics_empty_state'.tr());
    }

    final recommendations = _buildRecommendations(analytics);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricGrid(
          metrics: [
            _MetricTileData(
              label: 'merchant_analytics_total_sales'.tr(),
              value: _formatCurrency(analytics.totalSales),
              icon: Icons.payments_outlined,
            ),
            _MetricTileData(
              label: 'merchant_analytics_orders'.tr(),
              value: analytics.invoiceCount.toString(),
              icon: Icons.receipt_long_outlined,
            ),
            _MetricTileData(
              label: 'merchant_analytics_customers'.tr(),
              value: analytics.uniqueCustomers.toString(),
              icon: Icons.people_alt_outlined,
            ),
            _MetricTileData(
              label: 'merchant_analytics_repeat_rate'.tr(),
              value: '${(analytics.repeatRate * 100).toStringAsFixed(0)}%',
              icon: Icons.repeat_on_outlined,
            ),
            _MetricTileData(
              label: 'merchant_analytics_avg_ticket'.tr(),
              value: _formatCurrency(analytics.averageTicket),
              icon: Icons.shopping_basket_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _AnalyticsSection(
          title: 'merchant_analytics_sales_trend'.tr(),
          child: _AnalyticsTrendChart(points: analytics.salesTrend),
        ),
        const SizedBox(height: 16),
        _AnalyticsSection(
          title: 'merchant_analytics_top_products'.tr(),
          child: analytics.topProducts.isEmpty
              ? Text('merchant_analytics_no_data'.tr())
              : Column(
                  children: analytics.topProducts
                      .asMap()
                      .entries
                      .map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text('${entry.key + 1}')),
                          title: Text(entry.value.name),
                          subtitle: Text(
                            'merchant_analytics_units_sold'.tr(args: [entry.value.quantity.toString()]),
                          ),
                          trailing: Text(_formatCurrency(entry.value.revenue)),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _AnalyticsSection(
          title: 'merchant_analytics_customer_demographics'.tr(),
          child: analytics.demographics.hasAnyData
              ? Column(
                  children: [
                    _GenderBreakdown(snapshot: analytics.demographics),
                    const SizedBox(height: 16),
                    _AgeDistributionView(snapshot: analytics.demographics),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('merchant_analytics_demographics_empty'.tr()),
                    if (showDemographicWarning)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'merchant_analytics_demographics_permission_hint'.tr(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade700),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _AnalyticsSection(
          title: 'merchant_analytics_category_performance'.tr(),
          child: analytics.categoryPerformance.isEmpty
              ? Text('merchant_analytics_category_empty'.tr())
              : Column(
                  children: analytics.categoryPerformance
                      .map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.category_outlined),
                          title: Text(entry.category.isEmpty
                              ? 'merchant_analytics_category_uncategorized'.tr()
                              : entry.category),
                          subtitle: Text(
                            'merchant_analytics_units_sold'.tr(args: [entry.quantity.toString()]),
                          ),
                          trailing: Text(_formatCurrency(entry.revenue)),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _AnalyticsSection(
          title: 'merchant_analytics_repeat_customers'.tr(),
          child: analytics.repeatCustomers.isEmpty
              ? Text('merchant_analytics_repeat_customers_empty'.tr())
              : Column(
                  children: analytics.repeatCustomers
                      .map(
                        (customer) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: Text(customer.displayName ?? customer.customerId),
                          subtitle: Text(
                            'merchant_analytics_orders_count'.tr(args: [customer.orderCount.toString()]),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _AnalyticsSection(
          title: 'merchant_analytics_recommendations'.tr(),
          child: recommendations.isEmpty
              ? Text('merchant_analytics_no_data'.tr())
              : Column(
                  children: recommendations
                      .map(
                        (tip) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                          title: Text(tip),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final symbol = context.locale.languageCode == 'ar' ? 'د.ل' : 'SAR';
    if (value >= 1000) {
      return '$symbol ${value.toStringAsFixed(0)}';
    }
    return '$symbol ${value.toStringAsFixed(1)}';
  }

  List<String> _buildRecommendations(_AnalyticsBundle analytics) {
    final tips = <String>[];
    if (!analytics.hasData) {
      tips.add('merchant_analytics_tip_collect_data'.tr());
      return tips;
    }
    if (analytics.repeatRate < 0.3 && analytics.uniqueCustomers > 0) {
      tips.add('merchant_analytics_tip_repeat'.tr());
    }
    if (analytics.averageTicket > 0 && analytics.averageTicket < 75) {
      tips.add('merchant_analytics_tip_ticket'.tr());
    }
    if (analytics.salesTrend.isNotEmpty && analytics.salesTrend.last.value < analytics.averageTicket) {
      tips.add('merchant_analytics_tip_trend'.tr());
    }
    return tips;
  }

  _AnalyticsBundle _buildAnalytics(
    List<Invoice> invoices,
    List<Product> products,
    Map<String, _CustomerDemographic> demographics,
    Locale locale,
  ) {
    if (invoices.isEmpty) {
      return _AnalyticsBundle.empty();
    }

    final totalSales = invoices.fold<double>(0, (runningTotal, invoice) => runningTotal + invoice.totalAmount);
    final customerFrequency = <String, int>{};
    for (final invoice in invoices) {
      customerFrequency[invoice.customerId] = (customerFrequency[invoice.customerId] ?? 0) + 1;
    }

    final uniqueCustomers = customerFrequency.length;
    final repeatCustomers = customerFrequency.entries.where((entry) => entry.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final demographicSnapshot = _buildDemographicSnapshot(customerFrequency.keys, demographics);
    final categoryPerformance = _buildCategoryPerformance(invoices, products);

    return _AnalyticsBundle(
      totalSales: totalSales,
      invoiceCount: invoices.length,
      uniqueCustomers: uniqueCustomers,
      repeatRate: uniqueCustomers == 0 ? 0 : repeatCustomers.length / uniqueCustomers,
      averageTicket: invoices.isEmpty ? 0 : totalSales / invoices.length,
      salesTrend: _buildTrend(invoices, locale),
      topProducts: _buildTopProducts(invoices, products),
      repeatCustomers: repeatCustomers
          .map(
            (entry) => _CustomerMetric(
              customerId: entry.key,
              orderCount: entry.value,
              displayName: demographics[entry.key]?.displayName,
            ),
          )
          .take(5)
          .toList(),
      demographics: demographicSnapshot,
      categoryPerformance: categoryPerformance,
    );
  }

  _DemographicSnapshot _buildDemographicSnapshot(
    Iterable<String> customerIds,
    Map<String, _CustomerDemographic> demographics,
  ) {
    if (customerIds.isEmpty) {
      return _DemographicSnapshot.empty();
    }

    var male = 0;
    var female = 0;
    var other = 0;
    final ageBuckets = <String, int>{
      '18_24': 0,
      '25_34': 0,
      '35_44': 0,
      '45_plus': 0,
      'unknown': 0,
    };

    for (final id in customerIds) {
      final profile = demographics[id];
      if (profile == null) continue;

      final gender = (profile.gender ?? '').toLowerCase();
      switch (gender) {
        case 'male':
        case 'm':
          male++;
          break;
        case 'female':
        case 'f':
          female++;
          break;
        default:
          other++;
      }

      final bucket = _resolveAgeBucket(profile.age);
      ageBuckets[bucket] = (ageBuckets[bucket] ?? 0) + 1;
    }

    return _DemographicSnapshot(
      male: male,
      female: female,
      other: other,
      ageBuckets: Map.unmodifiable(ageBuckets),
    );
  }

  String _resolveAgeBucket(int? age) {
    if (age == null || age <= 0) return 'unknown';
    if (age < 25) return '18_24';
    if (age < 35) return '25_34';
    if (age < 45) return '35_44';
    return '45_plus';
  }

  List<_CategoryPerformance> _buildCategoryPerformance(List<Invoice> invoices, List<Product> products) {
    if (invoices.isEmpty) {
      return const [];
    }

    final productCategory = <String, String>{
      for (final product in products) product.id: product.category,
    };
    final revenueByCategory = <String, double>{};
    final quantityByCategory = <String, int>{};

    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final rawCategory = productCategory[item.productId]?.trim() ?? '';
        final categoryKey = rawCategory;
        final lineRevenue = item.price * item.quantity;
        revenueByCategory[categoryKey] = (revenueByCategory[categoryKey] ?? 0) + lineRevenue;
        quantityByCategory[categoryKey] = (quantityByCategory[categoryKey] ?? 0) + item.quantity;
      }
    }

    final entries = revenueByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (entry) => _CategoryPerformance(
            category: entry.key,
            revenue: entry.value,
            quantity: quantityByCategory[entry.key] ?? 0,
          ),
        )
        .take(6)
        .toList();
  }

  List<_ChartEntry> _buildTrend(List<Invoice> invoices, Locale locale) {
    if (invoices.isEmpty) return const [];
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final buckets = <DateTime, double>{};
    for (int i = 0; i < 7; i++) {
      final day = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      buckets[day] = 0;
    }
    for (final invoice in invoices) {
      final created = invoice.createdAt.toDate();
      final normalized = DateTime(created.year, created.month, created.day);
      if (normalized.isBefore(start)) continue;
      if (!buckets.containsKey(normalized)) continue;
      buckets[normalized] = (buckets[normalized] ?? 0) + invoice.totalAmount;
    }
    return buckets.entries
        .map((entry) => _ChartEntry(
              label: _formatDayLabel(entry.key, locale),
              value: entry.value,
            ))
        .toList();
  }

  String _formatDayLabel(DateTime day, Locale locale) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return locale.languageCode == 'ar' ? '$date/$month' : '$month/$date';
  }

  List<_ProductPerformance> _buildTopProducts(List<Invoice> invoices, List<Product> products) {
    final revenueByProduct = <String, double>{};
    final quantityByProduct = <String, int>{};
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final revenue = item.price * item.quantity;
        revenueByProduct[item.productId] = (revenueByProduct[item.productId] ?? 0) + revenue;
        quantityByProduct[item.productId] = (quantityByProduct[item.productId] ?? 0) + item.quantity;
      }
    }
    if (revenueByProduct.isEmpty) return const [];

    final nameLookup = <String, String>{
      for (final product in products) product.id: product.name,
    };

    final entries = revenueByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (entry) => _ProductPerformance(
            id: entry.key,
            name: nameLookup[entry.key] ?? entry.key,
            revenue: entry.value,
            quantity: quantityByProduct[entry.key] ?? 0,
          ),
        )
        .take(5)
        .toList();
  }
}

class _AnalyticsBundle {
  final double totalSales;
  final int invoiceCount;
  final int uniqueCustomers;
  final double repeatRate;
  final double averageTicket;
  final List<_ChartEntry> salesTrend;
  final List<_ProductPerformance> topProducts;
  final List<_CustomerMetric> repeatCustomers;
  final _DemographicSnapshot demographics;
  final List<_CategoryPerformance> categoryPerformance;

  const _AnalyticsBundle({
    required this.totalSales,
    required this.invoiceCount,
    required this.uniqueCustomers,
    required this.repeatRate,
    required this.averageTicket,
    required this.salesTrend,
    required this.topProducts,
    required this.repeatCustomers,
    required this.demographics,
    required this.categoryPerformance,
  });

  bool get hasData => invoiceCount > 0 || totalSales > 0;

    factory _AnalyticsBundle.empty() => _AnalyticsBundle(
        totalSales: 0,
        invoiceCount: 0,
        uniqueCustomers: 0,
        repeatRate: 0,
        averageTicket: 0,
      salesTrend: const <_ChartEntry>[],
      topProducts: const <_ProductPerformance>[],
      repeatCustomers: const <_CustomerMetric>[],
        demographics: _DemographicSnapshot.empty(),
      categoryPerformance: const <_CategoryPerformance>[],
      );
}

class _ChartEntry {
  final String label;
  final double value;
  const _ChartEntry({required this.label, required this.value});
}

class _ProductPerformance {
  final String id;
  final String name;
  final double revenue;
  final int quantity;
  const _ProductPerformance({
    required this.id,
    required this.name,
    required this.revenue,
    required this.quantity,
  });
}

class _CustomerMetric {
  final String customerId;
  final int orderCount;
  final String? displayName;
  const _CustomerMetric({required this.customerId, required this.orderCount, this.displayName});
}

class _CategoryPerformance {
  final String category;
  final double revenue;
  final int quantity;
  const _CategoryPerformance({required this.category, required this.revenue, required this.quantity});
}

class _DemographicSnapshot {
  final int male;
  final int female;
  final int other;
  final Map<String, int> ageBuckets;

  const _DemographicSnapshot({
    required this.male,
    required this.female,
    required this.other,
    required this.ageBuckets,
  });

  int get total => male + female + other;
  bool get hasAnyData => total > 0 || ageBuckets.values.any((value) => value > 0);

  factory _DemographicSnapshot.empty() => const _DemographicSnapshot(
        male: 0,
        female: 0,
        other: 0,
        ageBuckets: <String, int>{
          '18_24': 0,
          '25_34': 0,
          '35_44': 0,
          '45_plus': 0,
          'unknown': 0,
        },
      );
}

class _CustomerDemographic {
  final String? displayName;
  final String? gender;
  final int? age;
  const _CustomerDemographic({this.displayName, this.gender, this.age});
}

class _GenderSegment {
  final String label;
  final int count;
  final Color color;
  const _GenderSegment({required this.label, required this.count, required this.color});
}

class _MetricTileData {
  final String label;
  final String value;
  final IconData icon;
  const _MetricTileData({required this.label, required this.value, required this.icon});
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricTileData> metrics;
  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics
          .map(
            (metric) => SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 24,
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(metric.icon, color: Colors.deepPurple),
                      const SizedBox(height: 8),
                      Text(metric.value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _AnalyticsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GenderBreakdown extends StatelessWidget {
  final _DemographicSnapshot snapshot;
  const _GenderBreakdown({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final total = snapshot.total;
    if (total == 0) {
      return Text('merchant_analytics_demographics_empty'.tr());
    }

    final segments = [
      _GenderSegment(
        label: 'merchant_analytics_gender_male'.tr(),
        count: snapshot.male,
        color: Colors.blue.shade400,
      ),
      _GenderSegment(
        label: 'merchant_analytics_gender_female'.tr(),
        count: snapshot.female,
        color: Colors.pink.shade300,
      ),
      _GenderSegment(
        label: 'merchant_analytics_gender_other'.tr(),
        count: snapshot.other,
        color: Colors.purple.shade300,
      ),
    ].where((segment) => segment.count > 0).toList();

    if (segments.isEmpty) {
      return Text('merchant_analytics_demographics_empty'.tr());
    }

    return Row(
      children: segments
          .map(
            (segment) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: segment.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${segment.count}', style: Theme.of(context).textTheme.titleLarge),
                    Text('${((segment.count / total) * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AgeDistributionView extends StatelessWidget {
  final _DemographicSnapshot snapshot;
  const _AgeDistributionView({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final visibleBuckets = snapshot.ageBuckets.entries.where((entry) => entry.value > 0).toList();
    if (visibleBuckets.isEmpty) {
      return Text('merchant_analytics_demographics_empty'.tr());
    }

    final total = visibleBuckets.fold<int>(0, (runningTotal, entry) => runningTotal + entry.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('merchant_analytics_age_distribution'.tr(), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        ...visibleBuckets.map(
          (entry) {
            final percent = total == 0 ? 0.0 : entry.value / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_ageBucketLabel(context, entry.key)),
                      Text('${(percent * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _ageBucketLabel(BuildContext context, String bucketKey) {
  switch (bucketKey) {
    case '18_24':
      return 'merchant_analytics_age_bucket_18_24'.tr();
    case '25_34':
      return 'merchant_analytics_age_bucket_25_34'.tr();
    case '35_44':
      return 'merchant_analytics_age_bucket_35_44'.tr();
    case '45_plus':
      return 'merchant_analytics_age_bucket_45_plus'.tr();
    default:
      return 'merchant_analytics_age_unknown'.tr();
  }
}

class _AnalyticsTrendChart extends StatelessWidget {
  final List<_ChartEntry> points;
  const _AnalyticsTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text('merchant_analytics_no_data'.tr());
    }
    final spots = points
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.value))
        .toList();
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(points[index].label, style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 4,
              color: Colors.deepPurple,
              belowBarData: BarAreaData(show: true, color: Colors.deepPurple.withValues(alpha: 0.1)),
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  final String message;
  const _AnalyticsEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 72, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'merchant_analytics_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
