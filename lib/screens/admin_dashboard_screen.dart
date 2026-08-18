import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/company_server_service.dart';
import '../theme/app_themes.dart';
import '../theme/design_tokens.dart';

typedef AdminRoleRequestsLoader = Future<List<Map<String, dynamic>>> Function(String status);
typedef AdminPeerAdsLoader = Future<List<Map<String, dynamic>>> Function(String status);
typedef AdminSummaryLoader = Future<Map<String, dynamic>> Function();
typedef AdminRoleRequestAction = Future<Map<String, dynamic>> Function(String requestId);
typedef AdminPeerAdAction = Future<Map<String, dynamic>> Function(String adId);

class AdminDashboardScreen extends StatefulWidget {
  final bool embedded;
  final AdminRoleRequestsLoader? roleRequestsLoader;
  final AdminPeerAdsLoader? peerAdsLoader;
  final AdminSummaryLoader? summaryLoader;
  final AdminRoleRequestAction? approveRoleRequest;
  final AdminRoleRequestAction? rejectRoleRequest;
  final AdminPeerAdAction? approvePeerAd;
  final AdminPeerAdAction? rejectPeerAd;

  const AdminDashboardScreen({
    super.key,
    this.embedded = false,
    this.roleRequestsLoader,
    this.peerAdsLoader,
    this.summaryLoader,
    this.approveRoleRequest,
    this.rejectRoleRequest,
    this.approvePeerAd,
    this.rejectPeerAd,
  });

  const AdminDashboardScreen.embedded({
    super.key,
    this.roleRequestsLoader,
    this.peerAdsLoader,
    this.summaryLoader,
    this.approveRoleRequest,
    this.rejectRoleRequest,
    this.approvePeerAd,
    this.rejectPeerAd,
  }) : embedded = true;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _roleRequestsFuture;
  late Future<List<Map<String, dynamic>>> _peerAdsFuture;
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    _roleRequestsFuture = widget.roleRequestsLoader != null
        ? widget.roleRequestsLoader!('pending_admin_review')
        : CompanyServerService.getAdminRoleRequests(status: 'pending_admin_review');
    _peerAdsFuture = widget.peerAdsLoader != null
        ? widget.peerAdsLoader!('pending_admin_review')
        : CompanyServerService.getAdminPeerAds(status: 'pending_admin_review');
    _summaryFuture = (widget.summaryLoader ?? CompanyServerService.getAdminDashboardSummary)();
  }

  Future<void> _approveRoleRequest(String requestId) async {
    await (widget.approveRoleRequest ?? CompanyServerService.approveAdminRoleRequest)(requestId);
    if (!mounted) return;
    setState(_refreshAll);
  }

  Future<void> _rejectRoleRequest(String requestId) async {
    await (widget.rejectRoleRequest ?? CompanyServerService.rejectAdminRoleRequest)(requestId);
    if (!mounted) return;
    setState(_refreshAll);
  }

  Future<void> _approvePeerAd(String adId) async {
    await (widget.approvePeerAd ?? CompanyServerService.approveAdminPeerAd)(adId);
    if (!mounted) return;
    setState(_refreshAll);
  }

  Future<void> _rejectPeerAd(String adId) async {
    await (widget.rejectPeerAd ?? CompanyServerService.rejectAdminPeerAd)(adId);
    if (!mounted) return;
    setState(_refreshAll);
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  String _roleLabel(String roleType) {
    switch (roleType.toLowerCase()) {
      case 'merchant':
        return _tx('role_merchant', 'merchant');
      case 'brand':
        return _tx('role_brand', 'brand');
      case 'cashier':
        return _tx('role_cashier', 'cashier');
      default:
        return _tx('role_customer', 'customer');
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildRoleRequests() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _roleRequestsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return Text(_tx('admin_no_pending_role_requests', 'No pending role requests.'));
        }

        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final requestId = (row['id'] ?? '').toString();
            final roleType = (row['roleType'] ?? '').toString();
            final businessName = (row['businessName'] ?? '-').toString();
            final phone = (row['phone'] ?? '-').toString();
            final planType = (row['planType'] ?? '-').toString();
            final lat = row['locationLat'];
            final lng = row['locationLng'];
            final locationAddress = (row['locationAddress'] ?? '').toString();
            final locationLabel =
                (lat != null && lng != null) ? '${lat.toString()}, ${lng.toString()}' : '-';
            final localizedRole = _roleLabel(roleType);

            return _sectionCard(
              title: '$businessName ($localizedRole)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_phone_value'.tr(namedArgs: {'value': phone}) == 'admin_phone_value'
                      ? 'Phone: $phone'
                      : 'admin_phone_value'.tr(namedArgs: {'value': phone})),
                  Text('admin_plan_value'.tr(namedArgs: {'value': planType}) == 'admin_plan_value'
                      ? 'Plan: $planType'
                      : 'admin_plan_value'.tr(namedArgs: {'value': planType})),
                  Text('admin_location_value'.tr(namedArgs: {'value': locationLabel}) == 'admin_location_value'
                      ? 'Location: $locationLabel'
                      : 'admin_location_value'.tr(namedArgs: {'value': locationLabel})),
                  if (locationAddress.isNotEmpty)
                    Text('admin_address_value'.tr(namedArgs: {'value': locationAddress}) == 'admin_address_value'
                        ? 'Address: $locationAddress'
                        : 'admin_address_value'.tr(namedArgs: {'value': locationAddress})),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: requestId.isEmpty ? null : () => _approveRoleRequest(requestId),
                        child: Text(_tx('approve', 'Approve')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: requestId.isEmpty ? null : () => _rejectRoleRequest(requestId),
                        child: Text(_tx('reject', 'Reject')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPeerAds() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _peerAdsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return Text(_tx('admin_no_pending_peer_ads', 'No pending peer ads.'));
        }

        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final adId = (row['id'] ?? '').toString();
            final content = (row['content'] ?? '-').toString();
            final targetType = (row['targetType'] ?? '-').toString();
            final targetValue = (row['targetValue'] ?? '-').toString();

            return _sectionCard(
              title: content,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('admin_target_value'.tr(namedArgs: {'type': targetType, 'value': targetValue}) == 'admin_target_value'
                      ? 'Target: $targetType / $targetValue'
                      : 'admin_target_value'.tr(namedArgs: {'type': targetType, 'value': targetValue})),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: adId.isEmpty ? null : () => _approvePeerAd(adId),
                        child: Text(_tx('approve', 'Approve')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: adId.isEmpty ? null : () => _rejectPeerAd(adId),
                        child: Text(_tx('reject', 'Reject')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final coreStats = _tx('admin_summary_core_stats', 'Active merchants: {active}\nPlatform sales: {sales}')
            .replaceAll('{active}', '${data['activeMerchants'] ?? 0}')
            .replaceAll('{sales}', '${data['totalSales'] ?? 0}');

        final salesSeries = const [10.0, 18.0, 15.0, 27.0, 24.0, 36.0, 42.0];
        final communitySeries = const [2.0, 3.0, 5.0, 6.0, 8.0, 10.0, 12.0];

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _sectionCard(
              title: _tx('admin_tab_analytics', 'Analytics'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coreStats),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 60,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text('${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: salesSeries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final value = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [BarChartRodData(toY: value, width: 14, color: const Color(0xFF4F6BFF))],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _sectionCard(
              title: 'Community activity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 150,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: const Color(0xFF00B894),
                            barWidth: 3,
                            spots: communitySeries.asMap().entries
                                .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Groups: ${data['groups'] ?? 0} | Reports: ${data['reports'] ?? 0} | Alerts: ${data['fraudFlags'] ?? 0}'),
                ],
              ),
            ),
            _sectionCard(title: _tx('admin_summary_users', 'Users'), child: Text('${data['users'] ?? 0}')),
            _sectionCard(title: _tx('admin_summary_merchants', 'Merchants'), child: Text('${data['merchants'] ?? 0}')),
            _sectionCard(title: _tx('admin_summary_brands', 'Brands'), child: Text('${data['brands'] ?? 0}')),
            _sectionCard(title: _tx('admin_summary_reports', 'Reports'), child: Text('${data['reports'] ?? 0}')),
            _sectionCard(title: _tx('admin_summary_fraud_flags', 'Fraud Flags'), child: Text('${data['fraudFlags'] ?? 0}')),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: _tx('admin_tab_role_requests', 'Role Requests')),
              Tab(text: _tx('admin_tab_peer_ads', 'Peer Ads')),
              Tab(text: _tx('admin_tab_analytics', 'Analytics')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRoleRequests(),
                _buildPeerAds(),
                _buildSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Theme(data: adminTheme, child: _buildBody());
    if (widget.embedded) {
      return body;
    }
    return Theme(
      data: adminTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tx('admin_dashboard_title', 'Admin Dashboard')),
          backgroundColor: kInk,
        ),
        body: _buildBody(),
      ),
    );
  }
}
