import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'analytics_map_panel.dart';

class BrandAnalyticsCharts extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const BrandAnalyticsCharts({super.key, required this.analytics});

  static const _gold = Color(0xFFE0A21A);
  static const _teal = Color(0xFF1B7A66);
  static const _blue = Color(0xFF2E80ED);
  static const _violet = Color(0xFF6C63FF);

  double _number(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;
  int _integer(dynamic value) => int.tryParse('${value ?? 0}') ?? _number(value).round();
  String _money(dynamic value) => _number(value).toStringAsFixed(2);

  List<Map<String, dynamic>> _list(String key) {
    final value = analytics[key];
    if (value is! List) return const [];
    return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  List<Map<String, dynamic>> _nestedList(String section, String key) {
    final value = analytics[section];
    if (value is! Map || value[key] is! List) return const [];
    return (value[key] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  bool _hasPositive(List<Map<String, dynamic>> rows, String key) => rows.any((row) => _number(row[key]) > 0);

  @override
  Widget build(BuildContext context) {
    final topStores = _list('topSellingStores');
    final lowStores = _list('lowestSellingStores');
    final products = _list('topProducts');
    final dailySales = _list('dailySales');
    final growth = _list('growthLevels');
    final heatmap = _list('distributionHeatmap');
    final genders = _nestedList('consumerDemographics', 'gender');
    final ages = _nestedList('consumerDemographics', 'ageBuckets');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 920 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(width, Icons.payments_outlined, 'brand_metric_sales'.tr(), _money(analytics['matchedSales']), _gold),
                _metric(width, Icons.people_outline, 'brand_metric_customers'.tr(), '${_integer(analytics['matchedCustomers'])}', _blue),
                _metric(width, Icons.storefront_outlined, 'brand_metric_stores'.tr(), '${topStores.length}', _teal),
                _metric(width, Icons.inventory_2_outlined, 'brand_metric_products'.tr(), '${products.length}', _violet),
                _metric(width, Icons.stars_outlined, 'brand_metric_points_issued'.tr(), '${_integer(analytics['pointsIssued'])}', _gold),
                _metric(width, Icons.card_giftcard_outlined, 'brand_metric_reward_claims'.tr(), '${_integer(analytics['rewardClaims'])}', _violet),
                _metric(width, Icons.percent, 'brand_metric_redemption_rate'.tr(), '${_money(analytics['redemptionRate'])}%', _teal),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (analytics['demographicsSuppressed'] == true) ...[
          Container(
            key: const Key('brand-demographics-privacy-notice'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, color: _blue),
                const SizedBox(width: 8),
                Expanded(child: Text('brand_demographics_privacy_notice'.tr())),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 900 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_daily_sales'.tr(),
                    icon: Icons.show_chart,
                    hasData: _hasPositive(dailySales, 'sales'),
                    child: _lineChart(dailySales),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_redemption'.tr(),
                    icon: Icons.pie_chart_outline,
                    hasData: _number(analytics['pointsIssued']) > 0,
                    child: _redemptionChart(),
                    legend: _redemptionLegend(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_top_stores'.tr(),
                    icon: Icons.storefront_outlined,
                    hasData: _hasPositive(topStores, 'salesTotal'),
                    child: _barChart(topStores, valueKey: 'salesTotal', color: _teal),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_products'.tr(),
                    icon: Icons.inventory_2_outlined,
                    hasData: _hasPositive(products, 'salesTotal'),
                    child: _barChart(products, valueKey: 'salesTotal', color: _violet),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_growth'.tr(),
                    icon: Icons.trending_up,
                    hasData: growth.any((row) => _number(row['current']) > 0 || _number(row['previous']) > 0),
                    child: _growthChart(growth),
                    legend: _growthLegend(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_low_stores'.tr(),
                    icon: Icons.trending_down,
                    hasData: _hasPositive(lowStores, 'salesTotal'),
                    child: _barChart(lowStores, valueKey: 'salesTotal', color: _gold),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_gender'.tr(),
                    icon: Icons.donut_large,
                    hasData: _hasPositive(genders, 'value'),
                    child: _pieChart(genders),
                    legend: _categoryLegend(genders),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _chartCard(
                    context,
                    title: 'brand_chart_age'.tr(),
                    icon: Icons.bar_chart,
                    hasData: _hasPositive(ages, 'value'),
                    child: _barChart(ages, valueKey: 'value', labelKey: 'label', color: _blue),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _mapCard(context, heatmap),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _metric(double width, IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: width,
      child: Container(
        key: Key('brand-analytics-metric-$label'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool hasData,
    required Widget child,
    Widget? legend,
  }) {
    return Card(
      key: Key('brand-chart-$title'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: _gold),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: hasData ? child : _emptyChart(),
            ),
            if (hasData && legend != null) ...[
              const SizedBox(height: 8),
              legend,
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyChart() {
    return Center(
      key: const Key('brand-chart-empty'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats, size: 38, color: Colors.grey.withValues(alpha: 0.65)),
          const SizedBox(height: 8),
          Text('brand_chart_empty'.tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _lineChart(List<Map<String, dynamic>> rows) {
    final values = rows.take(31).toList(growable: false);
    final maxValue = values.fold<double>(0, (maximum, row) => _number(row['sales']) > maximum ? _number(row['sales']) : maximum);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxValue * 1.2,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.18), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: _titles(values, labelKey: 'date', left: true),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem(_money(spot.y), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList())),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: _gold,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: _gold.withValues(alpha: 0.14)),
            spots: List.generate(values.length, (index) => FlSpot(index.toDouble(), _number(values[index]['sales']))),
          ),
        ],
      ),
    );
  }

  Widget _barChart(List<Map<String, dynamic>> rows, {required String valueKey, String labelKey = 'name', required Color color}) {
    final values = rows.take(6).toList(growable: false);
    final maxValue = values.fold<double>(0, (maximum, row) => _number(row[valueKey]) > maximum ? _number(row[valueKey]) : maximum);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxValue * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.18), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: _titles(values, labelKey: labelKey),
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(_money(rod.toY), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        barGroups: List.generate(
          values.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [BarChartRodData(toY: _number(values[index][valueKey]), width: 18, color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
          ),
        ),
      ),
    );
  }

  Widget _growthChart(List<Map<String, dynamic>> rows) {
    final values = rows.take(6).map((row) {
      final localized = Map<String, dynamic>.from(row);
      localized['label'] = _growthLabel(row);
      return localized;
    }).toList(growable: false);
    final maxValue = values.fold<double>(0, (maximum, row) {
      final rowMax = [_number(row['current']), _number(row['previous'])].reduce((a, b) => a > b ? a : b);
      return rowMax > maximum ? rowMax : maximum;
    });
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxValue * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.18), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: _titles(values, labelKey: 'label'),
        barGroups: List.generate(
          values.length,
          (index) => BarChartGroupData(
            x: index,
            barsSpace: 3,
            barRods: [
              BarChartRodData(toY: _number(values[index]['current']), width: 10, color: _gold, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
              BarChartRodData(toY: _number(values[index]['previous']), width: 10, color: _teal, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
            ],
          ),
        ),
      ),
    );
  }

  String _growthLabel(Map<String, dynamic> row) {
    final level = (row['level'] ?? '').toString();
    final label = (row['label'] ?? '').toString();
    if (level == 'overall' || label == 'Overall brand sales') return 'brand_growth_overall'.tr();
    if (level == 'store' || label == 'Top store') return 'brand_growth_top_store'.tr();
    if (level == 'product' || label == 'Top product') return 'brand_growth_top_product'.tr();
    return label.isEmpty ? '-' : label;
  }

  Widget _pieChart(List<Map<String, dynamic>> rows) {
    final values = rows.where((row) => _number(row['value']) > 0).take(6).toList(growable: false);
    final total = values.fold<double>(0, (sum, row) => sum + _number(row['value']));
    return PieChart(
      PieChartData(
        centerSpaceRadius: 42,
        sectionsSpace: 3,
        sections: List.generate(values.length, (index) {
          final value = _number(values[index]['value']);
          return PieChartSectionData(
            value: value,
            color: _palette[index % _palette.length],
            radius: 58,
            title: '${(value / total * 100).round()}%',
            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          );
        }),
      ),
    );
  }

  Widget _redemptionChart() {
    final issued = _number(analytics['pointsIssued']);
    final redeemed = _number(analytics['pointsRedeemed']).clamp(0, issued).toDouble();
    final remaining = (issued - redeemed).clamp(0, issued).toDouble();
    return PieChart(
      PieChartData(
        centerSpaceRadius: 48,
        sectionsSpace: 3,
        sections: [
          PieChartSectionData(value: redeemed, color: _gold, radius: 58, title: '${issued > 0 ? (redeemed / issued * 100).round() : 0}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          PieChartSectionData(value: remaining, color: _teal, radius: 58, title: ''),
        ],
      ),
    );
  }

  Widget _redemptionLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendItem(_gold, 'brand_chart_redeemed'.tr()),
        _legendItem(_teal, 'brand_chart_remaining'.tr()),
      ],
    );
  }

  FlTitlesData _titles(List<Map<String, dynamic>> rows, {required String labelKey, bool left = false}) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: left, reservedSize: 42, getTitlesWidget: (value, _) => Text(_compact(value), style: const TextStyle(fontSize: 9)))),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          getTitlesWidget: (value, _) {
            final index = value.toInt();
            if (index < 0 || index >= rows.length) return const SizedBox.shrink();
            var label = (rows[index][labelKey] ?? '-').toString();
            if (labelKey == 'date' && label.length >= 10) label = label.substring(5);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(width: 52, child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9))),
            );
          },
        ),
      ),
    );
  }

  String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  Widget _growthLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendItem(_gold, 'brand_chart_current'.tr()),
        _legendItem(_teal, 'brand_chart_previous'.tr()),
      ],
    );
  }

  Widget _categoryLegend(List<Map<String, dynamic>> rows) {
    final values = rows.where((row) => _number(row['value']) > 0).take(6).toList(growable: false);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: List.generate(values.length, (index) => _legendItem(_palette[index % _palette.length], (values[index]['label'] ?? '-').toString())),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _mapCard(BuildContext context, List<Map<String, dynamic>> heatmap) {
    return Card(
      key: const Key('brand-chart-map'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 19, color: _gold),
                const SizedBox(width: 8),
                Expanded(child: Text('brand_chart_distribution'.tr(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: heatmap.isEmpty
                  ? _emptyChart()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AnalyticsMapPanel(points: heatmap, emptyLabel: 'brand_chart_empty'.tr(), markerColor: _gold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static const _palette = [_gold, _teal, _blue, _violet, Color(0xFFC0524A), Color(0xFF607D8B)];
}
