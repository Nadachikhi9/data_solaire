import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';

/// Paired perf / 3D band: keep in sync with [Tracker3dWidget] side‑by‑side layout.
const EdgeInsets kDashboardPairCardInset =
    EdgeInsets.fromLTRB(16, 18, 16, 12);
const double kDashboardPairPlotHeight = 280;

class PowerChartWidget extends GetView<DashboardController> {
  const PowerChartWidget({super.key, this.fillVertical = false});

  final bool fillVertical;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: AppTheme.bentoDecoration(),
        clipBehavior: Clip.hardEdge,
        child: Padding(
          padding: kDashboardPairCardInset,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final outerH = constraints.maxHeight.isFinite &&
                      constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : kDashboardPairPlotHeight;

              final h = fillVertical ? outerH : kDashboardPairPlotHeight;

              return SizedBox(
                width: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : double.infinity,
                height: h.isFinite ? h : kDashboardPairPlotHeight,
                child: Obx(() {
                  final spots = controller.powerSpots.toList();
                  final maxY = controller.chartMaxY.value ?? 100;
                  final minX = controller.chartViewportMin.value;
                  final maxX = controller.chartViewportMax.value;
                  final hub = controller.lastTelemetryUpdatedMs.value;

                  if (spots.isEmpty) {
                    final msg = hub == null
                        ? AppStrings.chartWaitingSerial
                        : AppStrings.chartNoPowerYet;
                    return Center(
                      child: Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppTheme.onMuted,
                              height: 1.45,
                            ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
                  }

                  return LayoutBuilder(
                    builder: (context, lc) {
                      const leftTitles = 44.0;
                      final plotW = (lc.maxWidth - leftTitles)
                          .clamp(64.0, 2000.0);

                      return Directionality(
                        textDirection: TextDirection.ltr,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: controller.resetPowerChartToLive,
                          onHorizontalDragUpdate: (details) {
                            controller.onPowerChartPan(
                              details.delta.dx,
                              plotW,
                            );
                          },
                          child: LineChart(
                            LineChartData(
                              minX: minX,
                              maxX: maxX,
                              minY: 0,
                              maxY: maxY,
                              clipData: const FlClipData.all(),
                              lineTouchData: LineTouchData(
                                handleBuiltInTouches: true,
                                touchTooltipData: LineTouchTooltipData(
                                  fitInsideHorizontally: true,
                                  fitInsideVertically: true,
                                  getTooltipColor: (_) =>
                                      AppTheme.surfaceHigh
                                          .withValues(alpha: 0.95),
                                  getTooltipItems: (touched) {
                                    return touched
                                        .map(
                                          (s) => LineTooltipItem(
                                            '${s.y.toStringAsFixed(1)} W',
                                            TextStyle(
                                              color: AppTheme.onSurface,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                        .toList();
                                  },
                                ),
                              ),
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
                                      style: TextStyle(
                                        color: AppTheme.onMuted,
                                        fontSize: 11,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (v, m) => Text(
                                      '${v.toStringAsFixed(0)}s',
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
                                horizontalInterval: (maxY / 4)
                                    .clamp(1, double.infinity),
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: AppTheme.borderStrong
                                      .withValues(alpha: 0.5),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: AppTheme.borderStrong
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  curveSmoothness: 0.28,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.teal, AppTheme.violet],
                                  ),
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppTheme.teal.withValues(alpha: 0.28),
                                        AppTheme.violet.withValues(alpha: 0.04),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            duration: 280.ms,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      );
                    },
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
