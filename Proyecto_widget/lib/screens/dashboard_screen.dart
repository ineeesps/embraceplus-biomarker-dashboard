import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../providers/dashboard_provider.dart';
import '../models/biomarker.dart';
import '../widgets/quality_legend.dart';

class DashboardScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const DashboardScreen({super.key, required this.participantId, required this.username});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchMetrics(widget.participantId, widget.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Participante: ${widget.participantId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: () => _exportData(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}', style: const TextStyle(color: Colors.redAccent)),
                ],
              ),
            );
          }

          final metricsBySensor = provider.metricsBySensor;
          if (metricsBySensor.isEmpty) {
            return _buildEmptyState(context, provider);
          }

          return Column(
            children: [
              _buildTimeRangeSelector(context, provider),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: QualityLegend(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: metricsBySensor.entries.map((entry) {
                    return BiomarkerCard(
                      sensorType: entry.key,
                      data: entry.value,
                      provider: provider,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DashboardProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text('Sin datos en este rango', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.surface,
            ),
            onPressed: () => provider.setTimeRange(null, null, widget.participantId, widget.username),
            label: const Text('Ver día completo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(BuildContext context, DashboardProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            provider.startHour == null ? 'Sesión completa' : 'Tramo seleccionado',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          _TimeButton(
            label: provider.startHour?.format(context) ?? 'Inicio',
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: provider.startHour ?? const TimeOfDay(hour: 0, minute: 0));
              if (time != null) provider.setTimeRange(time, provider.endHour, widget.participantId, widget.username);
            },
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(color: Colors.white24))),
          _TimeButton(
            label: provider.endHour?.format(context) ?? 'Fin',
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: provider.endHour ?? const TimeOfDay(hour: 23, minute: 59));
              if (time != null) provider.setTimeRange(provider.startHour, time, widget.participantId, widget.username);
            },
          ),
          if (provider.startHour != null || provider.endHour != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
              onPressed: () => provider.setTimeRange(null, null, widget.participantId, widget.username),
            ),
        ],
      ),
    );
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando datos de ${widget.participantId}...'),
        backgroundColor: Colors.blue.shade900,
      ),
    );
  }
}

class BiomarkerCard extends StatelessWidget {
  final String sensorType;
  final List<Biomarker> data;
  final DashboardProvider provider;

  const BiomarkerCard({super.key, required this.sensorType, required this.data, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overlaySensor = provider.selectedOverlaySensor;
    final overlayData = (overlaySensor != null && overlaySensor != sensorType) 
        ? provider.metricsBySensor[overlaySensor] 
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSensorTitle(sensorType),
                        style: theme.textTheme.titleLarge,
                      ),
                      if (overlayData != null)
                        Text(
                          'VS ${_formatSensorTitle(overlaySensor!)}',
                          style: TextStyle(color: colorScheme.secondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildOverlayPicker(sensorType),
                    const SizedBox(width: 8),
                    _buildStatusTag(data.first.qualityFlag),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.any((b) => b.value != null)) _buildStatsTable(context, data),
            if (data.any((b) => b.value != null)) const SizedBox(height: 16),
            if (data.any((b) => b.value != null))
              SizedBox(
                height: overlayData != null ? 300 : 250,
                child: LineChart(_buildChartData(context, data, overlayData: overlayData)),
              )
            else 
               const SizedBox(
                 height: 100, 
                 child: Center(child: Text("Sin valores representables (Gaps de calidad)", style: TextStyle(color: Colors.white38)))
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayPicker(String currentSensor) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.layers_rounded, color: Colors.white54, size: 20),
      tooltip: 'Superponer otro sensor',
      onSelected: (sensor) {
        provider.setSelectedOverlaySensor(sensor == 'none' ? null : sensor);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'none', child: Text('Sin superposición')),
        ...provider.metricsBySensor.keys.where((s) => s != currentSensor).map((s) => PopupMenuItem(
          value: s,
          child: Text('Comparar con ${_formatSensorTitle(s)}'),
        )),
      ],
    );
  }

  Widget _buildStatsTable(BuildContext context, List<Biomarker> data) {
    final validValues = data.where((e) => e.value != null).map((e) => e.value!).toList();
    if (validValues.isEmpty) return const SizedBox();

    double mean = validValues.reduce((a, b) => a + b) / validValues.length;
    double min = validValues.reduce((a, b) => a < b ? a : b);
    double max = validValues.reduce((a, b) => a > b ? a : b);
    double variance = validValues.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / validValues.length;
    double sd = math.sqrt(variance);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'MEDIA', value: mean.toStringAsFixed(2)),
          _StatItem(label: 'SD', value: sd.toStringAsFixed(2)),
          _StatItem(label: 'MIN', value: min.toStringAsFixed(2)),
          _StatItem(label: 'MAX', value: max.toStringAsFixed(2)),
        ],
      ),
    );
  }

  String _formatSensorTitle(String sensorType) {
    if (sensorType == 'accelerometer_std') return 'ACELERÓMETRO (STD)';
    if (sensorType == 'acticounts_total') return 'ACTICOUNTS (TOTAL)';
    return sensorType.toUpperCase().replaceAll('_', ' ');
  }

  Widget _buildStatusTag(String flag) {
    Color color = const Color(0xFF10B981);
    String label = 'NORMAL';
    if (flag == 'worn_during_motion') { color = const Color(0xFFF59E0B); label = 'MOVIMIENTO'; }
    else if (flag == 'worn_with_low_signal_quality') { color = const Color(0xFFEF4444); label = 'SEÑAL BAJA'; }
    else if (flag == 'device_not_recording') { color = const Color(0xFF94A3B8); label = 'GAP'; }
    else if (flag == 'device_not_worn_correctly') { color = const Color(0xFF94A3B8); label = 'NO PUESTO'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  LineChartData _buildChartData(BuildContext context, List<Biomarker> data, {List<Biomarker>? overlayData}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayData = data;
    final List<LineChartBarData> bars = [];
    
    List<List<FlSpot>> segments = [];
    List<String> segmentQualities = [];
    
    if (displayData.isNotEmpty) {
      List<FlSpot> currentSegment = [];
      String currentQuality = displayData[0].qualityFlag;
      DateTime? lastTime = displayData[0].time;
      const int splitThresholdMs = 5 * 60 * 1000;

      for (int i = 0; i < displayData.length; i++) {
        final currentDT = displayData[i].time;
        double xVal = currentDT.toUtc().millisecondsSinceEpoch.toDouble();
        
        bool timeGap = lastTime != null && (currentDT.difference(lastTime).inMilliseconds).abs() > splitThresholdMs;
        bool qualityChange = displayData[i].qualityFlag != currentQuality;

        if (qualityChange || timeGap) {
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            segmentQualities.add(currentQuality);
          }
          currentSegment = [];
          currentQuality = displayData[i].qualityFlag;
        }

        if (displayData[i].value != null) {
          currentSegment.add(FlSpot(xVal, displayData[i].value!));
        }
        lastTime = currentDT;
      }
      if (currentSegment.isNotEmpty) {
        segments.add(currentSegment);
        segmentQualities.add(currentQuality);
      }
    }

    bars.addAll(segments.asMap().entries.map((entry) {
      final spots = entry.value;
      final quality = segmentQualities[entry.key];
      Color color = colorScheme.primary; 
      bool isProblematic = false;
      if (quality == 'worn_during_motion') { color = const Color(0xFFF59E0B); isProblematic = true; }
      else if (quality == 'worn_with_low_signal_quality') { color = const Color(0xFFEF4444); isProblematic = true; }
      else if (quality == 'device_not_recording') { color = const Color(0xFF94A3B8).withValues(alpha: 0.6); }
      else if (quality == 'device_not_worn_correctly') { color = const Color(0xFF94A3B8).withValues(alpha: 0.4); }

      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: isProblematic ? 2.5 : 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: isProblematic ? 0.3 : 0.15), color.withValues(alpha: 0.0)],
          ),
        ),
      );
    }));

    const int gapThresholdMs = 10 * 60 * 1000;
    for (int i = 0; i < segments.length - 1; i++) {
      final lastSpotOfCurrent = segments[i].last;
      final firstSpotOfNext = segments[i+1].first;
      
      if ((firstSpotOfNext.x - lastSpotOfCurrent.x).abs() < gapThresholdMs) {
        bars.add(LineChartBarData(
          spots: [lastSpotOfCurrent, firstSpotOfNext],
          isCurved: false,
          color: const Color(0xFF94A3B8).withValues(alpha: 0.6),
          barWidth: 1.5,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ));
      }
    }

    double scale = 1.0;
    bool hasOverlay = overlayData != null && overlayData.isNotEmpty;

    if (hasOverlay) {
      final validMain = displayData.where((e) => e.value != null).map((e) => e.value!);
      final validOverlay = overlayData.where((e) => e.value != null).map((e) => e.value!);
      
      double maxMain = validMain.isEmpty ? 100.0 : validMain.reduce((a, b) => a > b ? a : b);
      double maxOverlay = validOverlay.isEmpty ? 1.0 : validOverlay.reduce((a, b) => a > b ? a : b);
      
      if (maxOverlay > 0) scale = maxMain / maxOverlay;

      bars.add(LineChartBarData(
        spots: overlayData.asMap().entries.where((e) => e.value.value != null)
            .map((e) {
              double xVal = e.value.time.toUtc().millisecondsSinceEpoch.toDouble();
              return FlSpot(xVal, e.value.value! * scale);
            }).toList(),
        isCurved: true,
        color: colorScheme.secondary.withValues(alpha: 0.5),
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
        dashArray: [4, 4],
      ));
    }

    final sensorType = displayData.first.sensorType;
    bool isCategorical = ['activity_class', 'body_position', 'activity_intensity', 'sleep_detection'].contains(sensorType);
    final allValues = displayData.where((e) => e.value != null).map((e) => e.value!);
    double minY = allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    double maxY = allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b);
    double padding = (maxY - minY) * 0.15;
    if (padding == 0) padding = 1.0;
    minY = (minY - padding).clamp(0.0, double.infinity);
    maxY = maxY + padding;
    double yInterval = (maxY - minY) / 5;
    if (yInterval <= 0) yInterval = 1.0;

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    double minX = displayData.isNotEmpty ? displayData.first.time.toUtc().millisecondsSinceEpoch.toDouble() : 0.0;
    double maxX = displayData.isNotEmpty ? displayData.last.time.toUtc().millisecondsSinceEpoch.toDouble() : 0.0;
    
    if (provider.startHour != null && provider.sessionDate != null) {
      final startDT = DateTime.utc(provider.sessionDate!.year, provider.sessionDate!.month, provider.sessionDate!.day, provider.startHour!.hour, provider.startHour!.minute);
      minX = startDT.millisecondsSinceEpoch.toDouble();
    }
    
    if (provider.endHour != null && provider.sessionDate != null) {
      final endDT = DateTime.utc(provider.sessionDate!.year, provider.sessionDate!.month, provider.sessionDate!.day, provider.endHour!.hour, provider.endHour!.minute);
      maxX = endDT.millisecondsSinceEpoch.toDouble();
    }

    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 60000;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true, 
        horizontalInterval: yInterval, 
        verticalInterval: xInterval,
        getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
        getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.02), strokeWidth: 1),
        drawVerticalLine: true,
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: hasOverlay,
            interval: yInterval,
            reservedSize: 60,
            getTitlesWidget: (v, meta) {
              if (!hasOverlay) return const SizedBox();
              double realVal = v / scale;
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 12,
                child: Text(realVal >= 1000 ? '${(realVal/1000).toStringAsFixed(1)}k' : realVal.toStringAsFixed(1), 
                style: TextStyle(color: colorScheme.secondary.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.bold)),
              );
            }
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: xInterval,
            reservedSize: 30,
            getTitlesWidget: (v, meta) {
              if (v < minX || v > maxX) return const SizedBox();
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat('HH:mm').format(dt), style: const TextStyle(color: Colors.white38, fontSize: 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: isCategorical ? 65 : 60,
            getTitlesWidget: (v, meta) {
               if (isCategorical) {
                final intValue = v.round();
                if ((v - intValue).abs() > 0.1) return const SizedBox();
                String text = '';
                if (sensorType == 'activity_class') {
                  const labels = ['STILL', 'WALK', 'RUN', 'GENERIC'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                } else if (sensorType == 'body_position') {
                  const labels = ['SIT/LIE', 'STAND', 'LEFT', 'RIGHT', 'PRONE', 'SUPINE', 'MISC'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                } else if (sensorType == 'activity_intensity') {
                  const labels = ['SED', 'LPA', 'MPA', 'VPA'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                } else if (sensorType == 'sleep_detection') {
                  const labels = ['WAKE', 'REST', 'INTERRUPT', 'RESERVED'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                }
                return SideTitleWidget(axisSide: meta.axisSide, space: 10, child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 8)));
              }
              return SideTitleWidget(axisSide: meta.axisSide, space: 12, child: Text(v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)));
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => colorScheme.surface,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                spot.y.toStringAsFixed(2),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
