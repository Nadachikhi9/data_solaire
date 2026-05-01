import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

class PowerChartWidget extends GetView<DashboardController> {
  const PowerChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: SizedBox(
            height: 260,
            child: Obx(() {
              final spots = controller.powerSpots.toList();
              final maxY = controller.chartMaxY.value ?? 100;
              final hub = controller.lastTelemetryUpdatedMs.value;

              if (spots.isEmpty) {
                final msg = hub == null
                    ? AppStrings.chartWaitingSerial
                    : AppStrings.chartNoPowerYet;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.onMuted),
                    ),
                  ),
                );
              }

              return LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, m) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppTheme.onMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) => Text(
                          '${v.toStringAsFixed(0)} s',
                          style: const TextStyle(
                            color: AppTheme.onMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.border.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: AppTheme.border),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2,
                      color: AppTheme.accent,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accent.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }),
          ),
        ),
      ),
    );
  }
}
