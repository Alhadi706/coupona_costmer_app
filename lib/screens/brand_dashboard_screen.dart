import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/company_server_service.dart';
import '../services/export_download.dart';
import '../widgets/brand_analytics_charts.dart';
import '../widgets/analytics_map_panel.dart';
import '../widgets/brand_product_catalog.dart';
import '../widgets/reward_creation_dialog.dart';
import '../widgets/reward_funding_card.dart';
export '../widgets/brand_product_catalog.dart' show BrandProductCreator, BrandProductUpdater, BrandProductDeactivator, BrandProductImageSelector, BrandProductBarcodeSelector;
import 'add_coupon_screen.dart';
import 'merchant_campaign_screen.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';
import 'community_screen.dart';
import 'brand_network_screens.dart';
import 'brand_team_screen.dart';
import 'public_coalition_membership_screen.dart';

typedef BrandOffersLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandInvoicesLoader = Future<List<Map<String, dynamic>>> Function({int limit});
typedef BrandProfileLoader = Future<Map<String, dynamic>> Function();
typedef BrandProductsLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandCommunityLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandRewardsLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandReportsLoader = Future<List<Map<String, dynamic>>> Function();
typedef BrandAnalyticsLoader = Future<Map<String, dynamic>> Function();
typedef BrandAnalyticsRangeLoader = Future<Map<String, dynamic>> Function(String range);
typedef BrandAnalyticsFilterLoader = Future<Map<String, dynamic>> Function({required String range, String? storeId, String? product, String? region});
typedef BrandWalletLoader = Future<Map<String, dynamic>> Function();
typedef BrandRewardUpdater = Future<Map<String, dynamic>> Function(String rewardId, {bool? isActive, int? quantityLimit, DateTime? expiresAt, String? description});
typedef BrandRewardClaimsLoader = Future<List<Map<String, dynamic>>> Function();

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
  final BrandAnalyticsRangeLoader? analyticsRangeLoader;
  final BrandAnalyticsFilterLoader? analyticsFilterLoader;
  final BrandWalletLoader? walletLoader;
  final BrandWalletLoader? pendingPointsLoader;
  final BrandRewardUpdater? rewardUpdater;
  final RewardFundingLoader? rewardFundingLoader;
  final RewardFunder? rewardFunder;
  final BrandRewardClaimsLoader? rewardClaimsLoader;
  final BrandProductCreator? productCreator;
  final BrandProductUpdater? productUpdater;
  final BrandProductDeactivator? productDeactivator;
  final BrandProductImageSelector? productImageSelector;
  final BrandProductBarcodeSelector? productBarcodeSelector;

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
    this.analyticsRangeLoader,
    this.analyticsFilterLoader,
    this.walletLoader,
    this.pendingPointsLoader,
    this.rewardUpdater,
    this.rewardFundingLoader,
    this.rewardFunder,
    this.rewardClaimsLoader,
    this.productCreator,
    this.productUpdater,
    this.productDeactivator,
    this.productImageSelector,
    this.productBarcodeSelector,
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
    this.analyticsRangeLoader,
    this.analyticsFilterLoader,
    this.walletLoader,
    this.pendingPointsLoader,
    this.rewardUpdater,
    this.rewardFundingLoader,
    this.rewardFunder,
    this.rewardClaimsLoader,
    this.productCreator,
    this.productUpdater,
    this.productDeactivator,
    this.productImageSelector,
    this.productBarcodeSelector,
  }) : embedded = true;

  @override
  State<BrandDashboardScreen> createState() => _BrandDashboardScreenState();
}

class _BrandDashboardScreenState extends State<BrandDashboardScreen> {
  final TextEditingController _teamUserIdController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productImageController = TextEditingController();
  final TextEditingController _productBarcodeController = TextEditingController();

  bool _canManageProducts = false;
  bool _canViewGeoDistribution = false;
  bool _loading = true;
  bool _analyticsLoading = false;
  int _brandTabIndex = 0;
  String _analyticsRange = '30d';
  String _analyticsStoreId = '';
  String _analyticsProduct = '';
  String _analyticsRegion = '';
  String _reportStatusFilter = 'all';
  String _reportPriorityFilter = 'all';
  String? _error;
  String? _result;
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _brandProducts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _communityGroups = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _brandRewards = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _brandReports = <Map<String, dynamic>>[];
  Map<String, dynamic> _analytics = const <String, dynamic>{};
  Map<String, dynamic> _brandWallet = const <String, dynamic>{};
  Map<String, dynamic> _pendingPoints = const <String, dynamic>{};
  List<Map<String, dynamic>> _brandRewardClaims = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _loadOffers() => widget.offersLoader != null
      ? widget.offersLoader!()
      : CompanyServerService.getMyOffers();

  Future<List<Map<String, dynamic>>> _loadInvoices() => widget.invoicesLoader != null
      ? widget.invoicesLoader!(limit: 20)
      : CompanyServerService.getMyInvoices(limit: 20);

  Future<List<Map<String, dynamic>>> _loadProducts() => widget.productsLoader != null
      ? widget.productsLoader!()
      : CompanyServerService.getBrandProducts();

  Future<List<Map<String, dynamic>>> _loadCommunityGroups() => widget.communityLoader != null
      ? widget.communityLoader!()
      : CompanyServerService.getGroups();

  Future<List<Map<String, dynamic>>> _loadBrandRewards() => widget.rewardsLoader != null
      ? widget.rewardsLoader!()
      : CompanyServerService.getBrandRewards();

  Future<List<Map<String, dynamic>>> _loadBrandReports() => widget.reportsLoader != null
      ? widget.reportsLoader!()
      : CompanyServerService.getBrandReportsInbox();

  Future<Map<String, dynamic>> _loadBrandWallet() => widget.walletLoader != null
    ? widget.walletLoader!()
    : CompanyServerService.getBrandTokenWallet();

  Future<Map<String, dynamic>> _loadPendingPoints() => widget.pendingPointsLoader != null
    ? widget.pendingPointsLoader!()
    : CompanyServerService.getBrandPendingPoints();
  Future<List<Map<String, dynamic>>> _loadBrandRewardClaims() => widget.rewardClaimsLoader != null
      ? widget.rewardClaimsLoader!()
      : CompanyServerService.getBrandRewardClaims();

  Future<Map<String, dynamic>> _loadAnalytics() => widget.analyticsFilterLoader != null
      ? widget.analyticsFilterLoader!(range: _analyticsRange, storeId: _analyticsStoreId, product: _analyticsProduct, region: _analyticsRegion)
      : widget.analyticsRangeLoader != null
          ? widget.analyticsRangeLoader!(_analyticsRange)
          : widget.analyticsLoader != null
              ? widget.analyticsLoader!()
              : CompanyServerService.getBrandAnalytics(range: _analyticsRange, storeId: _analyticsStoreId, product: _analyticsProduct, region: _analyticsRegion);

  Future<void> _changeAnalyticsRange(String range) async {
    if (range == _analyticsRange || _analyticsLoading) return;
    setState(() {
      _analyticsRange = range;
      _analyticsLoading = true;
    });
    try {
        final analytics = widget.analyticsFilterLoader != null
          ? await widget.analyticsFilterLoader!(range: range, storeId: _analyticsStoreId, product: _analyticsProduct, region: _analyticsRegion)
          : widget.analyticsRangeLoader != null
          ? await widget.analyticsRangeLoader!(range)
          : widget.analyticsLoader != null
              ? await widget.analyticsLoader!()
              : await CompanyServerService.getBrandAnalytics(range: range);
      if (!mounted) return;
      setState(() => _analytics = analytics);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('brand_analytics_reload_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _analyticsLoading = false);
    }
  }

  Future<void> _changeAnalyticsFilter({String? storeId, String? product, String? region}) async {
    if (_analyticsLoading) return;
    setState(() {
      if (storeId != null) _analyticsStoreId = storeId;
      if (product != null) _analyticsProduct = product;
      if (region != null) _analyticsRegion = region;
      _analyticsLoading = true;
    });
    try {
      final analytics = widget.analyticsFilterLoader != null
          ? await widget.analyticsFilterLoader!(range: _analyticsRange, storeId: _analyticsStoreId, product: _analyticsProduct, region: _analyticsRegion)
          : await CompanyServerService.getBrandAnalytics(range: _analyticsRange, storeId: _analyticsStoreId, product: _analyticsProduct, region: _analyticsRegion);
      if (mounted) setState(() => _analytics = analytics);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('brand_analytics_reload_failed'.tr())));
    } finally {
      if (mounted) setState(() => _analyticsLoading = false);
    }
  }

  List<Map<String, dynamic>> _analyticsOptions(String key) {
    final filterOptions = _analytics['filterOptions'];
    if (filterOptions is! Map || filterOptions[key] is! List) return const [];
    return (filterOptions[key] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
  }

  @override
  void dispose() {
    _teamUserIdController.dispose();
    _productNameController.dispose();
    _productImageController.dispose();
    _productBarcodeController.dispose();
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
        _loadProducts(),
        _loadAnalytics(),
        _loadCommunityGroups(),
        _loadBrandRewards(),
        _loadBrandReports(),
        _loadBrandWallet(),
        _loadPendingPoints(),
        _loadBrandRewardClaims(),
      ]);
      if (!mounted) return;
      final rawAnalytics = results[3];
      final analytics = rawAnalytics is Map ? Map<String, dynamic>.from(rawAnalytics as Map<dynamic, dynamic>) : <String, dynamic>{};
      final loadedProducts = List<Map<String, dynamic>>.from(results[2] as List<dynamic>);
      final analyticsProducts = _listSectionFrom(analytics, 'topProducts');
      setState(() {
        _offers = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _invoices = List<Map<String, dynamic>>.from(results[1] as List<dynamic>);
        _brandProducts = loadedProducts.isEmpty ? analyticsProducts : loadedProducts;
        _analytics = analytics;
        _communityGroups = List<Map<String, dynamic>>.from(results[4] as List<dynamic>);
        _brandRewards = List<Map<String, dynamic>>.from(results[5] as List<dynamic>);
        _brandReports = List<Map<String, dynamic>>.from(results[6] as List<dynamic>);
        _brandWallet = Map<String, dynamic>.from(results[7] as Map<dynamic, dynamic>);
        _pendingPoints = Map<String, dynamic>.from(results[8] as Map<dynamic, dynamic>);
        _brandRewardClaims = List<Map<String, dynamic>>.from(results[9] as List<dynamic>);
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

    if (_error != null) {
      return Center(
        key: const Key('brand-dashboard-load-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFFC0524A)),
              const SizedBox(height: 12),
              Text(
                _tx('brand_load_error_title', 'Could not load the brand dashboard'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _tx('brand_load_error_body', 'Check your connection and try again. Empty figures will not replace real data.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text('retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    final tabs = <Widget>[
      _buildOverviewTab(),
      _buildAnalyticsTab(),
      _buildStoresTab(),
      _buildRewardsTab(),
      _buildAdsCampaignsTab(),
      _buildOperationsTab(),
      _buildNetworkTab(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _brandTabIndex,
                onDestinationSelected: (index) => setState(() => _brandTabIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: Text('brand_nav_overview'.tr())),
                  NavigationRailDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: Text('brand_nav_analytics'.tr())),
                  NavigationRailDestination(icon: const Icon(Icons.store_outlined), selectedIcon: const Icon(Icons.store), label: Text('brand_nav_stores'.tr())),
                  NavigationRailDestination(icon: const Icon(Icons.card_giftcard_outlined), selectedIcon: const Icon(Icons.card_giftcard), label: Text('brand_nav_rewards'.tr())),
                  NavigationRailDestination(icon: const Icon(Icons.campaign_outlined), selectedIcon: const Icon(Icons.campaign), label: Text('brand_nav_ads_campaigns'.tr())),
                  NavigationRailDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune), label: Text('brand_nav_management'.tr())),
                  NavigationRailDestination(icon: const Icon(Icons.hub_outlined), selectedIcon: const Icon(Icons.hub), label: Text('brand_nav_network'.tr())),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: tabs[_brandTabIndex]),
            ],
          );
        }

        return Column(
          children: [
            Expanded(child: tabs[_brandTabIndex]),
            NavigationBar(
              selectedIndex: switch (_brandTabIndex) {
                0 => 0,
                1 => 1,
                4 => 2,
                3 => 3,
                _ => 4,
              },
              onDestinationSelected: (index) {
                if (index == 0) setState(() => _brandTabIndex = 0);
                if (index == 1) setState(() => _brandTabIndex = 1);
                if (index == 2) setState(() => _brandTabIndex = 4);
                if (index == 3) setState(() => _brandTabIndex = 3);
                if (index == 4) _showMoreDestinations();
              },
              destinations: [
                NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: 'brand_nav_overview'.tr()),
                NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights), label: 'brand_nav_analytics'.tr()),
                NavigationDestination(icon: const Icon(Icons.campaign_outlined), selectedIcon: const Icon(Icons.campaign), label: 'brand_nav_ads_campaigns'.tr()),
                NavigationDestination(icon: const Icon(Icons.card_giftcard_outlined), selectedIcon: const Icon(Icons.card_giftcard), label: 'brand_nav_rewards'.tr()),
                NavigationDestination(icon: const Icon(Icons.more_horiz), selectedIcon: const Icon(Icons.more), label: 'brand_nav_more'.tr()),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMoreDestinations() async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: Text('brand_nav_stores'.tr()),
              selected: _brandTabIndex == 2,
              onTap: () => Navigator.pop(context, 2),
            ),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: Text('brand_nav_management'.tr()),
              selected: _brandTabIndex == 5,
              onTap: () => Navigator.pop(context, 5),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text('brand_nav_network'.tr()),
              selected: _brandTabIndex == 6,
              onTap: () => Navigator.pop(context, 6),
            ),
          ],
        ),
      ),
    );
    if (selectedIndex != null && mounted) {
      setState(() => _brandTabIndex = selectedIndex);
    }
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('brand_geo_intelligence_title'.tr()),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            key: const Key('brand-analytics-range'),
            segments: [
              ButtonSegment(value: '7d', label: Text('brand_range_7d'.tr())),
              ButtonSegment(value: '30d', label: Text('brand_range_30d'.tr())),
              ButtonSegment(value: '90d', label: Text('brand_range_90d'.tr())),
            ],
            selected: {_analyticsRange},
            onSelectionChanged: _analyticsLoading ? null : (selection) => _changeAnalyticsRange(selection.first),
          ),
        ),
        if (_analyticsLoading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _analyticsDropdown(
              key: const Key('brand-analytics-store-filter'),
              label: 'brand_filter_store'.tr(),
              value: _analyticsStoreId,
              options: _analyticsOptions('stores'),
              onChanged: (value) => _changeAnalyticsFilter(storeId: value),
            ),
            _analyticsDropdown(
              key: const Key('brand-analytics-product-filter'),
              label: 'brand_filter_product'.tr(),
              value: _analyticsProduct,
              options: _analyticsOptions('products'),
              onChanged: (value) => _changeAnalyticsFilter(product: value),
            ),
            _analyticsDropdown(
              key: const Key('brand-analytics-region-filter'),
              label: 'brand_filter_region'.tr(),
              value: _analyticsRegion,
              options: _analyticsOptions('regions'),
              onChanged: (value) => _changeAnalyticsFilter(region: value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _analyticsLoading ? null : _exportAnalyticsPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text('brand_export_pdf'.tr()),
            ),
            OutlinedButton.icon(
              onPressed: _analyticsLoading ? null : _exportAnalyticsCsv,
              icon: const Icon(Icons.table_view_outlined),
              label: Text('brand_export_csv'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAnalyticsCard(),
      ],
    );
  }

  Widget _buildAdsCampaignsTab() {
    return ListView(
      key: const Key('brand-ads-campaigns-tab'),
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('brand_ads_campaigns_title'.tr()),
        Text('brand_ads_campaigns_subtitle'.tr()),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: Text('billboard_create_ad'.tr()),
            subtitle: Text('billboard_create_ad_hint'.tr()),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddCouponScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.ads_click_outlined),
            title: Text('brand_launch_targeted_campaign'.tr()),
            subtitle: Text('brand_launch_targeted_campaign_hint'.tr()),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantCampaignScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sectionHeader('brand_my_ads'.tr()),
        if (_offers.isEmpty)
          Card(child: ListTile(title: Text('brand_no_ads'.tr())))
        else
          ..._offers.map((offer) {
            final status = (offer['lifecycleStatus'] ?? 'pending_review').toString();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text((offer['description'] ?? 'offer'.tr()).toString()),
                subtitle: Text(
                  '${'brand_ad_status'.tr()}: $status\n'
                  '${'brand_ad_metrics'.tr(namedArgs: {
                    'impressions': '${offer['impressions'] ?? 0}',
                    'clicks': '${offer['clicks'] ?? 0}',
                  })}',
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }

  Future<void> _exportAnalyticsPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Brand Analytics Export')),
          pw.Text('Range: $_analyticsRange'),
          pw.Text('Store: ${_analyticsStoreId.isEmpty ? 'All' : _analyticsStoreId}'),
          pw.Text('Product: ${_analyticsProduct.isEmpty ? 'All' : _analyticsProduct}'),
          pw.Text('Region: ${_analyticsRegion.isEmpty ? 'All' : _analyticsRegion}'),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Matched sales: ${_money(_analytics['matchedSales'])}'),
          pw.Bullet(text: 'Matched customers: ${_intValue(_analytics['matchedCustomers'])}'),
          pw.Bullet(text: 'Points issued: ${_intValue(_analytics['pointsIssued'])}'),
          pw.Bullet(text: 'Reward claims: ${_intValue(_analytics['rewardClaims'])}'),
          pw.Bullet(text: 'Points redeemed: ${_intValue(_analytics['pointsRedeemed'])}'),
          pw.Bullet(text: 'Redemption rate: ${_money(_analytics['redemptionRate'])}%'),
          pw.SizedBox(height: 12),
          pw.Text('Top products'),
          ..._listSection('topProducts').take(8).map((row) => pw.Bullet(text: '${row['name'] ?? '-'} | ${_money(row['salesTotal'])}')),
          pw.Text('Top stores'),
          ..._listSection('topSellingStores').take(8).map((row) => pw.Bullet(text: '${row['name'] ?? '-'} | ${_money(row['salesTotal'])}')),
        ],
      ),
    );
    final ok = await downloadBytes(bytes: await pdf.save(), fileName: 'brand-analytics-$_analyticsRange.pdf', mimeType: 'application/pdf');
    _showAnalyticsExportResult(ok, 'PDF');
  }

  Future<void> _exportAnalyticsCsv() async {
    final buffer = StringBuffer()
      ..writeln('section,label,value')
      ..writeln('filters,range,$_analyticsRange')
      ..writeln('filters,store,${_csv(_analyticsStoreId.isEmpty ? 'all' : _analyticsStoreId)}')
      ..writeln('filters,product,${_csv(_analyticsProduct.isEmpty ? 'all' : _analyticsProduct)}')
      ..writeln('filters,region,${_csv(_analyticsRegion.isEmpty ? 'all' : _analyticsRegion)}')
      ..writeln('summary,matched_sales,${_money(_analytics['matchedSales'])}')
      ..writeln('summary,matched_customers,${_intValue(_analytics['matchedCustomers'])}')
      ..writeln('summary,points_issued,${_intValue(_analytics['pointsIssued'])}')
      ..writeln('summary,reward_claims,${_intValue(_analytics['rewardClaims'])}')
      ..writeln('summary,points_redeemed,${_intValue(_analytics['pointsRedeemed'])}')
      ..writeln('summary,redemption_rate,${_money(_analytics['redemptionRate'])}');
    for (final row in _listSection('topProducts')) {
      buffer.writeln('product,${_csv((row['name'] ?? '-').toString())},${_money(row['salesTotal'])}');
    }
    for (final row in _listSection('topSellingStores')) {
      buffer.writeln('store,${_csv((row['name'] ?? '-').toString())},${_money(row['salesTotal'])}');
    }
    final ok = await downloadBytes(bytes: utf8.encode(buffer.toString()), fileName: 'brand-analytics-$_analyticsRange.csv', mimeType: 'text/csv');
    _showAnalyticsExportResult(ok, 'CSV');
  }

  String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  void _showAnalyticsExportResult(bool ok, String format) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'brand_export_started'.tr(namedArgs: {'format': format}) : 'brand_export_web_only'.tr())),
    );
  }

  Widget _analyticsDropdown({
    required Key key,
    required String label,
    required String value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        key: key,
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          DropdownMenuItem(value: '', child: Text('brand_filter_all'.tr())),
          ...options.map((option) => DropdownMenuItem(
                value: (option['value'] ?? '').toString(),
                child: Text((option['label'] ?? option['value'] ?? '-').toString(), overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: _analyticsLoading ? null : (selected) => onChanged(selected ?? ''),
      ),
    );
  }

  Widget _buildNetworkTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('brand_network_title'.tr()),
        Text('brand_network_subtitle'.tr()),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text('brand_network_clearinghouse'.tr()),
            subtitle: Text('brand_network_clearinghouse_hint'.tr()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BrandCoalitionClearinghouseScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: Text('brand_network_coalitions'.tr()),
            subtitle: Text('brand_network_coalitions_hint'.tr()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PublicCoalitionMembershipScreen(applicantType: 'brand'),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.card_giftcard_outlined),
            title: Text('brand_network_gifting'.tr()),
            subtitle: Text('brand_network_gifting_hint'.tr()),
            onTap: () => setState(() => _brandTabIndex = 3),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text('brand_team_title'.tr()),
            subtitle: Text('brand_team_subtitle'.tr()),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrandTeamScreen())),
          ),
        ),
      ],
    );
  }

  Widget _buildStoresTab() {
    final stores = _listSection('topSellingStores');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('brand_discovered_stores_title'.tr()),
        ...stores.map((store) => Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined, color: Color(0xFF137A60)),
                title: Text((store['name'] ?? '-').toString()),
                subtitle: Text('brand_store_sales_quantity'.tr(namedArgs: {'sales': _money(store['salesTotal']), 'quantity': '${_intValue(store['quantity'])}'})),
                trailing: IconButton(
                  tooltip: 'brand_launch_support_campaign'.tr(),
                  icon: const Icon(Icons.campaign_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MerchantCampaignScreen(
                        partnerMerchantId: (store['key'] ?? '').toString(),
                        partnerMerchantName: (store['name'] ?? '').toString(),
                      ),
                    ),
                  ),
                ),
                onTap: () => _showStoreDetails(store),
              ),
            )),
        if (stores.isEmpty) Text('brand_stores_empty'.tr()),
        if (stores.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('brand_support_campaign_hint'.tr()),
          ),
      ],
    );
  }

  Widget _buildRewardsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('brand_products_rewards_title'.tr()),
        RewardFundingCard(
          sourceType: 'brand',
          loader: widget.rewardFundingLoader,
          funder: widget.rewardFunder,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _fundingMetric(
              icon: Icons.account_balance_wallet_outlined,
              label: 'brand_funding_balance'.tr(),
              value: '${_brandWallet['balance'] ?? 0}',
              color: const Color(0xFF1B7A66),
            ),
            _fundingMetric(
              icon: Icons.pending_actions_outlined,
              label: 'brand_pending_points'.tr(),
              value: '${_pendingPoints['total_points'] ?? 0}',
              color: const Color(0xFFE0A21A),
            ),
            _fundingMetric(
              icon: Icons.people_outline,
              label: 'brand_pending_customers'.tr(),
              value: '${_pendingPoints['customer_count'] ?? 0}',
              color: const Color(0xFF2E80ED),
            ),
          ],
        ),
        if ((_pendingPoints['total_points'] as num? ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('brand_pending_points_warning'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFC0524A))),
          ),
        const SizedBox(height: 12),
        ..._brandRewards.map((reward) => Card(
              child: ListTile(
                leading: (reward['imageUrl'] ?? '').toString().isEmpty
                    ? const Icon(Icons.emoji_events_outlined, color: Color(0xFFE68A00))
                    : Image.network((reward['imageUrl'] ?? '').toString(), width: 48, height: 48, fit: BoxFit.cover),
                title: Text((reward['reward_name'] ?? '-').toString()),
                subtitle: Text('${reward['value'] ?? 0} نقطة • ${reward['kind'] ?? 'physical'}${reward['expiresAt'] == null ? '' : ' • ينتهي ${reward['expiresAt']}'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${reward['quantityRedeemed'] ?? 0}/${reward['quantityLimit'] ?? '∞'}'),
                    Switch(
                      value: reward['isActive'] != false,
                      onChanged: (value) async {
                        await (widget.rewardUpdater ?? CompanyServerService.updateBrandReward)(
                          (reward['id'] ?? '').toString(),
                          isActive: value,
                          quantityLimit: reward['quantityLimit'] is num ? (reward['quantityLimit'] as num).toInt() : null,
                        );
                        await _load();
                      },
                    ),
                    IconButton(
                      tooltip: 'brand_edit_reward'.tr(),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editReward(reward),
                    ),
                  ],
                ),
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
        const SizedBox(height: 8),
        BrandProductCatalog(
          products: _brandProducts,
          createProduct: widget.productCreator ?? CompanyServerService.createBrandProduct,
          updateProduct: widget.productUpdater ?? CompanyServerService.updateBrandProduct,
          deactivateProduct: widget.productDeactivator ?? CompanyServerService.deactivateBrandProduct,
          imageSelector: widget.productImageSelector,
          barcodeSelector: widget.productBarcodeSelector,
          reload: _load,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _showCreateRewardDialog,
          icon: const Icon(Icons.emoji_events_outlined),
          label: Text('brand_add_reward'.tr()),
        ),
        const SizedBox(height: 16),
        _sectionHeader('brand_recent_redemptions'.tr()),
        if (_brandRewardClaims.isEmpty)
          Text('brand_recent_redemptions_empty'.tr())
        else
              ..._brandRewardClaims.take(10).map((claim) => Card(
                key: Key('brand-claim-${claim['id']}'),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text((claim['rewardName'] ?? 'reward_generic'.tr()).toString()),
                  subtitle: Text('${claim['pointsCost'] ?? 0} • ${claim['status'] ?? '-'}'),
                  trailing: Tooltip(
                    message: (claim['id'] ?? '').toString(),
                    child: Text('#${(claim['id'] ?? '').toString().substring(0, ((claim['id'] ?? '').toString().length).clamp(0, 8))}'),
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _editReward(Map<String, dynamic> reward) async {
    var quantityText = '${reward['quantityLimit'] ?? ''}';
    var description = (reward['description'] ?? '').toString();
    DateTime? expiresAt = DateTime.tryParse((reward['expiresAt'] ?? '').toString());
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('brand_edit_reward'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('brand-reward-quantity'),
                  initialValue: quantityText,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantityText = value,
                  decoration: InputDecoration(labelText: 'brand_reward_quantity_limit'.tr(), errorText: error),
                ),
                TextFormField(
                  initialValue: description,
                  maxLines: 3,
                  onChanged: (value) => description = value,
                  decoration: InputDecoration(labelText: 'brand_reward_description'.tr()),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiresAt == null ? 'brand_reward_no_expiry'.tr() : '${'brand_reward_expiry'.tr()}: ${expiresAt!.toIso8601String().split('T').first}'),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: expiresAt?.isAfter(DateTime.now()) == true ? expiresAt! : DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setDialogState(() => expiresAt = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
            FilledButton(
              key: const Key('brand-reward-save'),
              onPressed: () async {
                final quantity = int.tryParse(quantityText);
                final redeemed = int.tryParse('${reward['quantityRedeemed'] ?? 0}') ?? 0;
                if (quantity == null || quantity <= 0 || quantity < redeemed) {
                  setDialogState(() => error = 'brand_reward_quantity_invalid'.tr(namedArgs: {'redeemed': '$redeemed'}));
                  return;
                }
                await (widget.rewardUpdater ?? CompanyServerService.updateBrandReward)(
                  (reward['id'] ?? '').toString(),
                  quantityLimit: quantity,
                  expiresAt: expiresAt,
                  description: description,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fundingMetric({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 11))])),
        ],
      ),
    );
  }

  Widget _buildOperationsTab() {
    final alerts = _buildSalesAlerts();
    final reports = _brandReports.where((report) {
      final statusMatches = _reportStatusFilter == 'all' || report['status'] == _reportStatusFilter;
      final priorityMatches = _reportPriorityFilter == 'all' || (report['priority'] ?? 'normal') == _reportPriorityFilter;
      return statusMatches && priorityMatches;
    }).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('brand_sales_alerts_title'.tr()),
        if (alerts.isEmpty) Text('brand_sales_alerts_empty'.tr()) else ...alerts,
        const SizedBox(height: 12),
        _sectionHeader('brand_quality_reports_title'.tr()),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownButton<String>(
              value: _reportStatusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('كل الحالات')),
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'information_requested', child: Text('بانتظار معلومات')),
                DropdownMenuItem(value: 'accepted', child: Text('مقبول')),
                DropdownMenuItem(value: 'reward_granted', child: Text('تم التعويض')),
                DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
              ],
              onChanged: (value) => setState(() => _reportStatusFilter = value ?? 'all'),
            ),
            DropdownButton<String>(
              value: _reportPriorityFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('كل الأولويات')),
                DropdownMenuItem(value: 'urgent', child: Text('عاجل')),
                DropdownMenuItem(value: 'normal', child: Text('عادي')),
                DropdownMenuItem(value: 'low', child: Text('منخفض')),
              ],
              onChanged: (value) => setState(() => _reportPriorityFilter = value ?? 'all'),
            ),
          ],
        ),
        if (reports.isEmpty) Text('brand_quality_reports_empty'.tr()) else ...reports.map(_buildReportCard),
        ExpansionTile(
          title: Text('brand_community_title'.tr()),
          leading: const Icon(Icons.groups_outlined, color: Color(0xFF2F80ED)),
          children: _communityGroups.isEmpty
              ? [ListTile(title: Text('brand_community_empty'.tr()))]
                : _communityGroups.map((group) => ListTile(
                    leading: const Icon(Icons.group_outlined),
                    title: Text((group['name'] ?? '-').toString()),
                    subtitle: Text('${group['members'] ?? 0} عضو'),
                  trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityScreen(initialGroupId: (group['id'] ?? '').toString()))),
                  )).toList(growable: false),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: Text('system_point_value_title'.tr()),
            subtitle: Text('system_point_value_description'.tr(namedArgs: const {'value': '0.1'})),
          ),
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
          Row(children: [const Icon(Icons.report_problem_outlined, color: Color(0xFFE67E22)), const SizedBox(width: 8), Expanded(child: Text((report['reportType'] ?? 'بلاغ جودة').toString(), style: const TextStyle(fontWeight: FontWeight.bold))), Chip(label: Text((report['priority'] ?? 'normal').toString())), const SizedBox(width: 6), Text((report['status'] ?? 'new').toString())]),
          const SizedBox(height: 6),
          Text('المبلغ: ${(report['reporterName'] ?? report['reporterEmail'] ?? '-').toString()}'),
          Text('المحل: ${(report['storeName'] ?? 'غير محدد').toString()}'),
          Text((report['description'] ?? 'بدون وصف').toString()),
          if (report['updates'] is List && (report['updates'] as List).isNotEmpty) ...[
            const Divider(),
            Text('report_updates_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
            ...(report['updates'] as List).whereType<Map>().map((update) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_bubble_outline, size: 18),
              title: Text((update['message'] ?? '').toString()),
              subtitle: Text((update['authorRole'] ?? '').toString()),
            )),
          ],
          if ((report['storePhone'] ?? '').toString().isNotEmpty) Text('الهاتف: ${report['storePhone']}'),
          if ((report['storeAddress'] ?? '').toString().isNotEmpty) Text('الموقع: ${report['storeAddress']}'),
          if (report['storeLat'] != null && report['storeLng'] != null) ...[const SizedBox(height: 8), AnalyticsMapPanel(points: [mapPoint], emptyLabel: 'لا يوجد موقع للبلاغ', markerColor: Colors.orange)],
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if ((report['ownerId'] ?? '').toString().isNotEmpty) OutlinedButton.icon(onPressed: () => _showMessageDialog({'userId': report['ownerId'], 'name': report['reporterName'] ?? 'المبلغ'}), icon: const Icon(Icons.mail_outline), label: const Text('رسالة للمبلغ')),
            if ((report['storeUserId'] ?? '').toString().isNotEmpty) OutlinedButton.icon(onPressed: () => _showMessageDialog({'userId': report['storeUserId'], 'name': report['storeName'] ?? 'المحل'}), icon: const Icon(Icons.storefront_outlined), label: const Text('رسالة للمحل')),
            if (report['status'] == 'new') ...[
              ElevatedButton.icon(onPressed: () => _resolveReport(report, action: 'reward'), icon: const Icon(Icons.stars_outlined), label: const Text('قبول ومنح نقاط')),
              OutlinedButton(onPressed: () => _resolveReport(report, action: 'accept'), child: const Text('قبول')),
              OutlinedButton(onPressed: () => _resolveReport(report, action: 'request_information'), child: const Text('طلب معلومات')),
              TextButton(onPressed: () => _resolveReport(report, action: 'reject'), child: const Text('رفض')),
            ],
          ]),
        ]),
      ),
    );
  }

  Future<void> _resolveReport(Map<String, dynamic> report, {required String action}) async {
    String? note = action == 'reward' || action == 'accept' ? 'تمت مراجعة البلاغ من العلامة.' : null;
    if (action == 'reject' || action == 'request_information') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(action == 'reject' ? 'سبب الرفض' : 'المعلومات المطلوبة'),
          content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظة للمستهلك')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
            FilledButton(onPressed: () { final value = controller.text.trim(); if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: Text('confirm'.tr())),
          ],
        ),
      );
      controller.dispose();
      if (note == null) return;
    }
    await CompanyServerService.resolveBrandReport((report['id'] ?? '').toString(), action: action, grantReward: action == 'reward', rewardPoints: 10, resolutionNote: note);
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
          Text('brand_dashboard_title'.tr(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('brand_dashboard_subtitle'.tr()),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth < 500 ? 0.9 : 1.55,
              children: [
                _metricCard(icon: Icons.storefront_outlined, title: 'brand_metric_stores'.tr(), value: '${stores.length}', subtitle: 'brand_metric_stores_hint'.tr(), color: const Color(0xFF1C7F6B)),
                _metricCard(icon: Icons.inventory_2_outlined, title: 'brand_metric_products'.tr(), value: '${products.length}', subtitle: 'brand_metric_products_hint'.tr(), color: const Color(0xFF5A5FE0)),
                _metricCard(icon: Icons.people_outline, title: 'brand_metric_customers'.tr(), value: '${_intValue(_analytics['matchedCustomers'])}', subtitle: 'brand_metric_customers_hint'.tr(), color: const Color(0xFF2E80ED)),
                _metricCard(icon: Icons.payments_outlined, title: 'brand_metric_sales'.tr(), value: _money(_analytics['matchedSales']), subtitle: 'brand_metric_sales_hint'.tr(), color: const Color(0xFFE68A00)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('brand_performance_title'.tr()),
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
    return BrandAnalyticsCharts(analytics: _analytics);
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

  Future<void> _showCreateRewardDialog() async {
    await showRewardCreationDialog(
      context: context,
      onSave: (data) async {
        await CompanyServerService.createBrandReward(
          rewardName: data.rewardName,
          points: data.points,
          description: data.description,
          imageUrl: data.imageUrl,
          kind: data.kind,
          expiresAt: data.expiresAt,
          quantityLimit: data.quantityLimit,
          pickupInstructions: data.pickupInstructions,
          drawEnabled: data.drawEnabled,
          drawAt: data.expiresAt,
        );
        await _load();
      },
    );
  }

  double _toDouble(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

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
