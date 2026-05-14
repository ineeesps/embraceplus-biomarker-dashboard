import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../providers/dashboard_provider.dart';
import '../models/biomarker.dart';
import '../utils/app_colors.dart';

const Color _bg      = AppColors.bgScreen;
const Color _surface = AppColors.bgCard;
const Color _text    = AppColors.textPrimary;
const Color _muted   = AppColors.textSecondary;
const Color _accent  = AppColors.cyberBlue;
const Color _border  = AppColors.border;

class CardiacoScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const CardiacoScreen({super.key, required this.participantId, required this.username});

  @override
  State<CardiacoScreen> createState() => _CardiacoScreenState();
}

class _CardiacoScreenState extends State<CardiacoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<DashboardProvider>();
      if (p.cardiacoStart == null && p.dataRangeStart != null) {
        p.setHourFilter(p.selectedHours, widget.participantId, widget.username);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isCardiacoLoading) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }

        final byType = <String, List<Biomarker>>{};
        for (var m in provider.cardiacoMetrics) {
          byType.putIfAbsent(m.sensorType, () => []).add(m);
        }

        final sections = [
          _ControlPanel(provider: provider, participantId: widget.participantId, username: widget.username),
          if (byType.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text('Sin datos cardíacos en el tramo seleccionado', style: GoogleFonts.inter(color: _muted)),
              ),
            )
          else ...[
            const SizedBox(height: 24),
            _buildSensorCard('pulse_rate', byType['pulse_rate'] ?? []),
            _buildSensorCard('respiratory_rate', byType['respiratory_rate'] ?? []),
            _buildSensorCard('prv', byType['prv'] ?? []),
          ]
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 600 ? 16 : 32,
                vertical: constraints.maxWidth < 600 ? 20 : 40,
              ),
              children: sections,
            );
          },
        );
      },
    );
  }

  Widget _buildSensorCard(String type, List<Biomarker> data) {
    if (data.isEmpty) return const SizedBox();
    return _CardiacCard(sensorType: type, data: data);
  }
}

class _ControlPanel extends StatelessWidget {
  final DashboardProvider provider;
  final String participantId;
  final String username;
  const _ControlPanel({required this.provider, required this.participantId, required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final isSmall = c.maxWidth < 450;
              final headerIcon = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sensorHeart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.heartPulse, size: 16, color: AppColors.sensorHeart),
              );
              final headerTitle = Text(
                'Cardíaco y Respiratorio',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
              );
              final resolutionBadge = provider.cardiacoResolucion.isEmpty
                  ? const SizedBox()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.gauge, size: 11, color: _accent),
                          const SizedBox(width: 6),
                          Text(
                            provider.cardiacoResolucion,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: _accent),
                          ),
                        ],
                      ),
                    );

              if (isSmall) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [headerIcon, const SizedBox(width: 12), headerTitle],
                    ),
                    resolutionBadge,
                  ],
                );
              }

              return Row(
                children: [
                  headerIcon,
                  const SizedBox(width: 12),
                  headerTitle,
                  const Spacer(),
                  resolutionBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _TimeRangeSelector(provider: provider, participantId: participantId, username: username),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  final DashboardProvider provider;
  final String participantId;
  final String username;
  const _TimeRangeSelector({required this.provider, required this.participantId, required this.username});

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final initialDate = isStart ? provider.cardiacoStart : provider.cardiacoEnd;
    if (initialDate == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accent,
              onPrimary: Colors.white,
              onSurface: _text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && context.mounted) {
      final newDate = DateTime(
        initialDate.year, initialDate.month, initialDate.day,
        time.hour, time.minute,
      );

      DateTime start = provider.cardiacoStart!;
      DateTime end = provider.cardiacoEnd!;

      if (isStart) {
        start = newDate;
        if (start.isAfter(end)) end = start.add(const Duration(hours: 1));
      } else {
        end = newDate;
        if (end.isBefore(start)) start = end.subtract(const Duration(hours: 1));
      }

      provider.setCardiacoRango(start, end, participantId, username);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (provider.cardiacoStart == null || provider.cardiacoEnd == null) return const SizedBox();

    final startStr = DateFormat('HH:mm').format(provider.cardiacoStart!);
    final endStr = DateFormat('HH:mm').format(provider.cardiacoEnd!);
    final dateStr = DateFormat('dd MMM yyyy').format(provider.cardiacoStart!);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarDays, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: _text, fontWeight: FontWeight.w600)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock, size: 14, color: _muted),
            const SizedBox(width: 8),
            Text('Tramo horario:', style: GoogleFonts.inter(fontSize: 13, color: _muted, fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            _TimeButton(
              time: startStr,
              onTap: () => _pickTime(context, true),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-', style: TextStyle(color: _muted)),
            ),
            _TimeButton(
              time: endStr,
              onTap: () => _pickTime(context, false),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;
  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _accent,
          ),
        ),
      ),
    );
  }
}

class _CardiacCard extends StatelessWidget {
  final String sensorType;
  final List<Biomarker> data;

  const _CardiacCard({required this.sensorType, required this.data});

  Color _getSensorColor() {
    switch (sensorType) {
      case 'pulse_rate': return AppColors.sensorHeart;
      case 'prv': return AppColors.sensorPRV;
      case 'respiratory_rate': return AppColors.sensorBreath;
      default: return AppColors.cyberBlue;
    }
  }

  String _getTitle() {
    switch (sensorType) {
      case 'pulse_rate': return 'Frecuencia Cardíaca';
      case 'prv': return 'Variabilidad Cardíaca (PRV)';
      case 'respiratory_rate': return 'Tasa Respiratoria';
      default: return sensorType;
    }
  }

  String _getSubtitle() {
    switch (sensorType) {
      case 'pulse_rate': return 'lpm · Señal fotopletismográfica';
      case 'prv': return 'ms · Intervalo R-R';
      case 'respiratory_rate': return 'rpm · Estimación acelerométrica';
      default: return '';
    }
  }

  IconData _getIcon() {
    switch (sensorType) {
      case 'pulse_rate': return LucideIcons.heartPulse;
      case 'prv': return LucideIcons.activity;
      case 'respiratory_rate': return LucideIcons.wind;
      default: return LucideIcons.barChart2;
    }
  }

  Widget _buildStatusTag(String flag) {
    Color color = const Color(0xFF34D399); 
    String label = 'NORMAL';
    if (flag == 'worn_during_motion') { color = const Color(0xFFFBBF24); label = 'MOVIMIENTO'; }
    else if (flag == 'worn_with_low_signal_quality' || flag == 'low_signal_quality') { color = const Color(0xFFFB7185); label = 'SEÑAL BAJA'; }
    else if (flag == 'device_not_recording') { color = _muted; label = 'GAP'; }
    else if (flag == 'device_not_worn_correctly') { color = _muted; label = 'NO PUESTO'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildStatsTable(BuildContext context, Color sensorColor) {
    final validValues = data.where((e) => e.value != null).map((e) => e.value!).toList();
    if (validValues.isEmpty) return const SizedBox();

    double mean = validValues.reduce((a, b) => a + b) / validValues.length;
    double min = validValues.reduce((a, b) => a < b ? a : b);
    double max = validValues.reduce((a, b) => a > b ? a : b);
    double variance = validValues.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / validValues.length;
    double sd = math.sqrt(variance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'MEDIA', value: mean.toStringAsFixed(2), color: sensorColor),
          _StatItem(label: 'SD', value: sd.toStringAsFixed(2), color: _muted),
          _StatItem(label: 'MIN', value: min.toStringAsFixed(2), color: _muted),
          _StatItem(label: 'MAX', value: max.toStringAsFixed(2), color: _muted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sensorColor = _getSensorColor();
    final hasData = data.any((b) => b.value != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sensorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getIcon(), size: 22, color: sensorColor),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(),
                        style: GoogleFonts.outfit(color: _text, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getSubtitle(),
                        style: GoogleFonts.inter(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (data.isNotEmpty) _buildStatusTag(data.first.qualityFlag),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasData) _buildStatsTable(context, sensorColor),
                if (hasData) const SizedBox(height: 24),
                if (hasData)
                  SizedBox(
                    height: 250,
                    child: LineChart(_buildChartData()),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'Sin valores representables (gaps de calidad)',
                        style: GoogleFonts.inter(color: _muted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData() {
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

    final sensorColor = _getSensorColor();

    bars.addAll(segments.asMap().entries.map((entry) {
      final spots = entry.value;
      final quality = segmentQualities[entry.key];
      Color color = sensorColor;
      bool isProblematic = false;
      if (quality == 'worn_during_motion') { color = const Color(0xFFF59E0B); isProblematic = true; }
      else if (quality == 'worn_with_low_signal_quality' || quality == 'low_signal_quality') { color = const Color(0xFFEF4444); isProblematic = true; }
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
            colors: [color.withValues(alpha: isProblematic ? 0.2 : 0.1), color.withValues(alpha: 0.0)],
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
          color: const Color(0xFF94A3B8).withValues(alpha: 0.4),
          barWidth: 1.5,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ));
      }
    }

    final allValues = displayData.where((e) => e.value != null).map((e) => e.value!);
    double minY = allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    double maxY = allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b);
    double padding = (maxY - minY) * 0.15;
    if (padding == 0) padding = 1.0;
    minY = (minY - padding).clamp(0.0, double.infinity);
    maxY = maxY + padding;
    double yInterval = (maxY - minY) / 5;
    if (yInterval <= 0) yInterval = 1.0;

    double minX = displayData.isNotEmpty ? displayData.first.time.toUtc().millisecondsSinceEpoch.toDouble() : 0.0;
    double maxX = displayData.isNotEmpty ? displayData.last.time.toUtc().millisecondsSinceEpoch.toDouble() : 0.0;
    
    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000; 

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
        getDrawingHorizontalLine: (v) => FlLine(color: _border, strokeWidth: 1),
        getDrawingVerticalLine: (v) => FlLine(color: _border.withValues(alpha: 0.6), strokeWidth: 1),
        drawVerticalLine: true,
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: xInterval,
            reservedSize: 30,
            getTitlesWidget: (v, meta) {
              if (v < minX || v > maxX) return const SizedBox();
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
              final format = (maxX - minX) > 86400000 ? 'dd/MM HH:mm' : 'HH:mm';
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat(format).format(dt), style: GoogleFonts.inter(color: _muted, fontSize: 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: 45,
            getTitlesWidget: (v, meta) {
              return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: Text(v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0), style: GoogleFonts.inter(color: _muted, fontSize: 10, fontWeight: FontWeight.bold)));
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          tooltipBorder: const BorderSide(color: _border),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                spot.y.toStringAsFixed(2),
                GoogleFonts.inter(color: _text, fontWeight: FontWeight.bold),
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
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? _accent;
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: _muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
