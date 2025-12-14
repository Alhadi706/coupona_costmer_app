import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/store_performance.dart';
import '../services/analytics/store_analytics_service.dart';
import '../services/analytics/store_performance_mock_data.dart';

class StorePerformanceAnalysisScreen extends StatefulWidget {
  const StorePerformanceAnalysisScreen({super.key, required this.brandId});

  final String brandId;

  @override
  State<StorePerformanceAnalysisScreen> createState() => _StorePerformanceAnalysisScreenState();
}

class _StorePerformanceAnalysisScreenState extends State<StorePerformanceAnalysisScreen> {
  late final StoreAnalyticsService _analyticsService;
  List<StorePerformance> _currentStores = const [];
  String _searchQuery = '';
  PerformanceRating? _ratingFilter;

  @override
  void initState() {
    super.initState();
    _analyticsService = StoreAnalyticsService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StorePerformance>>(
      stream: _analyticsService.watchBrandStores(widget.brandId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('store analytics stream error: ${snapshot.error}');
        }
        final stores = _resolveStores(snapshot);
        _currentStores = stores;
        final filtered = _filterStores(stores);

        return Scaffold(
          appBar: AppBar(
            title: const Text('أداء المحلات'),
            actions: [
              IconButton(icon: const Icon(Icons.map), tooltip: 'عرض الخريطة', onPressed: () => _openGeographicView(filtered)),
              IconButton(icon: const Icon(Icons.download), tooltip: 'تصدير التحليل', onPressed: _exportAnalysis),
            ],
          ),
          body: Column(
            children: [
              _buildStoreFilter(),
              _buildOverviewCards(filtered),
              Expanded(child: _buildStoresPerformanceTable(filtered)),
              _buildMiniMapPreview(filtered),
            ],
          ),
        );
      },
    );
  }

  List<StorePerformance> _filterStores(List<StorePerformance> stores) {
    return stores.where((store) {
      final matchesName = _searchQuery.isEmpty || store.storeName.contains(_searchQuery);
      final matchesRating = _ratingFilter == null || store.rating == _ratingFilter;
      return matchesName && matchesRating;
    }).toList();
  }

  List<StorePerformance> _resolveStores(AsyncSnapshot<List<StorePerformance>> snapshot) {
    if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
      return snapshot.data!;
    }
    final brandMocks = StorePerformanceMockData.listForBrand(widget.brandId);
    if (brandMocks.isNotEmpty) return brandMocks;
    final defaultMocks = StorePerformanceMockData.listForBrand('brand_demo');
    return defaultMocks.isNotEmpty ? defaultMocks : const [];
  }

  Widget _buildStoreFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن محل...'),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<PerformanceRating?>(
            hint: const Text('التقييم'),
            value: _ratingFilter,
            items: [
              const DropdownMenuItem(value: null, child: Text('الكل')),
              ...PerformanceRating.values
                  .map((rating) => DropdownMenuItem(value: rating, child: Text(_ratingLabel(rating)))),
            ],
            onChanged: (value) => setState(() => _ratingFilter = value),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(List<StorePerformance> stores) {
    final totalSales = stores.fold<double>(0, (sum, store) => sum + store.totalSales);
    final avgGrowth = stores.isEmpty ? 0 : stores.fold<double>(0, (sum, store) => sum + store.growthRate) / stores.length;
    final coverage = stores.where((store) => store.rating == PerformanceRating.excellent || store.rating == PerformanceRating.good).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _OverviewCard(title: 'إجمالي المبيعات', value: '${totalSales.toStringAsFixed(0)} د.ل', icon: Icons.attach_money)),
          const SizedBox(width: 12),
          Expanded(child: _OverviewCard(title: 'متوسط النمو', value: '${avgGrowth.toStringAsFixed(1)}%', icon: Icons.trending_up)),
          const SizedBox(width: 12),
          Expanded(child: _OverviewCard(title: 'محلات مميزة', value: coverage.toString(), icon: Icons.star_rate)),
        ],
      ),
    );
  }

  Widget _buildStoresPerformanceTable(List<StorePerformance> stores) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('المحل')),
          DataColumn(label: Text('الموقع')),
          DataColumn(label: Text('المبيعات')),
          DataColumn(label: Text('النمو')),
          DataColumn(label: Text('الحصة')),
          DataColumn(label: Text('التقييم')),
          DataColumn(label: Text('الإجراءات')),
        ],
        rows: stores.map((store) {
          return DataRow(
            cells: [
              DataCell(
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(store.storeName.isNotEmpty ? store.storeName[0] : '?')),
                  title: Text(store.storeName),
                  subtitle: Text('${store.totalTransactions} معاملة'),
                ),
                onTap: () => _openStoreDetail(store),
              ),
              DataCell(
                Tooltip(
                  message: '${store.location.latitude}, ${store.location.longitude}',
                  child: const Icon(Icons.location_on, color: Colors.blue),
                ),
              ),
              DataCell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${store.totalSales.toStringAsFixed(0)} د.ل'),
                  Text('${store.products.length} منتج', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )),
              DataCell(_GrowthBadge(value: store.growthRate)),
              DataCell(LinearProgressIndicator(
                value: (store.marketShare / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: Colors.blue,
              )),
              DataCell(_buildPerformanceRatingBadge(store.rating)),
              DataCell(
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(value: 'analysis', child: ListTile(leading: Icon(Icons.analytics), title: Text('تحليل مفصل'))),
                    const PopupMenuItem<String>(value: 'offer', child: ListTile(leading: Icon(Icons.local_offer), title: Text('تقديم عرض'))),
                    const PopupMenuItem<String>(value: 'recommend', child: ListTile(leading: Icon(Icons.message), title: Text('إرسال توصية'))),
                    const PopupMenuItem<String>(value: 'compare', child: ListTile(leading: Icon(Icons.compare), title: Text('مقارنة مع آخرين'))),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'analysis':
                        _openStoreAnalysis(store);
                        break;
                      case 'offer':
                        _createOfferForStore(store);
                        break;
                      case 'recommend':
                        _sendRecommendation(store);
                        break;
                      case 'compare':
                        _compareStores(store);
                        break;
                    }
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMiniMapPreview(List<StorePerformance> stores) {
    if (stores.isEmpty) {
      return Container(
        height: 140,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.blueGrey.shade50),
        alignment: Alignment.center,
        child: const Text('لا توجد بيانات لعرض الخريطة المصغرة'),
      );
    }
    final markers = stores
        .map((store) => Marker(
              markerId: MarkerId('mini_${store.storeId}'),
              position: LatLng(store.location.latitude, store.location.longitude),
              infoWindow: InfoWindow(title: store.storeName, snippet: '${store.totalSales.toStringAsFixed(0)} د.ل'),
            ))
        .toSet();
    final first = stores.first;
    return Container(
      height: 180,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade50)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(first.location.latitude, first.location.longitude), zoom: 9),
          markers: markers,
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          onTap: (_) => _openGeographicView(stores),
        ),
      ),
    );
  }

  void _openGeographicView(List<StorePerformance> stores) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeographicDistributionScreen(stores: stores.isNotEmpty ? stores : _currentStores),
      ),
    );
  }

  void _exportAnalysis() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم دعم التصدير قريباً')));
  }

  void _openStoreDetail(StorePerformance store) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoreDetailAnalysisScreen(store: store)),
    );
  }

  void _openStoreAnalysis(StorePerformance store) => _openStoreDetail(store);

  void _createOfferForStore(StorePerformance store) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('إطلاق عرض خاص لـ ${store.storeName} قريباً')));
  }

  void _sendRecommendation(StorePerformance store) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('إرسال توصية إلى ${store.storeName}')));
  }

  void _compareStores(StorePerformance store) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('مقارنة ${store.storeName} بمحلات أخرى')));
  }
}

class StoreDetailAnalysisScreen extends StatelessWidget {
  const StoreDetailAnalysisScreen({super.key, required this.store});

  final StorePerformance store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(store.storeName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.trending_up), text: 'الأداء'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'المنتجات'),
              Tab(icon: Icon(Icons.timeline), text: 'التاريخ'),
              Tab(icon: Icon(Icons.lightbulb), text: 'التوصيات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PerformanceTab(store: store),
            _ProductsTab(store: store),
            _HistoryTab(store: store),
            _RecommendationsTab(store: store),
          ],
        ),
      ),
    );
  }
}

class GeographicDistributionScreen extends StatefulWidget {
  const GeographicDistributionScreen({super.key, required this.stores});

  final List<StorePerformance> stores;

  @override
  State<GeographicDistributionScreen> createState() => _GeographicDistributionScreenState();
}

class _GeographicDistributionScreenState extends State<GeographicDistributionScreen> {
  bool _showLegend = false;
  bool _showHeatMap = false;

  @override
  Widget build(BuildContext context) {
    final markers = widget.stores.map((store) {
      return Marker(
        markerId: MarkerId(store.storeId),
        position: LatLng(store.location.latitude, store.location.longitude),
        infoWindow: InfoWindow(title: store.storeName, snippet: 'المبيعات: ${store.totalSales.toStringAsFixed(0)}'),
      );
    }).toSet();

    final initial = widget.stores.isEmpty
        ? const CameraPosition(target: LatLng(32.8872, 13.1913), zoom: 5)
        : CameraPosition(target: LatLng(widget.stores.first.location.latitude, widget.stores.first.location.longitude), zoom: 10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التوزيع الجغرافي'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_alt), onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.download), onPressed: _exportMapData),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initial,
            markers: markers,
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Card(
              child: Column(
                children: [
                  IconButton(icon: const Icon(Icons.legend_toggle), tooltip: 'مفتاح الخريطة', onPressed: () => setState(() => _showLegend = !_showLegend)),
                  IconButton(icon: const Icon(Icons.local_fire_department), tooltip: 'خريطة الحرارة', onPressed: () => setState(() => _showHeatMap = !_showHeatMap)),
                  IconButton(icon: const Icon(Icons.category), tooltip: 'التصنيف حسب الأداء', onPressed: _toggleCategoryView),
                ],
              ),
            ),
          ),
          if (_showLegend)
            Positioned(
              bottom: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: PerformanceRating.values
                        .map((rating) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 12, height: 12, color: _ratingColor(rating)),
                                const SizedBox(width: 6),
                                Text(_ratingLabel(rating)),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('عدد المحلات: ${widget.stores.length}'),
                    Text('خريطة الحرارة: ${_showHeatMap ? 'مفعلة' : 'معطلة'}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خيارات الفلترة'),
        content: const Text('سيتم إضافة المرشحات لاحقاً'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق'))],
      ),
    );
  }

  void _exportMapData() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تصدير بيانات الخريطة قريباً')));
  }

  void _toggleCategoryView() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم دعم التصنيف قريباً')));
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.blueGrey.shade50, child: Icon(icon, color: Colors.blueGrey)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('${value.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

Widget _buildPerformanceRatingBadge(PerformanceRating rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: _ratingColor(rating).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
    child: Text(_ratingLabel(rating), style: TextStyle(color: _ratingColor(rating), fontWeight: FontWeight.bold)),
  );
}

Color _ratingColor(PerformanceRating rating) {
  switch (rating) {
    case PerformanceRating.excellent:
      return Colors.green;
    case PerformanceRating.good:
      return Colors.blue;
    case PerformanceRating.average:
      return Colors.orange;
    case PerformanceRating.poor:
      return Colors.deepOrange;
    case PerformanceRating.critical:
      return Colors.red;
  }
}

String _ratingLabel(PerformanceRating rating) {
  switch (rating) {
    case PerformanceRating.excellent:
      return 'ممتاز';
    case PerformanceRating.good:
      return 'جيد';
    case PerformanceRating.average:
      return 'متوسط';
    case PerformanceRating.poor:
      return 'ضعيف';
    case PerformanceRating.critical:
      return 'حرج';
  }
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({required this.store});

  final StorePerformance store;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ملخص الأداء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildPerformanceRatingBadge(store.rating),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    children: [
                      _MetricCard(title: 'المبيعات الإجمالية', value: '${store.totalSales.toStringAsFixed(0)} د.ل', icon: Icons.attach_money),
                      _MetricCard(title: 'عدد المعاملات', value: store.totalTransactions.toString(), icon: Icons.receipt_long),
                      _MetricCard(title: 'نسبة النمو', value: '${store.growthRate.toStringAsFixed(1)}%', icon: Icons.trending_up),
                      _MetricCard(title: 'حصة السوق', value: '${store.marketShare.toStringAsFixed(1)}%', icon: Icons.pie_chart),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('مبيعات الشهر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  SizedBox(height: 200, child: Placeholder()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مقارنة مع متوسط العلامة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _ComparisonCard(title: 'متوسط المحل', average: store.storeAverage, totalSales: store.totalSales)),
                      const SizedBox(width: 16),
                      Expanded(child: _ComparisonCard(title: 'متوسط العلامة', average: store.brandAverage, totalSales: store.totalSales)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'الفرق: ${store.difference >= 0 ? '+' : ''}${store.difference.toStringAsFixed(1)}%',
                    style: TextStyle(color: store.difference >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.store});

  final StorePerformance store;

  @override
  Widget build(BuildContext context) {
    final products = store.products.values.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          child: ListTile(
            title: Text(product.productName),
            subtitle: Text('الوحدات: ${product.unitsSold} · النمو: ${product.growthRate.toStringAsFixed(1)}%'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${product.revenue.toStringAsFixed(0)} د.ل'),
                Text('العملاء: ${product.customerCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.store});

  final StorePerformance store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: const Text('آخر عملية بيع'),
            subtitle: Text(store.lastSaleDate.toIso8601String()),
          ),
        ),
        const SizedBox(height: 12),
        const Card(child: SizedBox(height: 200, child: Placeholder())),
      ],
    );
  }
}

class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab({required this.store});

  final StorePerformance store;

  @override
  Widget build(BuildContext context) {
    final items = store.recommendations;
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد توصيات بعد'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final rec = items[index];
        return Card(
          child: ListTile(
            leading: Icon(_recommendationIcon(rec.type), color: _severityColor(rec.severity)),
            title: Text(rec.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.description),
                Text('الإجراء: ${rec.suggestedAction}', style: const TextStyle(fontSize: 12)),
                Text('التأثير المتوقع: ${rec.estimatedImpact}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.title, required this.average, required this.totalSales});

  final String title;
  final double average;
  final double totalSales;

  @override
  Widget build(BuildContext context) {
    final progress = average == 0 ? 0.0 : (totalSales / average).clamp(0.0, 2.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress > 1 ? 1 : progress, minHeight: 8),
        const SizedBox(height: 4),
        Text('المتوسط: ${average.toStringAsFixed(0)} د.ل'),
      ],
    );
  }
}

IconData _recommendationIcon(RecommendationType type) {
  switch (type) {
    case RecommendationType.issue:
      return Icons.warning_amber;
    case RecommendationType.opportunity:
      return Icons.insights;
    case RecommendationType.product:
      return Icons.shopping_basket;
    case RecommendationType.location:
      return Icons.place;
  }
}

Color _severityColor(Severity severity) {
  switch (severity) {
    case Severity.low:
      return Colors.green;
    case Severity.medium:
      return Colors.orange;
    case Severity.high:
      return Colors.red;
  }
}
