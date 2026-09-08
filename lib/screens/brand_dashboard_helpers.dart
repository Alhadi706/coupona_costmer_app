part of 'package:coupona_app/screens/brand_dashboard_screen.dart';

class BrandAnalyticsDropdown extends StatelessWidget {
  final Key fieldKey;
  final String label;
  final String value;
  final List<Map<String, dynamic>> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const BrandAnalyticsDropdown({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        key: fieldKey,
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          DropdownMenuItem(value: '', child: Text('brand_filter_all'.tr())),
          ...options.map((option) => DropdownMenuItem(
            value: (option['value'] ?? '').toString(),
            child: Text((option['label'] ?? option['value'] ?? '-').toString(), overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: enabled ? (selected) => onChanged(selected ?? '') : null,
      ),
    );
  }
}

extension _BrandDashboardHelpers on _BrandDashboardScreenState {
  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
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
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF5B5F66), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF18222F)),
              ),
              Text(subtitle, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return BrandAnalyticsCharts(analytics: _analytics);
  }

  Widget _buildSalesChart(List<Map<String, dynamic>> stores, List<Map<String, dynamic>> products) {
    final entries = stores.take(5).toList(growable: false);
    final maxValue = entries.fold<double>(0, (max, row) => max > _toDouble(row['salesTotal']) ? max : _toDouble(row['salesTotal']));
    if (entries.isEmpty || maxValue <= 0) return const SizedBox.shrink();
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
              barGroups: List<BarChartGroupData>.generate(entries.length, (index) => BarChartGroupData(x: index, barRods: [BarChartRodData(toY: _toDouble(entries[index]['salesTotal']), color: const Color(0xFF1B7A66), width: 18, borderRadius: BorderRadius.circular(4))])),
            ),
          ),
        ),
        if (products.isNotEmpty) Text('أفضل منتج: ${(products.first['name'] ?? '-').toString()} • ${_money(products.first['salesTotal'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
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

  double _toDouble(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

  List<Map<String, dynamic>> _analyticsOptions(String key) {
    final filterOptions = _analytics['filterOptions'];
    if (filterOptions is! Map || filterOptions[key] is! List) return const [];
    return (filterOptions[key] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
  }

  List<Map<String, dynamic>> _listSection(String key) {
    return _listSectionFrom(_analytics, key);
  }

  List<Map<String, dynamic>> _listSectionFrom(Map<String, dynamic> source, String key) {
    final raw = source[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList(growable: false);
  }

  String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  String _money(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    return double.tryParse((value ?? '').toString())?.toStringAsFixed(2) ?? '0.00';
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
