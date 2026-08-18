import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/company_server_service.dart';
import '../widgets/analytics_map_panel.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';

class BrandDashboardScreen extends StatefulWidget {
  final bool embedded;

  const BrandDashboardScreen({super.key, this.embedded = false});

  const BrandDashboardScreen.embedded({super.key}) : embedded = true;

  @override
  State<BrandDashboardScreen> createState() => _BrandDashboardScreenState();
}

class _BrandDashboardScreenState extends State<BrandDashboardScreen> {
  final TextEditingController _teamUserIdController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productImageController = TextEditingController();
  final TextEditingController _productBarcodeController = TextEditingController();
  final TextEditingController _pointValueController = TextEditingController();

  bool _canManageProducts = false;
  bool _canViewGeoDistribution = false;
  bool _loading = true;
  bool _savingPointValue = false;
  String? _error;
  String? _result;
  double? _currentPointValue;
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  Map<String, dynamic> _analytics = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _teamUserIdController.dispose();
    _productNameController.dispose();
    _productImageController.dispose();
    _productBarcodeController.dispose();
    _pointValueController.dispose();
    super.dispose();
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        CompanyServerService.getOffers(),
        CompanyServerService.getMyInvoices(limit: 20),
        CompanyServerService.getBrandProfile(),
        CompanyServerService.getBrandAnalytics().catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(results[2] as Map<dynamic, dynamic>);
      final pointValueRaw = profile['pointValue'];
      final pointValue = pointValueRaw == null ? null : double.tryParse(pointValueRaw.toString());
      final rawAnalytics = results[3];
      setState(() {
        _offers = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _invoices = List<Map<String, dynamic>>.from(results[1] as List<dynamic>);
        _analytics = rawAnalytics is Map ? Map<String, dynamic>.from(rawAnalytics as Map<dynamic, dynamic>) : const <String, dynamic>{};
        _currentPointValue = pointValue;
        _pointValueController.text = pointValue == null ? '' : pointValue.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _savePointValue() async {
    final pointValue = double.tryParse(_pointValueController.text.trim());
    if (pointValue == null || pointValue <= 0) {
      setState(() {
        _result = 'brand_point_value_invalid'.tr();
      });
      return;
    }

    setState(() {
      _savingPointValue = true;
      _result = null;
    });

    try {
      final data = await CompanyServerService.setBrandPointValue(pointValue: pointValue);
      final updated = double.tryParse((data['pointValue'] ?? pointValue).toString()) ?? pointValue;
      if (!mounted) return;
      setState(() {
        _currentPointValue = updated;
        _pointValueController.text = updated.toString();
        _result = 'brand_point_value_saved'.tr(namedArgs: {'value': updated.toString()});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPointValue = false;
        });
      }
    }
  }

  Future<void> _addTeamMember() async {
    try {
      await CompanyServerService.addBrandTeamMember(
        userId: _teamUserIdController.text.trim(),
        canManageProducts: _canManageProducts,
        canViewGeoDistribution: _canViewGeoDistribution,
      );
      setState(() {
        _result = 'brand_team_permissions_saved'.tr();
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Future<void> _createProduct() async {
    if (_productNameController.text.trim().isEmpty) return;
    try {
      final created = await CompanyServerService.createBrandProduct(
        name: _productNameController.text.trim(),
        imageUrl: _productImageController.text.trim(),
        barcode: _productBarcodeController.text.trim(),
      );
      setState(() {
        _result = 'brand_product_created'.tr(namedArgs: {'id': '${created['id'] ?? ''}'});
      });
      _productNameController.clear();
      _productImageController.clear();
      _productBarcodeController.clear();
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text('brand_summary'.tr()),
              subtitle: Text('brand_summary_counts'.tr(namedArgs: {
                'offers': '${_offers.length}',
                'invoices': '${_invoices.length}',
              })),
              trailing: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_result!, style: const TextStyle(color: Colors.green)),
            ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: Text('brand_set_point_value'.tr()),
            subtitle: Text('brand_current_value'.tr(namedArgs: {'value': _currentPointValue?.toString() ?? '-'})),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _pointValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'brand_point_value_label'.tr(),
                  helperText: 'brand_point_value_helper'.tr(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _savingPointValue ? null : _savePointValue,
                child: Text(_savingPointValue ? 'brand_saving'.tr() : 'brand_save_point_value'.tr()),
              ),
            ],
          ),
          ExpansionTile(
            title: Text('brand_point_conversion_values'.tr()),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              Text('brand_point_conversion_help'.tr()),
            ],
          ),
          ExpansionTile(
            title: Text('brand_team_permissions'.tr()),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _teamUserIdController,
                decoration: InputDecoration(labelText: 'brand_user_id'.tr()),
              ),
              SwitchListTile(
                value: _canManageProducts,
                title: Text('brand_can_manage_products'.tr()),
                onChanged: (value) => setState(() => _canManageProducts = value),
              ),
              SwitchListTile(
                value: _canViewGeoDistribution,
                title: Text('brand_can_view_geo_distribution'.tr()),
                onChanged: (value) => setState(() => _canViewGeoDistribution = value),
              ),
              ElevatedButton(onPressed: _addTeamMember, child: Text('brand_save_team_member'.tr())),
            ],
          ),
          ExpansionTile(
            title: Text('brand_create_product_registry'.tr()),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _productNameController,
                decoration: InputDecoration(labelText: 'brand_product_name'.tr()),
              ),
              TextField(
                controller: _productImageController,
                decoration: InputDecoration(labelText: 'brand_image_url_optional'.tr()),
              ),
              TextField(
                controller: _productBarcodeController,
                decoration: InputDecoration(labelText: 'brand_barcode_optional'.tr()),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _createProduct, child: Text('brand_create_product'.tr())),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PointsConversionScreen()),
                  );
                },
                child: Text('brand_points_conversion'.tr()),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RewardQrCodeScreen()),
                  );
                },
                child: Text('brand_create_reward_qr'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(),
          const SizedBox(height: 12),
          Text('brand_latest_offers'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ..._offers.take(8).map((offer) => Card(
                child: ListTile(
                  title: Text((offer['description'] ?? 'offer'.tr()).toString()),
                  subtitle: Text('brand_offer_category_type'.tr(namedArgs: {
                    'category': '${offer['category'] ?? '-'}',
                    'type': '${offer['offerType'] ?? '-'}',
                  })),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    final heatmap = _listSection('distributionHeatmap');
    final topStores = _listSection('topSellingStores');
    final lowStores = _listSection('lowestSellingStores');
    final growthLevels = _listSection('growthLevels');
    final topProducts = _listSection('topProducts');
    final demographics = _mapSection('consumerDemographics');
    final genders = _nestedListSection(demographics, 'gender');
    final ages = _nestedListSection(demographics, 'ageBuckets');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tx('brand_analytics_title', 'Brand analytics'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              _tx('brand_analytics_matched_sales_consumers', 'Matched sales: {sales} | Consumers: {consumers}')
                  .replaceAll('{sales}', _money(_analytics['matchedSales']))
                  .replaceAll('{consumers}', '${_intValue(_analytics['matchedCustomers'])}'),
            ),
            const SizedBox(height: 12),
            Text(_tx('brand_analytics_heatmap_title', 'Heatmap distribution')),
            const SizedBox(height: 6),
            AnalyticsMapPanel(
              points: heatmap,
              emptyLabel: _tx('brand_analytics_heatmap_empty', 'No sales locations linked to this brand right now.'),
              markerColor: Colors.redAccent,
            ),
            const SizedBox(height: 10),
            _buildAnalyticsList(_tx('brand_analytics_top_selling_stores', 'Top selling stores'), topStores.map((row) => '${(row['name'] ?? '-').toString()} • ${_money(row['salesTotal'])} • ${_intValue(row['quantity'])}').toList(growable: false)),
            _buildAnalyticsList(_tx('brand_analytics_lowest_selling_stores', 'Lowest selling stores'), lowStores.map((row) => '${(row['name'] ?? '-').toString()} • ${_money(row['salesTotal'])} • ${_intValue(row['quantity'])}').toList(growable: false)),
            _buildAnalyticsList(_tx('brand_analytics_top_products', 'Top products'), topProducts.map((row) => '${(row['name'] ?? '-').toString()} • ${_money(row['salesTotal'])}').toList(growable: false)),
            _buildAnalyticsList(
              _tx('brand_analytics_growth_rate', 'Growth rate ((current - previous) / previous) x 100%'),
              growthLevels
                  .map((row) => _tx('brand_analytics_growth_line', '{label} | current {current} | previous {previous} | {growth}%')
                      .replaceAll('{label}', (row['label'] ?? row['level'] ?? '-').toString())
                      .replaceAll('{current}', _money(row['current']))
                      .replaceAll('{previous}', _money(row['previous']))
                      .replaceAll('{growth}', _money(row['growthPercent'])))
                  .toList(growable: false),
            ),
            _buildAnalyticsList(_tx('brand_analytics_demographics', 'Consumer demographics'), <String>[
              _tx('brand_analytics_gender_line', 'Gender: {value}').replaceAll('{value}', _formatCounts(genders)),
              _tx('brand_analytics_age_line', 'Age: {value}').replaceAll('{value}', _formatCounts(ages)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsList(String title, List<String> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Text(_tx('brand_analytics_empty', 'No data in the current range.'))
          else
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(row),
                )),
        ],
      ),
    );
  }

  Map<String, dynamic> _mapSection(String key) {
    final raw = _analytics[key];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listSection(String key) {
    final raw = _analytics[key];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _nestedListSection(Map<String, dynamic> source, String key) {
    final raw = source[key];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _formatCounts(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '-';
    return rows.map((row) => '${(row['label'] ?? '-').toString()}: ${_intValue(row['value'])}').join(' | ');
  }

  String _money(dynamic value) {
    final parsed = double.tryParse('${value ?? 0}') ?? 0;
    return parsed.toStringAsFixed(2);
  }

  int _intValue(dynamic value) {
    return int.tryParse('${value ?? 0}') ?? (double.tryParse('${value ?? 0}')?.round() ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      appBar: AppBar(title: Text('brand_dashboard_title'.tr())),
      body: _buildBody(),
    );
  }
}
