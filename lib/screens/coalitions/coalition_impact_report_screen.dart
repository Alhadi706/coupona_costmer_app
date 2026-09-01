import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/company_server_service.dart';

/// Coalition Impact Report Screen - Shows merchant's contribution & fulfillment metrics
/// Part of Pro-Rata Multi-Sponsor Coalition Engine v3
class CoalitionImpactReportScreen extends StatefulWidget {
  final String coalitionId;
  final String coalitionName;

  const CoalitionImpactReportScreen({
    super.key,
    required this.coalitionId,
    required this.coalitionName,
  });

  @override
  State<CoalitionImpactReportScreen> createState() => _CoalitionImpactReportScreenState();
}

class _CoalitionImpactReportScreenState extends State<CoalitionImpactReportScreen> {
  bool _loading = false;
  Map<String, dynamic>? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await CompanyServerService.getCoalitionImpactReport(widget.coalitionId);
      setState(() => _report = report);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('coalition_impact_report_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'coalition_impact_refresh'.tr(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'coalition_impact_error'.tr(namedArgs: {'error': _error!}),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReport,
                          child: Text('coalition_impact_refresh'.tr()),
                        ),
                      ],
                    ),
                  ),
                )
              : _report == null
                  ? const Center(child: Text('No data'))
                  : RefreshIndicator(
                      onRefresh: _loadReport,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildContributorSection(),
                            const SizedBox(height: 24),
                            _buildFulfillerSection(),
                            const SizedBox(height: 24),
                            _buildCrossCustomersSection(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildContributorSection() {
    final asContributor = _report!['as_contributor'] as Map<String, dynamic>?;
    if (asContributor == null) return const SizedBox.shrink();

    final uniqueCustomers = asContributor['unique_customers'] ?? 0;
    final totalPoints = asContributor['total_points_contributed'] ?? 0;
    final avgPercentage = asContributor['avg_contribution_percentage'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volunteer_activism, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'coalition_impact_as_contributor'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'coalition_impact_unique_customers'.tr(namedArgs: {'count': uniqueCustomers.toString()}),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'coalition_impact_points_contributed'.tr(namedArgs: {'points': totalPoints.toString()}),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'coalition_impact_avg_contribution'.tr(namedArgs: {'percentage': avgPercentage.toStringAsFixed(1)}),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFulfillerSection() {
    final asFulfiller = _report!['as_fulfiller'] as Map<String, dynamic>?;
    if (asFulfiller == null) return const SizedBox.shrink();

    final uniqueCustomers = asFulfiller['unique_customers'] ?? 0;
    final totalPointsReceived = asFulfiller['total_points_received'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.redeem, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'coalition_impact_as_fulfiller'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'coalition_impact_customers_received'.tr(namedArgs: {'count': uniqueCustomers.toString()}),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'coalition_impact_points_received'.tr(namedArgs: {'points': totalPointsReceived.toString()}),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossCustomersSection() {
    final crossCustomers = _report!['recent_cross_coalition_customers'] as List<dynamic>?;
    if (crossCustomers == null || crossCustomers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'coalition_impact_cross_customers'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'coalition_impact_no_cross_customers'.tr(),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'coalition_impact_cross_customers'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            ...crossCustomers.map((customer) => _buildCustomerItem(customer)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerItem(dynamic customer) {
    final customerName = customer['customer_name'] ?? 'Unknown';
    final giftTitle = customer['gift_title'] ?? '';
    final pointsContributed = customer['points_contributed'] ?? 0;
    final contributionPercentage = customer['contribution_percentage'] ?? 0.0;
    final redeemedAt = customer['redeemed_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'coalition_impact_customer_name'.tr(namedArgs: {'name': customerName}),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'coalition_impact_gift_title'.tr(namedArgs: {'title': giftTitle}),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'coalition_impact_your_contribution'.tr(namedArgs: {
              'points': pointsContributed.toString(),
              'percentage': contributionPercentage.toStringAsFixed(1)
            }),
            style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'coalition_impact_redeemed_at'.tr(namedArgs: {'date': redeemedAt}),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
