import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';

import '../services/company_server_service.dart';
import '../widgets/analytics_map_panel.dart';
import 'add_coupon_screen.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';
import 'community_screen.dart';

typedef BrandOffersLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandInvoicesLoader = Future<List<Map<String, dynamic>>> Function({int limit});
typedef BrandProfileLoader = Future<Map<String, dynamic>> Function();
typedef BrandProductsLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandCommunityLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandRewardsLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandReportsLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandAnalyticsLoader = Future<Map<String, dynamic>> Function();

class BrandDashboardScreen extends StatefulWidget {
  final bool embedded;
  final BrandOffersLoader? offersLoader;
  final BrandInvoicesLoader? invoicesLoader;
  final BrandProfileLoader? profileLoader;
  final BrandProductsLoader? productsLoader;
  final BrandCommunityLoader? communityLoader;
  final BrandRewardsLoader? rewardsLoader;
  final BrandReportsLoader? reportsLoader;
  final BrandAnalyticsLoader? analyticsLoader;

  const BrandDashboardScreen({
    super.key,
    this.embedded = false,
    this.offersLoader,
    this.invoicesLoader,
    this.profileLoader,
    this.productsLoader,
    this.communityLoader,
    this.rewardsLoader,
    this.reportsLoader,
    this.analyticsLoader,
  });

  const BrandDashboardScreen.embedded({
    super.key,
    this.offersLoader,
    this.invoicesLoader,
    this.profileLoader,
    this.productsLoader,
    this.communityLoader,
    this.rewardsLoader,
    this.reportsLoader,
    this.analyticsLoader,
  }) : embedded = true;

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
  int _brandTabIndex = 0;
  String? _error;
  String? _result;
  double? _currentPointValue;
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _brandProducts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _communityGroups = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _brandRewards = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _brandReports = <Map<String, dynamic>>[];
  Map<String, dynamic> _analytics = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _loadOffers() => widget.offersLoader != null
      ? widget.offersLoader!()
      : CompanyServerService.getOffers().catchError((_) => <Map<String, dynamic>>[]);

  Future<List<Map<String, dynamic>>> _loadInvoices() => widget.invoicesLoader != null
      ? widget.invoicesLoader!(limit: 20)
      : CompanyServerService.getMyInvoices(limit: 20).catchError((_) => <Map<String, dynamic>>[]);

  Future<Map<String, dynamic>> _loadProfile() => widget.profileLoader != null
      ? widget.profileLoader!()
      : CompanyServerService.getBrandProfile().catchError((_) => <String, dynamic>{});

  Future<List<Map<String, dynamic>>> _loadProducts() => widget.productsLoader != null
      ? widget.productsLoader!()
      : CompanyServerService.getBrandProducts().catchError((_) => <Map<String, dynamic>>[]);

  Future<List<Map<String, dynamic>>> _loadCommunityGroups() => widget.communityLoader != null
      ? widget.communityLoader!()
      : CompanyServerService.getGroups().catchError((_) => <Map<String, dynamic>>[]);

  Future<List<Map<String, dynamic>>> _loadBrandRewards() => widget.rewardsLoader != null
      ? widget.rewardsLoader!()
      : CompanyServerService.getBrandRewards().catchError((_) => <Map<String, dynamic>>[]);

  Future<List<Map<String, dynamic>>> _loadBrandReports() => widget.reportsLoader != null
      ? widget.reportsLoader!()
      : CompanyServerService.getBrandReportsInbox().catchError((_) => <Map<String, dynamic>>[]);

  Future<Map<String, dynamic>> _loadAnalytics() => widget.analyticsLoader != null
      ? widget.analyticsLoader!()
      : CompanyServerService.getBrandAnalytics().catchError((_) => <String, dynamic>{});

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
        _loadOffers(),
        _loadInvoices(),
        _loadProfile(),
        _loadProducts(),
        _loadAnalytics(),
        _loadCommunityGroups(),
        _loadBrandRewards(),
        _loadBrandReports(),
      ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(results[2] as Map<dynamic, dynamic>);
      final pointValueRaw = profile['pointValue'];
      final pointValue = pointValueRaw == null ? null : double.tryParse(pointValueRaw.toString());
      final rawAnalytics = results[4];
      final analytics = rawAnalytics is Map ? Map<String, dynamic>.from(rawAnalytics as Map<dynamic, dynamic>) : <String, dynamic>{};
      final loadedProducts = List<Map<String, dynamic>>.from(results[3] as List<dynamic>);
      final analyticsProducts = _listSectionFrom(analytics, 'topProducts');
      setState(() {
        _offers = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _invoices = List<Map<String, dynamic>>.from(results[1] as List<dynamic>);
        _brandProducts = loadedProducts.isEmpty ? analyticsProducts : loadedProducts;
        _analytics = analytics;
        _communityGroups = List<Map<String, dynamic>>.from(results[5] as List<dynamic>);
        _brandRewards = List<Map<String, dynamic>>.from(results[6] as List<dynamic>);
        _brandReports = List<Map<String, dynamic>>.from(results[7] as List<dynamic>);
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

    final tabs = <Widget>[
      _buildOverviewTab(),
      _buildAnalyticsTab(),
      _buildStoresTab(),
      _buildRewardsTab(),
      _buildOperationsTab(),
    ];

    return Column(
      children: [
        Expanded(child: tabs[_brandTabIndex]),
        NavigationBar(
          selectedIndex: _brandTabIndex,
          onDestinationSelected: (index) => setState(() => _brandTabIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'نظرة عامة'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'التحليلات'),
            NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'المتاجر'),
            NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard), label: 'المكافآت'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'الإدارة'),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('خريطة الذكاء الجغرافي'),
        _buildAnalyticsCard(),
      ],
    );
  }

  Widget _buildStoresTab() {
    final stores = _listSection('topSellingStores');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('متاجر مكتشفة تلقائياً'),
        ...stores.map((store) => Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined, color: Color(0xFF137A60)),
                title: Text((store['name'] ?? '-').toString()),
                subtitle: Text('مبيعات مؤكدة: ${_money(store['salesTotal'])} • الكمية: ${_intValue(store['quantity'])}'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _showStoreDetails(store),
              ),
            )),
        if (stores.isEmpty) const Text('لا توجد مبيعات مرتبطة بمتاجر حتى الآن.'),
      ],
    );
  }

  Widget _buildRewardsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('منتجات العلامة والمكافآت'),
        ..._brandRewards.map((reward) => Card(
              child: ListTile(
                leading: (reward['imageUrl'] ?? '').toString().isEmpty
                    ? const Icon(Icons.emoji_events_outlined, color: Color(0xFFE68A00))
                    : Image.network((reward['imageUrl'] ?? '').toString(), width: 48, height: 48, fit: BoxFit.cover),
                title: Text((reward['reward_name'] ?? '-').toString()),
                subtitle: Text('${reward['value'] ?? 0} نقطة • ${reward['kind'] ?? 'physical'}${reward['expiresAt'] == null ? '' : ' • ينتهي ${reward['expiresAt']}'}'),
                trailing: Text('${reward['quantityRedeemed'] ?? 0}/${reward['quantityLimit'] ?? '∞'}'),
                onTap: reward['drawEnabled'] == true && reward['drawWinnerUserId'] == null
                    ? () async {
                        try {
                          await CompanyServerService.drawBrandReward((reward['id'] ?? '').toString());
                          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنفيذ السحب وإرسال إشعار للفائز'))); await _load(); }
                        } catch (error) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكن تنفيذ السحب: $error')));
                        }
                      }
                    : null,
              ),
            )),
        ..._brandProducts.map((reward) => Card(
              child: ListTile(
                leading: const Icon(Icons.card_giftcard_outlined, color: Color(0xFF6C63FF)),
                title: Text((reward['name'] ?? '-').toString()),
                subtitle: Text('SKU: ${(reward['barcode'] ?? '-').toString()}'),
                trailing: const Icon(Icons.chevron_left),
              ),
            )),
        if (_brandProducts.isEmpty) const Text('لا توجد منتجات مسجلة لهذه العلامة حتى الآن.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showCreateProductDialog,
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('إضافة منتج للعلامة'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _showCreateRewardDialog,
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('إضافة جائزة ونقاط الوصول'),
        ),
      ],
    );
  }

  Widget _buildOperationsTab() {
    final alerts = _buildSalesAlerts();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('تنبيهات المبيعات'),
        if (alerts.isEmpty) const Text('لا توجد تنبيهات مبيعات في الفترة الحالية.') else ...alerts,
        const SizedBox(height: 12),
        _sectionHeader('بلاغات الجودة'),
        if (_brandReports.isEmpty) const Text('لا توجد بلاغات مرتبطة بهذه العلامة حالياً.') else ..._brandReports.map(_buildReportCard),
        ExpansionTile(
          title: const Text('مجتمع العلامة والمحتوى المستهدف'),
          leading: const Icon(Icons.groups_outlined, color: Color(0xFF2F80ED)),
          children: _communityGroups.isEmpty
              ? const [ListTile(title: Text('لا توجد مجموعات مرتبطة بهذا الحساب حالياً.'))]
                : _communityGroups.map((group) => ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text((group['name'] ?? '-').toString()),
                    subtitle: Text('${group['members'] ?? 0} عضو'),
                  trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityScreen(initialGroupId: (group['id'] ?? '').toString()))),
                  )).toList(growable: false),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: Text('brand_set_point_value'.tr()),
          subtitle: Text('brand_current_value'.tr(namedArgs: {'value': _currentPointValue?.toString() ?? '-'})),
          childrenPadding: const EdgeInsets.all(12),
          children: [
            TextField(controller: _pointValueController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'brand_point_value'.tr())),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _savingPointValue ? null : _savePointValue, child: Text('save'.tr())),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildSalesAlerts() {
    final alerts = <Widget>[];
    for (final row in _listSection('growthLevels')) {
      final growth = _toDouble(row['growthPercent']);
      if (growth >= 0) continue;
      alerts.add(Card(color: const Color(0xFFFFF3F0), child: ListTile(leading: const Icon(Icons.trending_down, color: Colors.red), title: Text('انخفاض المبيعات: ${(row['label'] ?? '-').toString()}'), subtitle: Text('انخفضت المبيعات بنسبة ${_money(growth.abs())}% مقارنة بالفترة السابقة.'))));
    }
    return alerts;
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final mapPoint = <String, dynamic>{'label': report['storeName'] ?? 'موقع البلاغ', 'latitude': report['storeLat'], 'longitude': report['storeLng'], 'value': report['reportType'] ?? 'بلاغ'};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.report_problem_outlined, color: Color(0xFFE67E22)), const SizedBox(width: 8), Expanded(child: Text((report['reportType'] ?? 'بلاغ جودة').toString(), style: const TextStyle(fontWeight: FontWeight.bold))), Text((report['status'] ?? 'new').toString())]),
          const SizedBox(height: 6),
          Text('المبلغ: ${(report['reporterName'] ?? report['reporterEmail'] ?? '-').toString()}'),
          Text('المحل: ${(report['storeName'] ?? 'غير محدد').toString()}'),
          Text((report['description'] ?? 'بدون وصف').toString()),
          if ((report['storePhone'] ?? '').toString().isNotEmpty) Text('الهاتف: ${report['storePhone']}'),
          if ((report['storeAddress'] ?? '').toString().isNotEmpty) Text('الموقع: ${report['storeAddress']}'),
          if (report['storeLat'] != null && report['storeLng'] != null) ...[const SizedBox(height: 8), AnalyticsMapPanel(points: [mapPoint], emptyLabel: 'لا يوجد موقع للبلاغ', markerColor: Colors.orange)],
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if ((report['ownerId'] ?? '').toString().isNotEmpty) OutlinedButton.icon(onPressed: () => _showMessageDialog({'userId': report['ownerId'], 'name': report['reporterName'] ?? 'المبلغ'}), icon: const Icon(Icons.mail_outline), label: const Text('رسالة للمبلغ')),
            if ((report['storeUserId'] ?? '').toString().isNotEmpty) OutlinedButton.icon(onPressed: () => _showMessageDialog({'userId': report['storeUserId'], 'name': report['storeName'] ?? 'المحل'}), icon: const Icon(Icons.storefront_outlined), label: const Text('رسالة للمحل')),
            if (report['status'] == 'new') ElevatedButton.icon(onPressed: () => _resolveReport(report), icon: const Icon(Icons.stars_outlined), label: const Text('قبول ومنح نقاط')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _resolveReport(Map<String, dynamic> report) async {
    await CompanyServerService.resolveBrandReport((report['id'] ?? '').toString(), grantReward: true, rewardPoints: 10, resolutionNote: 'تمت مراجعة البلاغ من العلامة.');
    await _load();
  }

  Widget _buildOverviewTab() {
    final stores = _listSection('topSellingStores');
    final products = _listSection('topProducts');
    final growth = _listSection('growthLevels');
    final dailySales = _listSection('dailySales');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('لوحة العلامة التجارية', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('ملخص مباشر لأداء العلامة والمتاجر والمنتجات المرتبطة.'),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _metricCard(icon: Icons.storefront_outlined, title: 'متاجر', value: '${stores.length}', subtitle: 'مرتبطة بالمبيعات', color: const Color(0xFF1C7F6B)),
              _metricCard(icon: Icons.inventory_2_outlined, title: 'منتجات', value: '${products.length}', subtitle: 'في التحليل', color: const Color(0xFF5A5FE0)),
              _metricCard(icon: Icons.people_outline, title: 'عملاء', value: '${_intValue(_analytics['matchedCustomers'])}', subtitle: 'متطابقون', color: const Color(0xFF2E80ED)),
              _metricCard(icon: Icons.payments_outlined, title: 'المبيعات', value: _money(_analytics['matchedSales']), subtitle: 'إجمالي مطابق', color: const Color(0xFFE68A00)),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader('أداء العلامة'),
          _buildSalesChart(stores, products),
          const SizedBox(height: 16),
          _buildDailySalesChart(dailySales),
          const SizedBox(height: 12),
          if (growth.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.trending_up, color: Color(0xFF1B7A66)), title: const Text('نمو المبيعات'), subtitle: Text('${_money(growth.first['growthPercent'])}% مقارنة بالفترة السابقة'))),
        ],
      ),
    );
  }

  Widget _buildLegacyOverviewTab() {
    final merchantDirectory = <Map<String, dynamic>>[
      <String, dynamic>{'name': 'سوبرماركت المدينة', 'city': 'طرابلس', 'tier': 'ذهبي', 'volume': '1450', 'trend': '+18%'},
      <String, dynamic>{'name': 'محل السلام', 'city': 'زليتن', 'tier': 'فضي', 'volume': '860', 'trend': '-12%'},
      <String, dynamic>{'name': 'سوبرماركت النخلة', 'city': 'بنغازي', 'tier': 'جديد', 'volume': '620', 'trend': '+32%'},
    ];

    final salesAlerts = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'Sales Drop Alert',
        'merchant': 'محل السلام - زليتن',
        'detail': 'انخفضت مبيعات صابون لميس بنسبة 40% خلال آخر 30 يومًا.',
        'severity': 'High',
      },
      <String, dynamic>{
        'title': 'New Merchant Discovery',
        'merchant': 'سوبرماركت النخلة - بنغازي',
        'detail': 'تم اكتشاف متجر جديد عبر 15 فاتورة خلال هذا الأسبوع.',
        'severity': 'Normal',
      },
    ];

    final skuRewards = <Map<String, dynamic>>[
      <String, dynamic>{'product': 'عصير النسيم 1L', 'barcode': '123456789012', 'points': 10},
      <String, dynamic>{'product': 'صندوق عصير النسيم', 'barcode': '123456789013', 'points': 150},
      <String, dynamic>{'product': 'صابون لميس 200g', 'barcode': '123456789014', 'points': 25},
    ];

    final qualityAlerts = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'تقرير منتج تالف',
        'store': 'متجر المدينة',
        'detail': 'تم رفع شكوى من منتج منتهي الصلاحية مع صورة إيصال.',
        'batch': 'B-2048',
      },
      <String, dynamic>{
        'title': 'تقرير طعم متغير',
        'store': 'سوبرماركت النخلة',
        'detail': 'تم رصد ملاحظات من الزبائن بشأن اختلاف الطعم في دفعة جديدة.',
        'batch': 'B-2054',
      },
    ];

    final communityPosts = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'استطلاع النكهة القادمة',
        'detail': 'ما النكهة المفضلة في المنتج القادم؟',
        'tag': 'Poll',
      },
      <String, dynamic>{
        'title': 'حملة طرابلس',
        'detail': 'اشترِ منتجين من النسيم واحصل على نقاط مضاعفة اليوم.',
        'tag': 'Geo Push',
      },
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4ED),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFCFE8DA), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'لوحة العلامة التجارية',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F3D38),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B7A66),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Live',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'المبيعات المتطابقة: ${_money(_analytics['matchedSales'])} • الزبائن: ${_intValue(_analytics['matchedCustomers'])}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _metricCard(icon: Icons.storefront_outlined, title: 'متاجر', value: '${merchantDirectory.length}', subtitle: 'مكتشفة', color: const Color(0xFF1C7F6B)),
                      _metricCard(icon: Icons.trending_up_rounded, title: 'تنبيهات', value: '${salesAlerts.length}', subtitle: 'مبيعات', color: const Color(0xFFE68A00)),
                      _metricCard(icon: Icons.card_giftcard_rounded, title: 'مكافآت', value: '${skuRewards.length}', subtitle: 'منتجات', color: const Color(0xFF5A5FE0)),
                      _metricCard(icon: Icons.groups_rounded, title: 'مجتمع', value: '${communityPosts.length}', subtitle: 'نشط', color: const Color(0xFF2E80ED)),
                    ],
                  ),
                ],
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
            _sectionHeader('خريطة الذكاء الجغرافي'),
            _buildAnalyticsCard(),
            const SizedBox(height: 12),
            _sectionHeader('متاجر مكتشفة تلقائياً'),
            ...merchantDirectory.map((store) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined, color: Color(0xFF137A60)),
                    title: Text((store['name'] ?? '').toString()),
                    subtitle: Text('${store['city']} • ${store['tier']} tier • ${store['trend']} sales trend'),
                    trailing: Text('${store['volume']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )),
            const SizedBox(height: 12),
            _sectionHeader('تنبيهات المبيعات'),
            ...salesAlerts.map((alert) => Card(
                  color: (alert['severity'] == 'High') ? const Color(0xFFFFF3F0) : const Color(0xFFF3F9FF),
                  child: ListTile(
                    leading: Icon(
                      (alert['severity'] == 'High') ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: (alert['severity'] == 'High') ? Colors.red : Colors.green,
                    ),
                    title: Text((alert['title'] ?? '').toString()),
                    subtitle: Text('${alert['merchant']}\n${alert['detail']}'),
                  ),
                )),
            const SizedBox(height: 12),
            _sectionHeader('مكافآت المنتجات والسحوبات'),
            ...skuRewards.map((reward) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard_outlined, color: Color(0xFF6C63FF)),
                    title: Text('${reward['product']}'),
                    subtitle: Text('SKU: ${reward['barcode']}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDE7FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${reward['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            _sectionHeader('الجودة'),
            const SizedBox(height: 4),
            Text('إدارة البلاغات وجودة المنتج', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            ...qualityAlerts.map((alert) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.report_problem_outlined, color: Color(0xFFE67E22)),
                    title: Text((alert['title'] ?? '').toString()),
                    subtitle: Text('${alert['store']}\nBatch: ${alert['batch']}\n${alert['detail']}'),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Goodwill'),
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            _sectionHeader('مجتمع العلامة والمحتوى المستهدف'),
            ...communityPosts.map((post) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_outlined, color: Color(0xFF2F80ED)),
                    title: Text((post['title'] ?? '').toString()),
                    subtitle: Text((post['detail'] ?? '').toString()),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text((post['tag'] ?? '').toString()),
                    ),
                  ),
                )),
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text('billboard_create_ad'.tr()),
                subtitle: Text('billboard_create_ad_hint'.tr()),
                trailing: const Icon(Icons.chevron_left),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddCouponScreen()),
                  );
                },
              ),
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
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF5B5F66), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF18222F)),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _miniStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 14),
            _buildAnalyticsCharts(topStores, lowStores, topProducts, growthLevels, genders, ages),
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
    return _listSectionFrom(_analytics, key);
  }

  List<Map<String, dynamic>> _listSectionFrom(Map<String, dynamic> source, String key) {
    final raw = source[key];
    if (raw is List) {
      return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Widget _buildSalesChart(List<Map<String, dynamic>> stores, List<Map<String, dynamic>> products) {
    final entries = stores.take(5).toList(growable: false);
    final maxValue = entries.fold<double>(0, (max, row) => max > _toDouble(row['salesTotal']) ? max : _toDouble(row['salesTotal']));
    if (entries.isEmpty || maxValue <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مقارنة المبيعات حسب المتجر', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: BarChart(
            BarChartData(
              maxY: maxValue * 1.2,
              minY: 0,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                      final name = (entries[index]['name'] ?? '-').toString();
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)));
                    },
                  ),
                ),
              ),
              barGroups: List<BarChartGroupData>.generate(entries.length, (index) {
                return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: _toDouble(entries[index]['salesTotal']), color: const Color(0xFF1B7A66), width: 18, borderRadius: BorderRadius.circular(4))]);
              }),
            ),
          ),
        ),
        if (products.isNotEmpty)
          Text('أفضل منتج: ${(products.first['name'] ?? '-').toString()} • ${_money(products.first['salesTotal'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAnalyticsCharts(
    List<Map<String, dynamic>> topStores,
    List<Map<String, dynamic>> lowStores,
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> growth,
    List<Map<String, dynamic>> genders,
    List<Map<String, dynamic>> ages,
  ) {
    final dailySales = _listSection('dailySales');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSalesChart(topStores, products),
        const SizedBox(height: 18),
        _buildDailySalesChart(dailySales),
        const SizedBox(height: 18),
        _buildMetricBarChart('الأقل مبيعاً حسب المتجر', lowStores, const Color(0xFFE68A00)),
        const SizedBox(height: 18),
        if (products.isNotEmpty) _buildProductChart(products),
        if (growth.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildGrowthChart(growth),
        ],
        if (genders.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildGenderChart(genders),
        ],
        if (ages.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildDistributionChart('توزيع العملاء حسب العمر', ages, const Color(0xFF2E80ED)),
        ],
      ],
    );
  }

  Widget _buildMetricBarChart(String title, List<Map<String, dynamic>> rows, Color color) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxValue = rows.fold<double>(0, (max, row) => max > _toDouble(row['salesTotal']) ? max : _toDouble(row['salesTotal']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: BarChart(BarChartData(
            maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) return const SizedBox.shrink();
                return Text((rows[index]['name'] ?? '-').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9));
              })),
            ),
            barGroups: List<BarChartGroupData>.generate(rows.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: _toDouble(rows[index]['salesTotal']), color: color, width: 18, borderRadius: BorderRadius.circular(4))])),
          )),
        ),
      ],
    );
  }

  Widget _buildProductChart(List<Map<String, dynamic>> products) {
    final rows = products.take(6).toList(growable: false);
    final maxValue = rows.fold<double>(0, (max, row) => max > _toDouble(row['salesTotal']) ? max : _toDouble(row['salesTotal']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مبيعات المنتجات', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: BarChart(BarChartData(
            maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) return const SizedBox.shrink();
                return Text((rows[index]['name'] ?? '-').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9));
              })),
            ),
            barGroups: List<BarChartGroupData>.generate(rows.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: _toDouble(rows[index]['salesTotal']), color: const Color(0xFF5A5FE0), width: 18, borderRadius: BorderRadius.circular(4))])),
          )),
        ),
      ],
    );
  }

  Widget _buildGrowthChart(List<Map<String, dynamic>> growth) {
    final rows = growth.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('معدل النمو', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: BarChart(BarChartData(
            minY: 0,
            maxY: rows.fold<double>(0, (max, row) => [max, _toDouble(row['current']), _toDouble(row['previous'])].reduce((a, b) => a > b ? a : b)) * 1.2,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) return const SizedBox.shrink();
                return Text((rows[index]['level'] ?? '-').toString(), style: const TextStyle(fontSize: 9));
              })),
            ),
            barGroups: List<BarChartGroupData>.generate(rows.length, (index) => BarChartGroupData(x: index, barsSpace: 4, barRods: [
              BarChartRodData(toY: _toDouble(rows[index]['current']), color: const Color(0xFF1B7A66), width: 9, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: _toDouble(rows[index]['previous']), color: const Color(0xFFB9C4CE), width: 9, borderRadius: BorderRadius.circular(3)),
            ])),
          )),
        ),
      ],
    );
  }

  Widget _buildDailySalesChart(List<Map<String, dynamic>> dailySales) {
    if (dailySales.isEmpty) return const SizedBox.shrink();
    final rows = dailySales.take(31).toList(growable: false);
    final maxValue = rows.fold<double>(0, (max, row) => max > _toDouble(row['sales']) ? max : _toDouble(row['sales']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('المبيعات منذ أول ظهور في الفترة المحددة', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: LineChart(LineChartData(
            minY: 0,
            maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: rows.length > 10 ? 5 : 1, getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) return const SizedBox.shrink();
                return Text((rows[index]['date'] ?? '').toString().substring(5), style: const TextStyle(fontSize: 9));
              })),
            ),
            lineBarsData: [LineChartBarData(isCurved: true, color: const Color(0xFF2E80ED), barWidth: 3, dotData: const FlDotData(show: false), spots: List<FlSpot>.generate(rows.length, (index) => FlSpot(index.toDouble(), _toDouble(rows[index]['sales']))))],
          )),
        ),
      ],
    );
  }

  Widget _buildGenderChart(List<Map<String, dynamic>> genders) {
    return _buildDistributionChart('توزيع العملاء حسب النوع', genders, const Color(0xFF5A5FE0));
  }

  Widget _buildDistributionChart(String title, List<Map<String, dynamic>> rows, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: PieChart(PieChartData(sections: List<PieChartSectionData>.generate(rows.length, (index) => PieChartSectionData(value: _toDouble(rows[index]['value']), color: Color.lerp(color, Colors.white, index / (rows.length + 1)), title: '${rows[index]['label']}', radius: 70, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))))),
        ),
      ],
    );
  }

  Future<void> _showStoreDetails(Map<String, dynamic> store) async {
    final growth = _listSection('growthLevels').firstWhere((row) => (row['label'] ?? '').toString() == (store['name'] ?? '').toString(), orElse: () => <String, dynamic>{});
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text((store['name'] ?? '-').toString()),
        content: Text('المبيعات: ${_money(store['salesTotal'])}\nالكمية: ${_intValue(store['quantity'])}\nالنمو: ${_money(growth['growthPercent'])}%\nالهاتف: ${(store['phone'] ?? 'غير متوفر').toString()}\nالعنوان: ${(store['address'] ?? 'غير متوفر').toString()}'),
        actions: [
          if ((store['userId'] ?? '').toString().isNotEmpty) TextButton(onPressed: () => _showMessageDialog(store), child: const Text('إرسال رسالة')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _showMessageDialog(Map<String, dynamic> store) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رسالة إلى ${(store['name'] ?? 'المتجر').toString()}'),
        content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'نص الرسالة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              try {
                final chat = await CompanyServerService.createPrivateChat(targetUserId: (store['userId'] ?? '').toString(), title: 'تواصل مع ${store['name']}');
                await CompanyServerService.sendPrivateMessage(chatId: (chat['id'] ?? chat['chatId'] ?? '').toString(), text: text);
                if (context.mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة')));
              } catch (error) {
                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $error')));
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showCreateProductDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة منتج للعلامة'),
        content: TextField(controller: _productNameController, decoration: const InputDecoration(labelText: 'اسم المنتج')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createProduct();
              await _load();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateRewardDialog() async {
    final name = TextEditingController();
    final points = TextEditingController();
    final description = TextEditingController();
    final pickup = TextEditingController();
    final quantity = TextEditingController();
    String kind = 'physical';
    bool drawEnabled = false;
    DateTime? expiresAt;
    XFile? image;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('إضافة جائزة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الجائزة')),
          TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد النقاط المطلوبة')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'وصف الجائزة')),
          TextField(controller: pickup, decoration: const InputDecoration(labelText: 'أين وكيف يتم الاستلام؟')),
          TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الجوائز (اختياري)')),
          DropdownButtonFormField<String>(value: kind, decoration: const InputDecoration(labelText: 'نوع الجائزة'), items: const [DropdownMenuItem(value: 'physical', child: Text('استلام مباشر')), DropdownMenuItem(value: 'digital', child: Text('رقمية'))], onChanged: (value) => setDialogState(() => kind = value ?? 'physical')),
          SwitchListTile(title: const Text('سحب عشوائي عند انتهاء المدة'), value: drawEnabled, onChanged: (value) => setDialogState(() => drawEnabled = value)),
          ListTile(contentPadding: EdgeInsets.zero, title: Text(expiresAt == null ? 'تحديد مدة الجائزة' : 'تنتهي في ${expiresAt!.toLocal().toString().split(' ').first}'), trailing: const Icon(Icons.event_outlined), onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 30))); if (picked != null) setDialogState(() => expiresAt = picked); }),
          OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickImage(source: ImageSource.gallery); if (picked != null) setDialogState(() => image = picked); }, icon: const Icon(Icons.photo_library_outlined), label: Text(image == null ? 'اختيار صورة' : 'تم اختيار الصورة')),
          OutlinedButton.icon(onPressed: () async { final picked = await ImagePicker().pickImage(source: ImageSource.camera); if (picked != null) setDialogState(() => image = picked); }, icon: const Icon(Icons.camera_alt_outlined), label: const Text('التقاط صورة بالكاميرا')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () async {
            final cost = int.tryParse(points.text.trim());
            if (name.text.trim().isEmpty || cost == null || cost <= 0) return;
            String? imageUrl;
            if (image != null) imageUrl = await CompanyServerService.uploadImageBytes(await image!.readAsBytes());
            await CompanyServerService.createBrandReward(rewardName: name.text.trim(), points: cost, description: description.text.trim(), imageUrl: imageUrl, kind: kind, expiresAt: expiresAt, quantityLimit: int.tryParse(quantity.text.trim()), pickupInstructions: pickup.text.trim(), drawEnabled: drawEnabled, drawAt: expiresAt);
            if (context.mounted) Navigator.pop(context);
            await _load();
          }, child: const Text('حفظ الجائزة')),
        ],
      )),
    );
    name.dispose(); points.dispose(); description.dispose(); pickup.dispose(); quantity.dispose();
  }

  double _toDouble(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

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
      appBar: AppBar(
        title: const Text('لوحة العلامة التجارية'),
        backgroundColor: const Color(0xFF1E5F55),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }
}
