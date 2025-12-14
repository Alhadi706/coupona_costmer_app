import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/analytics/customer_analytics_service.dart';

class CustomerAnalyticsScreen extends StatefulWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  State<CustomerAnalyticsScreen> createState() =>
      _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState extends State<CustomerAnalyticsScreen> {
  final CustomerAnalyticsService _service = CustomerAnalyticsService();
  Future<CustomerAnalyticsSnapshot>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _future = null);
      return;
    }
    setState(() {
      _future = _service.load(user.uid);
    });
  }

  Future<void> _handleRefresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _future = null);
      return;
    }
    final future = _service.load(user.uid);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('customer_analytics_title'.tr()),
          backgroundColor: Colors.deepPurple.shade700,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Colors.deepPurple.shade200,
                ),
                const SizedBox(height: 12),
                Text(
                  'customer_analytics_sign_in'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('customer_analytics_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'customer_analytics_refresh'.tr(),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: FutureBuilder<CustomerAnalyticsSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _handleRefresh);
          }
          if (!snapshot.hasData) {
            return _EmptyState(onRetry: _handleRefresh);
          }
          final data = snapshot.data!;
          final locale = context.locale;
          final currencyFormatter = NumberFormat.compactCurrency(
            locale: locale.toLanguageTag(),
            decimalDigits: 1,
            symbol: 'SAR ',
          );
          final numberFormatter = NumberFormat.decimalPattern(
            locale.toLanguageTag(),
          );
          final dateFormatter = DateFormat.yMMMd(locale.toLanguageTag());

          final metrics = [
            _AnalyticsMetric(
              title: 'customer_analytics_total_spent'.tr(),
              value: currencyFormatter.format(data.totalSpend),
              icon: Icons.payments_outlined,
              color: Colors.deepPurple,
            ),
            _AnalyticsMetric(
              title: 'customer_analytics_total_invoices'.tr(),
              value: numberFormatter.format(data.totalInvoices),
              icon: Icons.receipt_long,
              color: Colors.indigo,
            ),
            _AnalyticsMetric(
              title: 'customer_analytics_unique_stores'.tr(),
              value: numberFormatter.format(data.uniqueStores),
              icon: Icons.store_mall_directory,
              color: Colors.pinkAccent,
            ),
            _AnalyticsMetric(
              title: 'customer_analytics_registered_stores'.tr(),
              value: numberFormatter.format(data.registeredStores),
              icon: Icons.how_to_reg,
              color: Colors.green,
            ),
            _AnalyticsMetric(
              title: 'customer_analytics_avg_ticket'.tr(),
              value: currencyFormatter.format(data.averageInvoiceValue),
              icon: Icons.trending_up,
              color: Colors.orange,
            ),
            _AnalyticsMetric(
              title: 'customer_analytics_monthly_invoices'.tr(),
              value: numberFormatter.format(data.monthlyInvoices),
              icon: Icons.calendar_today,
              color: Colors.teal,
            ),
            _AnalyticsMetric(
              title: 'customer_analytics_monthly_spend'.tr(),
              value: currencyFormatter.format(data.monthlySpend),
              icon: Icons.stacked_line_chart,
              color: Colors.blueGrey,
            ),
          ];

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MetricsGrid(metrics: metrics),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'customer_analytics_top_merchants'.tr(),
                  child: data.topMerchants.isEmpty
                      ? _SectionPlaceholder(
                          message: 'customer_analytics_no_merchants'.tr(),
                        )
                      : Column(
                          children: [
                            for (final merchant in data.topMerchants)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.deepPurple.shade50,
                                  child: Text(
                                    _buildInitials(merchant.merchantName),
                                    style: const TextStyle(
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ),
                                title: Text(merchant.merchantName),
                                subtitle: Text(
                                  '${numberFormatter.format(merchant.invoicesCount)} ${'customer_analytics_invoice_suffix'.tr()} · ${currencyFormatter.format(merchant.totalSpend)}',
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'customer_analytics_recent_invoices'.tr(),
                  child: data.recentInvoices.isEmpty
                      ? _SectionPlaceholder(
                          message: 'customer_analytics_no_invoices'.tr(),
                        )
                      : Column(
                          children: [
                            for (final invoice in data.recentInvoices)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.receipt_long,
                                  color: Colors.deepPurple,
                                ),
                                title: Text(
                                  invoice.merchantName.isEmpty
                                      ? '—'
                                      : invoice.merchantName,
                                ),
                                subtitle: Text(
                                  '${currencyFormatter.format(invoice.amount)} · ${invoice.createdAt != null ? dateFormatter.format(invoice.createdAt!) : '—'}',
                                ),
                                trailing: Chip(
                                  label: Text(invoice.status.toUpperCase()),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsMetric {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _MetricsGrid extends StatelessWidget {
  final List<_AnalyticsMetric> metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _AnalyticsMetric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: metric.color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(metric.icon, color: metric.color),
            const SizedBox(height: 12),
            Text(
              metric.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: metric.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metric.title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final String message;
  const _SectionPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.redAccent.shade200),
          const SizedBox(height: 12),
          Text('customer_analytics_error'.tr()),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text('customer_analytics_retry'.tr()),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: Colors.deepPurple.shade200,
          ),
          const SizedBox(height: 12),
          Text('customer_analytics_empty'.tr()),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text('customer_analytics_retry'.tr()),
          ),
        ],
      ),
    );
  }
}

String _buildInitials(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  final firstRune = trimmed.runes.first;
  return String.fromCharCode(firstRune).toUpperCase();
}
