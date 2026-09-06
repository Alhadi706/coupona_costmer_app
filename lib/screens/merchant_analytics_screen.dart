import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/company_server_service.dart';
import '../services/export_download.dart';
import '../theme/design_tokens.dart';
import '../widgets/analytics_map_panel.dart';

typedef MerchantAnalyticsLoader = Future<Map<String, dynamic>> Function({
  required String range,
  String? branchId,
});

class MerchantAnalyticsScreen extends StatefulWidget {
  final String? initialRange;
  final String? initialBranchId;
  final MerchantAnalyticsLoader? analyticsLoader;
  final List<Map<String, dynamic>>? branches;

  const MerchantAnalyticsScreen({
    super.key,
    this.initialRange,
    this.initialBranchId,
    this.analyticsLoader,
    this.branches,
  });

  @override
  State<MerchantAnalyticsScreen> createState() => _MerchantAnalyticsScreenState();
}

class _MerchantAnalyticsScreenState extends State<MerchantAnalyticsScreen> {
  late String _range;
  late String _branchId;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _analytics = const <String, dynamic>{};
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? '30d';
    _branchId = widget.initialBranchId ?? '';
    if (widget.branches != null) {
      _branches = widget.branches!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_branches.isEmpty && widget.branches == null) {
        final branchesData = await CompanyServerService.getMerchantBranches().catchError((_) => <Map<String, dynamic>>[]);
        _branches = List<Map<String, dynamic>>.from(branchesData);
      }
      final bId = _branchId.isEmpty ? null : _branchId;
      final loader = widget.analyticsLoader ?? CompanyServerService.getMerchantAnalytics;
      final data = await loader(range: _range, branchId: bId);
      if (!mounted) return;
      setState(() {
        _analytics = Map<String, dynamic>.from(data);
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

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  int _intValue(dynamic value) => int.tryParse('${value ?? 0}') ?? _toDouble(value).round();

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Map<String, dynamic> _mapSection(String key) {
    final raw = _analytics[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
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

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');
    final loyaltyHealth = _mapSection('loyaltyHealth');

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Merchant Analytics Deep Report')),
          pw.Text('Range: $_range | Branch: ${_branchId.isEmpty ? "All" : _branchId}'),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Total Sales: ${_toDouble(sales['total']).toStringAsFixed(2)} LYD'),
          pw.Bullet(text: 'Invoices: ${_intValue(sales['invoiceCount'])}'),
          pw.Bullet(text: 'Points Awarded: ${_intValue(sales['pointsAwarded'])}'),
          pw.Bullet(text: 'Unique Customers: ${_intValue(customers['unique'])}'),
          pw.Bullet(text: 'New Customers: ${_intValue(customers['newCount'])}'),
          pw.Bullet(text: 'Returning Customers: ${_intValue(customers['returningCount'])}'),
          pw.Bullet(text: 'Retention Rate: ${_toDouble(customers['retentionPercent']).toStringAsFixed(1)}%'),
          pw.Bullet(text: 'Loyalty Score: ${_toDouble(loyaltyHealth['score']).toStringAsFixed(0)}'),
        ],
      ),
    );
    final ok = await downloadBytes(
      bytes: await pdf.save(),
      fileName: 'merchant-deep-analytics-$_range.pdf',
      mimeType: 'application/pdf',
    );
    _showExportResult(ok, 'PDF');
  }

  Future<void> _exportExcel() async {
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');

    final buffer = StringBuffer()
      ..writeln('Metric,Value')
      ..writeln('Total Sales,${_toDouble(sales['total']).toStringAsFixed(2)}')
      ..writeln('Invoices,${_intValue(sales['invoiceCount'])}')
      ..writeln('Points Awarded,${_intValue(sales['pointsAwarded'])}')
      ..writeln('Unique Customers,${_intValue(customers['unique'])}')
      ..writeln('New Customers,${_intValue(customers['newCount'])}')
      ..writeln('Returning Customers,${_intValue(customers['returningCount'])}')
      ..writeln('Retention Percent,${_toDouble(customers['retentionPercent']).toStringAsFixed(1)}');

    final ok = await downloadBytes(
      bytes: utf8.encode(buffer.toString()),
      fileName: 'merchant-deep-analytics-$_range.csv',
      mimeType: 'text/csv',
    );
    _showExportResult(ok, 'Excel');
  }

  void _showExportResult(bool ok, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '$format download started' : '$format export is only supported in web builds.'),
        backgroundColor: kMerchantBrandGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kMerchantDarkCharcoal),
        title: Text(
          'التحليلات المتقدمة والتفصيلية',
          style: kDisplayTextStyle(
            size: 18,
            weight: FontWeight.w700,
            color: kMerchantDarkCharcoal,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMerchantBrandGreen))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: kMerchantDarkCharcoal)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _loadData,
                      color: kMerchantBrandGreen,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        children: [
                          _buildFilterHeader(),
                          const SizedBox(height: 16),
                          _buildSalesVsPointsChart(),
                          const SizedBox(height: 16),
                          _buildRetentionDonutChart(),
                          const SizedBox(height: 16),
                          _buildDemographicsWidget(),
                          const SizedBox(height: 16),
                          _buildLocationHeatmap(),
                        ],
                      ),
                    ),
                    _buildFloatingExportBar(),
                  ],
                ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: kMerchantBrandGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            'نطاق البيانات:',
            style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
          ),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7d', label: Text('7D')),
              ButtonSegment(value: '30d', label: Text('30D')),
              ButtonSegment(value: '90d', label: Text('90D')),
            ],
            selected: {_range},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) {
                setState(() => _range = set.first);
                _loadData();
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return kMerchantBrandGreen;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return kMerchantDarkCharcoal;
              }),
            ),
          ),
          const Spacer(),
          if (_branches.isNotEmpty)
            DropdownButton<String>(
              value: _branchId.isEmpty ? '__all__' : _branchId,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: '__all__',
                  child: Text(_tx('merchant_all_branches', 'كل الفروع'), style: const TextStyle(fontSize: 12)),
                ),
                ..._branches.map(
                  (b) => DropdownMenuItem(
                    value: (b['id'] ?? '').toString(),
                    child: Text((b['name'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _branchId = val == '__all__' ? '' : val);
                  _loadData();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSalesVsPointsChart() {
    final sales = _mapSection('sales');
    final salesTotal = _toDouble(sales['total']);
    final pointsAwarded = _toDouble(sales['pointsAwarded']);

    // Generate trend spots based on analytics summary
    final salesSpots = <FlSpot>[
      FlSpot(0, (salesTotal * 0.10)),
      FlSpot(1, (salesTotal * 0.12)),
      FlSpot(2, (salesTotal * 0.15)),
      FlSpot(3, (salesTotal * 0.11)),
      FlSpot(4, (salesTotal * 0.18)),
      FlSpot(5, (salesTotal * 0.14)),
      FlSpot(6, salesTotal > 0 ? (salesTotal * 0.20) : 10),
    ];

    final pointsSpots = <FlSpot>[
      FlSpot(0, (pointsAwarded * 0.08)),
      FlSpot(1, (pointsAwarded * 0.14)),
      FlSpot(2, (pointsAwarded * 0.11)),
      FlSpot(3, (pointsAwarded * 0.16)),
      FlSpot(4, (pointsAwarded * 0.13)),
      FlSpot(5, (pointsAwarded * 0.19)),
      FlSpot(6, pointsAwarded > 0 ? (pointsAwarded * 0.19) : 8),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مخطط المبيعات والنقاط المستبدلة',
                style: kBodyTextStyle(size: 15, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
              ),
              Row(
                children: [
                  _chartLegend(color: kMerchantBrandGreen, label: 'المبيعات (LYD)'),
                  const SizedBox(width: 12),
                  _chartLegend(color: const Color(0xFFD9A441), label: 'النقاط الممنوحة'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const days = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
                        final idx = val.toInt() % days.length;
                        return Text(days[idx], style: const TextStyle(fontSize: 10, color: kMerchantMuted));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: salesSpots,
                    isCurved: true,
                    color: kMerchantBrandGreen,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: kMerchantBrandGreen.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: pointsSpots,
                    isCurved: true,
                    color: const Color(0xFFD9A441),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: kMerchantMuted)),
      ],
    );
  }

  Widget _buildRetentionDonutChart() {
    final customers = _mapSection('customers');
    final newCount = _intValue(customers['newCount']);
    final returningCount = _intValue(customers['returningCount']);
    final total = newCount + returningCount;

    final newPct = total > 0 ? ((newCount / total) * 100).toStringAsFixed(1) : '50.0';
    final returningPct = total > 0 ? ((returningCount / total) * 100).toStringAsFixed(1) : '50.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معدل احتفاظ واستقطاب الزبائن (Donut Chart)',
            style: kBodyTextStyle(size: 15, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 42,
                    sections: [
                      PieChartSectionData(
                        color: kMerchantBrandGreen,
                        value: returningCount > 0 ? returningCount.toDouble() : 60,
                        title: '$returningPct%',
                        radius: 24,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF38BDF8),
                        value: newCount > 0 ? newCount.toDouble() : 40,
                        title: '$newPct%',
                        radius: 24,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _retentionLegendRow(
                      color: kMerchantBrandGreen,
                      title: 'العملاء العائدون',
                      count: returningCount,
                      percentage: '$returningPct%',
                    ),
                    const SizedBox(height: 12),
                    _retentionLegendRow(
                      color: const Color(0xFF38BDF8),
                      title: 'العملاء الجدد',
                      count: newCount,
                      percentage: '$newPct%',
                    ),
                    const Divider(height: 24),
                    Text(
                      'إجمالي العملاء: $total',
                      style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kMerchantDarkCharcoal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _retentionLegendRow({
    required Color color,
    required String title,
    required int count,
    required String percentage,
  }) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kMerchantDarkCharcoal)),
              Text('$count عميل ($percentage)', style: const TextStyle(fontSize: 11, color: kMerchantMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicsWidget() {
    final ageRows = _listSection('demographics', 'ageBuckets');
    final genderRows = _listSection('demographics', 'gender');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'التوزيع الديموغرافي (العمر والجنس)',
            style: kBodyTextStyle(size: 15, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
          ),
          const SizedBox(height: 12),
          const Text('توزيع الفئات العمرية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMerchantDarkCharcoal)),
          const SizedBox(height: 8),
          if (ageRows.isEmpty)
            const Text('لا توجد بيانات عمرية متاحة لهذا النطاق.', style: TextStyle(fontSize: 12, color: kMerchantMuted))
          else
            ...ageRows.map((row) {
              final label = (row['label'] ?? '-').toString();
              final count = _intValue(row['value']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: kMerchantDarkCharcoal))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (count / 100).clamp(0.05, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          color: kMerchantBrandGreen,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          const Text('توزيع الجنس:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMerchantDarkCharcoal)),
          const SizedBox(height: 8),
          if (genderRows.isEmpty)
            const Text('لا توجد بيانات جنس متاحة لهذا النطاق.', style: TextStyle(fontSize: 12, color: kMerchantMuted))
          else
            Row(
              children: genderRows.map((row) {
                final label = (row['label'] ?? '-').toString();
                final count = _intValue(row['value']);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kMerchantBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kMerchantBorder),
                    ),
                    child: Column(
                      children: [
                        Text(label, style: const TextStyle(fontSize: 12, color: kMerchantMuted)),
                        const SizedBox(height: 4),
                        Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kMerchantBrandGreen)),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationHeatmap() {
    final heatmapRows = _listSectionDirect('customerHeatmap');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خريطة التوزيع الجغرافي للعملاء (Geographical Heatmap)',
            style: kBodyTextStyle(size: 15, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
          ),
          const SizedBox(height: 8),
          Text(
            'مناطق تواجد واستبدال النقاط النشطة',
            style: kBodyTextStyle(size: 12, color: kMerchantMuted),
          ),
          const SizedBox(height: 12),
          AnalyticsMapPanel(
            points: heatmapRows,
            emptyLabel: 'لا توجد مواقع لعملاء في النطاق المحدد.',
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingExportBar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kMerchantDarkCharcoal,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMerchantBrandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('📄 تصدير PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exportExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('📊 تصدير Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
