import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';

class PointsScreen extends StatelessWidget {
  final String userId;
  const PointsScreen({super.key, required this.userId});

  Future<int> fetchPoints() async {
    final user = await CompanyServerService.getUserById(userId);
    if (user == null) return 0;
    final points = user['points'];
    if (points is int) return points;
    if (points is num) return points.toInt();
    return int.tryParse(points?.toString() ?? '') ?? 0;
  }

  Future<List<int>> fetchPointsHistory() async {
    // جلب آخر 7 أيام من النقاط (أو بيانات تجريبية إذا لم تتوفر)
    final user = await CompanyServerService.getUserById(userId);
    if (user != null && user['points_history'] != null) {
      final List<dynamic> history = user['points_history'];
      return history.cast<int>();
    }
    // بيانات تجريبية في حال عدم وجود نقاط تاريخية
    return [10, 20, 15, 30, 25, 40, 35];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: fetchPointsHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data ?? [0, 0, 0, 0, 0, 0, 0];
        final points = history.isNotEmpty ? history.last : 0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('my_points_value'.tr(namedArgs: {'points': '$points'}), style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                        return Text('day_value'.tr(namedArgs: {'day': '${(value + 1).toInt()}'}));
                      }),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(history.length, (i) => FlSpot(i.toDouble(), history[i].toDouble())),
                      isCurved: true,
                      color: Colors.deepPurple,
                      barWidth: 4,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('points_progress_last_7_days'.tr(), style: const TextStyle(fontSize: 16)),
          ],
        );
      },
    );
  }
}