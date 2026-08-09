import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/home/presentation/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glass_container.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String _selectedRange = 'Last 7 Days';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Analytics'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
        child: Column(
          children: [
            // Date Range Switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRange,

                  dropdownColor: Theme.of(context).colorScheme.surface,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                  items: ['Last 7 Days', 'Last 30 Days', 'This Quarter']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedRange = v!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 1. Downtime Trend
            _buildSectionHeader('Downtime Trend (Hours)'),
            const SizedBox(height: 16),
            GlassContainer(
              width: double.infinity,
              height: 250,
              borderRadius: 24,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(days[value.toInt()], style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10));
                        }
                        return const Text('');
                      })),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 3),
                          FlSpot(1, 1),
                          FlSpot(2, 4),
                          FlSpot(3, 2),
                          FlSpot(4, 5),
                          FlSpot(5, 1),
                          FlSpot(6, 0),
                        ],
                        isCurved: true,
                        color: AppColors.accent,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.accent.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            // 2. Faults by Area
            _buildSectionHeader('Faults by Area'),
            const SizedBox(height: 16),
            GlassContainer(
              width: double.infinity,
              height: 250,
              borderRadius: 24,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                        const areas = ['Unit A', 'Unit B', 'Pump', 'Gen'];
                        if (value.toInt() >= 0 && value.toInt() < areas.length) {
                          return Text(areas[value.toInt()], style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10));
                        }
                        return const Text('');
                      })),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: AppColors.error, width: 16, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 3, color: AppColors.warning, width: 16, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 5, color: AppColors.primaryLight, width: 16, borderRadius: BorderRadius.circular(4))]),
                      BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 2, color: AppColors.success, width: 16, borderRadius: BorderRadius.circular(4))]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
