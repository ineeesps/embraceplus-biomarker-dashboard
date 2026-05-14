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

const Color _hrColor    = Color(0xFFE11D48); 
const Color _hrZone     = Color(0xFFFFE4E6); 
const Color _rrArea     = Color(0xFF06B6D4); 
const Color _rrLine     = Color(0xFF0891B2); 
const Color _ratioColor = Color(0xFF8B5CF6); 

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
      context.read<DashboardProvider>().fetchCardiacoMetrics(widget.participantId, widget.username);
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

        final hrData = byType['pulse_rate'] ?? [];
        final rrData = byType['respiratory_rate'] ?? [];

        final sections = [
          _ControlPanel(provider: provider, participantId: widget.participantId, username: widget.username),
          if (hrData.isEmpty && rrData.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text('Sin datos cardíacos en el tramo seleccionado', style: GoogleFonts.inter(color: _muted)),
              ),
            )
          else ...[
            const SizedBox(height: 24),
            _KPIsLayer(hrData: hrData, rrData: rrData),
            const SizedBox(height: 24),
            _CouplingGraphLayer(hrData: hrData, rrData: rrData),
            const SizedBox(height: 24),
            _ScatterPlotLayer(hrData: hrData, rrData: rrData),
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

// ---------------------------------------------------------
// LAYER 1: KPIs
// ---------------------------------------------------------
class _KPIsLayer extends StatelessWidget {
  final List<Biomarker> hrData;
  final List<Biomarker> rrData;

  const _KPIsLayer({required this.hrData, required this.rrData});

  @override
  Widget build(BuildContext context) {
    final validHR = hrData.where((e) => e.value != null).map((e) => e.value!).toList();
    final validRR = rrData.where((e) => e.value != null).map((e) => e.value!).toList();

    double avgHR = 0, minHR = 0, maxHR = 0;
    if (validHR.isNotEmpty) {
      avgHR = validHR.reduce((a, b) => a + b) / validHR.length;
      minHR = validHR.reduce((a, b) => a < b ? a : b);
      maxHR = validHR.reduce((a, b) => a > b ? a : b);
    }

    double avgRR = 0;
    if (validRR.isNotEmpty) {
      avgRR = validRR.reduce((a, b) => a + b) / validRR.length;
    }

    double avgRatio = 0;
    int ratioCount = 0;
    final rrMap = {for (var e in rrData) if (e.value != null) e.time.millisecondsSinceEpoch: e.value!};
    for (var hr in hrData) {
      if (hr.value != null) {
        final rrVal = rrMap[hr.time.millisecondsSinceEpoch];
        if (rrVal != null && rrVal > 0) {
          avgRatio += (hr.value! / rrVal);
          ratioCount++;
        }
      }
    }
    if (ratioCount > 0) avgRatio /= ratioCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 700;
        final children = [
          Expanded(
            flex: isSmall ? 0 : 1,
            child: _KPICard(
              title: 'Frecuencia Cardíaca',
              value: validHR.isEmpty ? '--' : '${avgHR.round()} BPM',
              subtitle: validHR.isEmpty ? 'Sin datos' : 'Min: ${minHR.round()}  |  Max: ${maxHR.round()}',
              icon: LucideIcons.activity,
              color: _hrColor,
            ),
          ),
          if (!isSmall) const SizedBox(width: 16),
          Expanded(
            flex: isSmall ? 0 : 1,
            child: _KPICard(
              title: 'Tasa Respiratoria',
              value: validRR.isEmpty ? '--' : '${avgRR.round()} BrPM',
              subtitle: 'Media del tramo',
              icon: LucideIcons.wind,
              color: _rrLine,
            ),
          ),
          if (!isSmall) const SizedBox(width: 16),
          Expanded(
            flex: isSmall ? 0 : 1,
            child: _KPICard(
              title: 'Ratio Cardiorrespiratorio',
              value: ratioCount == 0 ? '--' : avgRatio.toStringAsFixed(1),
              subtitle: 'Latidos por respiración',
              icon: LucideIcons.infinity,
              color: _ratioColor,
            ),
          ),
        ];

        if (isSmall) {
          return Column(
            children: [
              children[0],
              const SizedBox(height: 16),
              children[2],
              const SizedBox(height: 16),
              children[4],
            ],
          );
        }
        return Row(children: children);
      },
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _muted)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// LAYER 2: Coupling Graph
// ---------------------------------------------------------
class _CouplingGraphLayer extends StatelessWidget {
  final List<Biomarker> hrData;
  final List<Biomarker> rrData;

  const _CouplingGraphLayer({required this.hrData, required this.rrData});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(LucideIcons.activity, size: 20, color: _text),
                const SizedBox(width: 12),
                Text('Acoplamiento Cardiorrespiratorio', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 300,
              child: hrData.isEmpty && rrData.isEmpty
                  ? Center(child: Text('Sin datos para graficar', style: GoogleFonts.inter(color: _muted)))
                  : LineChart(_buildChartData()),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData() {
    // Escalar RR para que conviva visualmente con HR
    // HR suele estar entre 50 y 150. RR suele estar entre 10 y 30.
    // Factor de escala ideal: x4
    const double rrScale = 4.0; 

    final List<LineChartBarData> bars = [];

    // Tachycardia Zone (Background)
    final extraLines = ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: 100,
          color: _hrZone.withValues(alpha: 0.8),
          strokeWidth: 0,
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            style: GoogleFonts.inter(color: _hrColor, fontSize: 10, fontWeight: FontWeight.bold),
            labelResolver: (_) => 'TAQUICARDIA (>100)',
          ),
        ),
      ],
    );

    // RR Area
    if (rrData.isNotEmpty) {
      List<FlSpot> rrSpots = [];
      for (var d in rrData) {
        if (d.value != null) {
          rrSpots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), d.value! * rrScale));
        }
      }
      if (rrSpots.isNotEmpty) {
        bars.add(LineChartBarData(
          spots: rrSpots,
          isCurved: true,
          color: _rrLine,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _rrArea.withValues(alpha: 0.15),
          ),
        ));
      }
    }

    // HR Line
    if (hrData.isNotEmpty) {
      List<FlSpot> hrSpots = [];
      for (var d in hrData) {
        if (d.value != null) {
          hrSpots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), d.value!));
        }
      }
      if (hrSpots.isNotEmpty) {
        bars.add(LineChartBarData(
          spots: hrSpots,
          isCurved: true,
          color: _hrColor,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
        ));
      }
    }

    // Calcular ejes X
    double minX = 0;
    double maxX = 0;
    final allT = [...hrData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble()), ...rrData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble())];
    if (allT.isNotEmpty) {
      minX = allT.reduce(math.min);
      maxX = allT.reduce(math.max);
    }
    double xInterval = (maxX - minX) / 6;
    if (xInterval <= 0) xInterval = 3600000;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: 160, // Fijo para asegurar proporción clínica
      lineBarsData: bars,
      extraLinesData: extraLines,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (v) => FlLine(color: _border.withValues(alpha: 0.5), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          axisNameWidget: Text('HR (BPM)', style: GoogleFonts.inter(fontSize: 10, color: _hrColor, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            interval: 40,
            getTitlesWidget: (v, meta) {
              return Text(v.toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _hrColor, fontSize: 10, fontWeight: FontWeight.bold));
            }
          )
        ),
        rightTitles: AxisTitles(
          axisNameWidget: Text('RR (BrPM)', style: GoogleFonts.inter(fontSize: 10, color: _rrLine, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            interval: 40, // 40 / rrScale = 10 BrPM
            getTitlesWidget: (v, meta) {
              return Text((v / rrScale).toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _rrLine, fontSize: 10, fontWeight: FontWeight.bold));
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          tooltipBorder: const BorderSide(color: _border),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final isRR = spot.bar.color == _rrLine;
              final val = isRR ? spot.y / rrScale : spot.y;
              final label = isRR ? 'RR' : 'HR';
              final color = isRR ? _rrLine : _hrColor;
              return LineTooltipItem(
                '$label: ${val.toStringAsFixed(1)}',
                GoogleFonts.inter(color: color, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// LAYER 3: Scatter Plot
// ---------------------------------------------------------
class _ScatterPlotLayer extends StatelessWidget {
  final List<Biomarker> hrData;
  final List<Biomarker> rrData;

  const _ScatterPlotLayer({required this.hrData, required this.rrData});

  @override
  Widget build(BuildContext context) {
    final rrMap = {for (var e in rrData) if (e.value != null) e.time.millisecondsSinceEpoch: e.value!};
    List<ScatterSpot> spots = [];
    
    for (var hr in hrData) {
      if (hr.value != null) {
        final rrVal = rrMap[hr.time.millisecondsSinceEpoch];
        if (rrVal != null && rrVal > 0) {
          spots.add(ScatterSpot(
            rrVal, 
            hr.value!, 
            dotPainter: FlDotCirclePainter(
              color: _ratioColor.withValues(alpha: 0.5),
              radius: 5,
              strokeWidth: 0,
            ),
          ));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.scatterChart, size: 20, color: _ratioColor),
                    const SizedBox(width: 12),
                    Text('Matriz de Dispersión Cardiorrespiratoria', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Correlación entre tasa respiratoria (X) y frecuencia cardíaca (Y).', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 250,
              child: spots.isEmpty
                  ? Center(child: Text('Datos insuficientes para el análisis de dispersión', style: GoogleFonts.inter(color: _muted)))
                  : ScatterChart(_buildScatterData(spots)),
            ),
          ),
        ],
      ),
    );
  }

  ScatterChartData _buildScatterData(List<ScatterSpot> spots) {
    return ScatterChartData(
      scatterSpots: spots,
      minX: 5,
      maxX: 40,
      minY: 40,
      maxY: 180,
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (v) => FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1),
        getDrawingVerticalLine: (v) => FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          axisNameWidget: Text('Respiración (BrPM)', style: GoogleFonts.inter(fontSize: 10, color: _rrLine, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            reservedSize: 24,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _muted, fontSize: 10)),
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Text('Pulso (BPM)', style: GoogleFonts.inter(fontSize: 10, color: _hrColor, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            reservedSize: 35,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _muted, fontSize: 10)),
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: _border)),
      scatterTouchData: ScatterTouchData(
        enabled: true,
        touchTooltipData: ScatterTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          getTooltipItems: (touchedSpot) => ScatterTooltipItem(
            'HR: ${touchedSpot.y.toInt()}\nRR: ${touchedSpot.x.toInt()}',
            textStyle: GoogleFonts.jetBrainsMono(color: _ratioColor, fontWeight: FontWeight.bold),
            bottomMargin: 8,
          ),
        ),
      ),
    );
  }
}
