part of 'package:coupona_app/screens/merchant_dashboard_screen.dart';

extension _MerchantDashboardAnalyticsExt on _MerchantDashboardScreenState {
  Future<void> _exportAnalyticsPdf() async {
    final pdf = pw.Document();
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');
    final loyaltyHealth = _mapSection('loyaltyHealth');
    final financialSummary = _mapSection('financialSummary');
    final topProducts = _listSectionDirect('topBrandProducts');
    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Merchant Analytics Export')),
          pw.Text('Range: $_analyticsRange | Branch: ${_analyticsBranchId.isEmpty ? 'All' : _analyticsBranchId}'),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Sales: ${_money(sales['total'])}'),
          pw.Bullet(text: 'Invoices: ${_intValue(sales['invoiceCount'])}'),
          pw.Bullet(text: 'Points awarded: ${_intValue(sales['pointsAwarded'])}'),
          pw.Bullet(text: 'Unique customers: ${_intValue(customers['unique'])}'),
          pw.Bullet(text: 'New customers: ${_intValue(customers['newCount'])}'),
          pw.Bullet(text: 'Returning customers: ${_intValue(customers['returningCount'])}'),
          pw.Bullet(text: 'Retention: ${_numValue(customers['retentionPercent'])}%'),
          pw.Bullet(text: 'Churn: ${_numValue(customers['churnPercent'])}%'),
          pw.Bullet(text: 'Loyalty health: ${_numValue(loyaltyHealth['score'])} (${(loyaltyHealth['trend'] ?? 'stable').toString()})'),
          pw.Bullet(text: 'Point value: ${_money(financialSummary['pointValue'])}'),
          pw.SizedBox(height: 12),
          pw.Text('Top Brand Products'),
          ...topProducts.take(8).map((row) => pw.Bullet(text: '${(row['name'] ?? '-').toString()} | ${(row['brandName'] ?? '-').toString()} | ${_money(row['salesTotal'])}')),
        ],
      ),
    );
    final ok = await downloadBytes(
      bytes: await pdf.save(),
      fileName: 'merchant-analytics-$_analyticsRange.pdf',
      mimeType: 'application/pdf',
    );
    _showExportResult(ok, 'PDF');
  }

  Future<void> _exportAnalyticsExcel() async {
    final buffer = StringBuffer()
      ..writeln('section,label,value')
      ..writeln('sales,total,${_money(_mapSection('sales')['total'])}')
      ..writeln('sales,invoices,${_intValue(_mapSection('sales')['invoiceCount'])}')
      ..writeln('sales,points_awarded,${_intValue(_mapSection('sales')['pointsAwarded'])}')
      ..writeln('customers,unique,${_intValue(_mapSection('customers')['unique'])}')
      ..writeln('customers,new,${_intValue(_mapSection('customers')['newCount'])}')
      ..writeln('customers,returning,${_intValue(_mapSection('customers')['returningCount'])}')
      ..writeln('customers,retention_percent,${_numValue(_mapSection('customers')['retentionPercent'])}')
      ..writeln('customers,churn_percent,${_numValue(_mapSection('customers')['churnPercent'])}');
    for (final row in _listSectionDirect('topBrandProducts')) {
      buffer.writeln('top_brand_products,${(row['name'] ?? '-').toString()},${_money(row['salesTotal'])}');
    }
    final ok = await downloadBytes(
      bytes: utf8.encode(buffer.toString()),
      fileName: 'merchant-analytics-$_analyticsRange.csv',
      mimeType: 'text/csv',
    );
    _showExportResult(ok, 'Excel');
  }

  void _showExportResult(bool ok, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '$format download started' : '$format export is only supported in web builds.')),
    );
  }

  Widget _buildAnalyticsBlock(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMerchantBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kMerchantBorder, width: kBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantDarkCharcoal)),
          const SizedBox(height: 6),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: kBodyTextStyle(size: 12, weight: FontWeight.w500, color: kMerchantDarkCharcoal.withValues(alpha: 0.92))),
            ),
          ),
        ],
      ),
    );
  }

  String _money(dynamic value) => _MerchantDashboardHelpers.money(value);

  String _numValue(dynamic value) => _MerchantDashboardHelpers.numValue(value);

  int _intValue(dynamic value) => _MerchantDashboardHelpers.intValue(value);

  Map<String, dynamic>? _merchantSubscription() {
    final subscriptions = (_roles['subscriptions'] as List?) ?? const <dynamic>[];
    for (final row in subscriptions) {
      if (row is Map && row['roleType'] == 'merchant') {
        return Map<String, dynamic>.from(row);
      }
    }
    return null;
  }

  bool get _merchantReadOnly => (_merchantSubscription()?['status'] ?? '').toString() == 'suspended';

  bool get _merchantGracePeriod => (_merchantSubscription()?['status'] ?? '').toString() == 'grace_period';

  Map<String, dynamic> _mapSection(String key) {
    final raw = _analytics[key];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listSection(String outerKey, String innerKey) {
    final outer = _mapSection(outerKey);
    final raw = outer[innerKey];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _listSectionDirect(String key) {
    final raw = _analytics[key];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _formatCountRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '-';
    return rows.map((row) => '${(row['label'] ?? '-').toString()}: ${_intValue(row['value'])}').join(' | ');
  }
}
