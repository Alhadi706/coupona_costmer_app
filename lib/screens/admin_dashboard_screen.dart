import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/company_server_service.dart';
import '../theme/app_themes.dart';
import '../theme/design_tokens.dart';
import 'admin_report_detail_screen.dart';

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
  late Future<Map<String, dynamic>> _operationsFuture;

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
    _operationsFuture = CompanyServerService.getAdminOperationsQueue();
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

  Future<void> _transitionReport(String reportId, String to, {bool rewardGranted = false}) async {
    try {
      await CompanyServerService.transitionAdminReport(
        reportId,
        to: to,
        rewardGranted: rewardGranted,
      );
      if (!mounted) return;
      setState(_refreshAll);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the report. Please refresh and try again.')),
      );
    }
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
        final totalSales = data['totalSales'] ?? 0;
        final activeMerchants = data['activeMerchants'] ?? 0;
        final reports = data['reports'] ?? 0;
        final fraudFlags = data['fraudFlags'] ?? 0;
        final users = data['users'] ?? 0;
        final merchants = data['merchants'] ?? 0;
        final brands = data['brands'] ?? 0;
        final groups = data['groups'] ?? 0;
        final activity = (data['activity'] as List? ?? const [])
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList();
        final activitySpots = activity.asMap().entries.map((entry) {
          final value = entry.value;
          final approvedInvoices = double.tryParse('${value['approvedInvoices'] ?? 0}') ?? 0;
          final reportCount = double.tryParse('${value['reports'] ?? 0}') ?? 0;
          final newUsers = double.tryParse('${value['newUsers'] ?? 0}') ?? 0;
          return FlSpot(entry.key.toDouble(), approvedInvoices + reportCount + newUsers);
        }).toList();

        final salesSpots = activity.asMap().entries.map((entry) {
          final value = entry.value;
          final dailySales = double.tryParse('${value['dailySales'] ?? 0}') ?? 0;
          return FlSpot(entry.key.toDouble(), dailySales);
        }).toList();

        final usersPct = (users > 0 ? (users / (users + merchants + brands)) * 100 : 0).toDouble();
        final merchantsPct = (merchants > 0 ? (merchants / (users + merchants + brands)) * 100 : 0).toDouble();
        final brandsPct = (brands > 0 ? (brands / (users + merchants + brands)) * 100 : 0).toDouble();

        final metricCards = [
          _buildMetricCard(_tx('admin_active_merchants', 'Active merchants'), activeMerchants, const Color(0xFF4F6BFF)),
          _buildMetricCard(_tx('admin_total_sales', 'Total sales'), totalSales, const Color(0xFF00B894)),
          _buildMetricCard(_tx('admin_users', 'Users'), users, const Color(0xFF7C4DFF)),
          _buildMetricCard(_tx('admin_reports', 'Reports'), reports, const Color(0xFFFFA726)),
          _buildMetricCard(_tx('admin_fraud_flags', 'Fraud flags'), fraudFlags, const Color(0xFFEF5350)),
          _buildMetricCard(_tx('admin_groups', 'Groups'), groups, const Color(0xFF26A69A)),
        ];

        final roleRequestsCountFuture = _roleRequestsFuture.then((rows) => rows.length);
        final peerAdsCountFuture = _peerAdsFuture.then((rows) => rows.length);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              _tx('admin_operations_control_center', 'Operations control center'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metricCards,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _sectionCard(
                    title: _tx('admin_platform_activity', 'Platform activity & Revenue (30 days)'),
                    child: SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) => Text('${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              color: const Color(0xFF00B894),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: true, color: const Color(0xFF00B894).withValues(alpha: 0.1)),
                              spots: activitySpots.isEmpty ? const [FlSpot(0, 0), FlSpot(6, 0)] : activitySpots,
                            ),
                            LineChartBarData(
                              isCurved: true,
                              color: const Color(0xFF4F6BFF),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                              spots: salesSpots.isEmpty ? const [FlSpot(0, 0), FlSpot(6, 0)] : salesSpots,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _sectionCard(
                    title: _tx('admin_user_distribution', 'User Distribution'),
                    child: SizedBox(
                      height: 200,
                      child: (users + merchants + brands == 0) 
                          ? const Center(child: Text('No data'))
                          : PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  PieChartSectionData(color: const Color(0xFF7C4DFF), value: usersPct, title: '${usersPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  PieChartSectionData(color: const Color(0xFF4F6BFF), value: merchantsPct, title: '${merchantsPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  PieChartSectionData(color: const Color(0xFF00B894), value: brandsPct, title: '${brandsPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            _sectionCard(
              title: _tx('admin_operational_pulse', 'Operational pulse'),
              child: Column(
                children: [
                  _buildOpsRow(_tx('admin_customer_reports', 'Customer reports'), _tx('admin_reports_received', '{count} reports received').replaceAll('{count}', '$reports'), _tx('admin_open_queue', 'Open queue'), const Color(0xFFFFA726)),
                  _buildOpsRow(_tx('admin_risk_review', 'Risk review'), _tx('admin_risk_flags_detected', '{count} risk flags detected').replaceAll('{count}', '$fraudFlags'), _tx('admin_review_needed', 'Review needed'), const Color(0xFFEF5350)),
                  _buildOpsRow(_tx('admin_merchant_activity', 'Merchant activity'), _tx('admin_active_merchants_30_days', '{count} active in the last 30 days').replaceAll('{count}', '$activeMerchants'), _tx('admin_live', 'Live'), const Color(0xFF00B894)),
                ],
              ),
            ),
            _sectionCard(
              title: _tx('admin_monitoring_and_actions', 'Monitoring & actions'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tx('admin_business_footprint', 'Business footprint: {m} merchants | {b} brands | {u} users').replaceAll('{m}', '$merchants').replaceAll('{b}', '$brands').replaceAll('{u}', '$users')),
                  const SizedBox(height: 10),
                  FutureBuilder<int>(
                    future: roleRequestsCountFuture,
                    builder: (context, roleSnapshot) {
                      final roleCount = roleSnapshot.data ?? 0;
                      return FutureBuilder<int>(
                        future: peerAdsCountFuture,
                        builder: (context, adSnapshot) {
                          final adCount = adSnapshot.data ?? 0;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _actionChip(_tx('admin_review_role_requests', 'Review role requests'), _tx('admin_pending_count', '{count} pending').replaceAll('{count}', '$roleCount'), const Color(0xFF4F6BFF)),
                              _actionChip(_tx('admin_approve_ads', 'Approve ads'), _tx('admin_pending_count', '{count} pending').replaceAll('{count}', '$adCount'), const Color(0xFF00B894)),
                              _actionChip(_tx('admin_escalate_reports', 'Escalate reports'), _tx('admin_reports_count', '{count} reports').replaceAll('{count}', '$reports'), const Color(0xFFFFA726)),
                              _actionChip(_tx('admin_fraud_monitor', 'Fraud monitor'), _tx('admin_flags_count', '{count} flags').replaceAll('{count}', '$fraudFlags'), const Color(0xFFEF5350)),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationsQueue() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _operationsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final queue = snapshot.data!;
        final reports = (queue['reports'] as List? ?? const [])
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList();
        final fraudFlags = (queue['fraudFlags'] as List? ?? const [])
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList();
        final roleRequests = (queue['pendingRoleRequests'] as List? ?? const [])
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList();
        final peerAds = (queue['pendingPeerAds'] as List? ?? const [])
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              _tx('admin_operations_queue', 'Operations queue'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(_tx('admin_operations_queue_desc', 'Review customer reports, risk signals, and approvals from one place.')),
            _sectionCard(
              title: _tx('admin_customer_reports_count', 'Customer reports ({count})').replaceAll('{count}', '${reports.length}'),
              child: reports.isEmpty
                  ? Text(_tx('admin_no_reports_need_review', 'No reports currently need review.'))
                  : Column(
                      children: reports.map(_buildReportQueueItem).toList(),
                    ),
            ),
            _sectionCard(
              title: _tx('admin_risk_signals_count', 'Risk signals ({count})').replaceAll('{count}', '${fraudFlags.length}'),
              child: fraudFlags.isEmpty
                  ? Text(_tx('admin_no_fraud_flags_found', 'No fraud flags were found.'))
                  : Column(
                      children: fraudFlags.map((flag) {
                        final details = flag['details'];
                        return _buildOpsRow(
                          '${flag['reason'] ?? _tx('admin_unknown_risk', 'Unknown risk')}',
                          '${flag['ownerLabel'] ?? _tx('admin_unknown_reporter', 'Unknown user')}${details == null ? '' : ' | $details'}',
                          _tx('admin_review', 'Review'),
                          const Color(0xFFEF5350),
                        );
                      }).toList(),
                    ),
            ),
            _sectionCard(
              title: _tx('admin_pending_approvals', 'Pending approvals'),
              child: Column(
                children: [
                  _buildOpsRow(_tx('admin_op_role_requests', 'Role requests'), _tx('admin_awaiting_verification', '{count} awaiting verification').replaceAll('{count}', '${roleRequests.length}'), _tx('admin_open_tab', 'Open tab'), const Color(0xFF4F6BFF)),
                  _buildOpsRow(_tx('admin_op_peer_ads', 'Peer ads'), _tx('admin_awaiting_review', '{count} awaiting review').replaceAll('{count}', '${peerAds.length}'), _tx('admin_open_tab', 'Open tab'), const Color(0xFF00B894)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportQueueItem(Map<String, dynamic> report) {
    final status = '${report['status'] ?? _tx('admin_status_new', 'new')}';
    final target = '${report['targetName'] ?? _tx('admin_unknown_target', 'Unknown target')}';
    final detail = '${report['description'] ?? _tx('admin_no_description', 'No description')}';
    
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminReportDetailScreen(
              report: report,
              onTransition: (reportId, to, {rewardGranted = false}) => _transitionReport(reportId, to, rewardGranted: rewardGranted),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFA726).withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(target, style: const TextStyle(fontWeight: FontWeight.w800))),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 4),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Text('${report['reportType'] ?? _tx('admin_lbl_report', 'report')} | $status | ${report['reporterLabel'] ?? _tx('admin_unknown_reporter', 'Unknown reporter')}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, dynamic value, Color color) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpsRow(String title, String detail, String status, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, String meta, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(meta, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: _tx('admin_tab_analytics', 'Overview')),
              Tab(text: _tx('admin_tab_operations', 'Operations')),
              Tab(text: _tx('admin_tab_role_requests', 'Role Requests')),
              Tab(text: _tx('admin_tab_peer_ads', 'Peer Ads')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSummary(),
                _buildOperationsQueue(),
                _buildRoleRequests(),
                _buildPeerAds(),
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
