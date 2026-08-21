const fs = require('fs');
const file = 'lib/screens/admin_dashboard_screen.dart';
let txt = fs.readFileSync(file, 'utf8');

const regex = /final salesSpots = activity\.asMap\(\)\.entries\.map\(\(entry\) \{[\s\S]*?final brandsPct = \(brands > 0 \? \(brands \/ \(users \+ merchants \+ brands\)\) \* 100 : 0\)\.toDouble\(\);\n\n        final salesSpots = activity\.asMap\(\)\.entries\.map\(\(entry\) \{[\s\S]*?final brandsPct = \(brands > 0 \? \(brands \/ \(users \+ merchants \+ brands\)\) \* 100 : 0\)\.toDouble\(\);/m;

const replacement = `final salesSpots = activity.asMap().entries.map((entry) {
          final value = entry.value;
          final dailySales = double.tryParse('\${value['dailySales'] ?? 0}') ?? 0;
          return FlSpot(entry.key.toDouble(), dailySales);
        }).toList();

        final usersPct = (users > 0 ? (users / (users + merchants + brands)) * 100 : 0).toDouble();
        final merchantsPct = (merchants > 0 ? (merchants / (users + merchants + brands)) * 100 : 0).toDouble();
        final brandsPct = (brands > 0 ? (brands / (users + merchants + brands)) * 100 : 0).toDouble();`;

txt = txt.replace(regex, replacement);

const oldCharts = `            const SizedBox(height: 12),
            _sectionCard(
              title: _tx('admin_platform_activity', 'Platform activity (30 days)'),
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
                          getTitlesWidget: (value, meta) => Text('\${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
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
                    ],
                  ),
                ),
              ),
            ),
            _sectionCard(
              title: _tx('admin_operational_pulse', 'Operational pulse'),`;

const newCharts = `            const SizedBox(height: 12),
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
                                getTitlesWidget: (value, meta) => Text('\${value.toInt() + 1}', style: const TextStyle(fontSize: 10)),
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
                                  PieChartSectionData(color: const Color(0xFF7C4DFF), value: usersPct, title: '\${usersPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  PieChartSectionData(color: const Color(0xFF4F6BFF), value: merchantsPct, title: '\${merchantsPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  PieChartSectionData(color: const Color(0xFF00B894), value: brandsPct, title: '\${brandsPct.toStringAsFixed(0)}%', radius: 25, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            _sectionCard(
              title: _tx('admin_operational_pulse', 'Operational pulse'),`;

txt = txt.replace(oldCharts, newCharts);
fs.writeFileSync(file, txt);
