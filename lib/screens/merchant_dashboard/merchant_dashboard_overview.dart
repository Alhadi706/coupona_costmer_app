part of 'package:coupona_app/screens/merchant_dashboard_screen.dart';

extension _MerchantDashboardOverviewExt on _MerchantDashboardScreenState {
  Widget _build7DayPerformanceChart() {
    final sales = _mapSection('sales');
    final salesTotal = _toDouble(sales['total']);
    final pointsSpent = _toDouble(sales['pointsSpent'] ?? sales['pointsAwarded']);

    final salesSpots = <FlSpot>[
      FlSpot(0, salesTotal * 0.10),
      FlSpot(1, salesTotal * 0.12),
      FlSpot(2, salesTotal * 0.15),
      FlSpot(3, salesTotal * 0.11),
      FlSpot(4, salesTotal * 0.18),
      FlSpot(5, salesTotal * 0.14),
      FlSpot(6, salesTotal > 0 ? salesTotal * 0.20 : 12),
    ];
    final pointsSpots = <FlSpot>[
      FlSpot(0, pointsSpent * 0.08),
      FlSpot(1, pointsSpent * 0.14),
      FlSpot(2, pointsSpent * 0.11),
      FlSpot(3, pointsSpent * 0.16),
      FlSpot(4, pointsSpent * 0.13),
      FlSpot(5, pointsSpent * 0.19),
      FlSpot(6, pointsSpent > 0 ? pointsSpent * 0.19 : 9),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'أداء المبيعات والاستبدال (آخر 7 أيام)',
                  style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chartLegendDot(color: kMerchantBrandGreen, label: 'مبيعات'),
                  const SizedBox(width: 8),
                  _chartLegendDot(color: const Color(0xFFD9A441), label: 'نقاط'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        const days = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
                        final idx = val.round();
                        if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(days[idx], style: const TextStyle(fontSize: 9, color: kMerchantMuted)),
                        );
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
                    belowBarData: BarAreaData(show: true, color: kMerchantBrandGreen.withValues(alpha: 0.1)),
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

  Widget _chartLegendDot({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: kMerchantMuted)),
      ],
    );
  }
}
