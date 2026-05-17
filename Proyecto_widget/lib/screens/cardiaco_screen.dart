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
const Color _accent  = AppColors.clinicalHeart; 
const Color _border  = AppColors.border;

const Color _hrColor    = AppColors.clinicalHeart; 
const Color _rrArea     = AppColors.clinicalBreath; 
const Color _rrLine     = Color(0xFF0891B2); 
const Color _ratioColor = AppColors.clinicalViolet; 
const Color _tooltipBg  = Color(0xFF0F172A); 

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
          final type = m.sensorType.toLowerCase().replaceAll('-', '_');
          byType.putIfAbsent(type, () => []).add(m);
        }

        final hrData = byType['pulse_rate'] ?? [];
        final rrData = byType['respiratory_rate'] ?? [];

        final listSections = [
          if (hrData.isEmpty && rrData.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text('Sin datos cardíacos en el tramo seleccionado', style: GoogleFonts.inter(color: _muted)),
              ),
            )
          else if (provider.cardiacoStart != null && provider.cardiacoEnd != null) ...[
            _KPIsLayer(hrData: hrData, rrData: rrData, provider: provider),
            const SizedBox(height: 24),
            _CouplingGraphLayer(hrData: hrData, rrData: rrData, startTime: provider.cardiacoStart!, endTime: provider.cardiacoEnd!),
            const SizedBox(height: 24),
            _ScatterPlotLayer(hrData: hrData, rrData: rrData),
          ]
        ];

        return Column(
          children: [
            _ControlPanel(provider: provider, participantId: widget.participantId, username: widget.username),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isLaptop = constraints.maxWidth > 1100;
                  final padding  = isMobile ? 12.0 : (constraints.maxWidth > 720 ? 24.0 : 16.0);

                  if (isLaptop && listSections.length >= 5) {
                    return ListView(
                      padding: EdgeInsets.all(padding),
                      children: [
                        listSections[0],
                        const SizedBox(height: 24),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: listSections[2]),
                              const SizedBox(width: 20),
                              Expanded(child: listSections[4]),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.all(padding),
                    children: listSections,
                  );
                },
              ),
            ),
          ],
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 12),
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
              final headerTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitorización Cardiopulmonar',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
                  ),
                  Text(
                    'Análisis continuo del acoplamiento entre la demanda ventilatoria y la respuesta cardíaca.',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
              );
              final resolutionBadge = provider.cardiacoResolucion.isEmpty
                  ? const SizedBox()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _hrColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _hrColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.gauge, size: 11, color: _hrColor),
                          const SizedBox(width: 6),
                          Text(
                            provider.cardiacoResolucion,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: _hrColor),
                          ),
                        ],
                      ),
                    );

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        headerIcon,
                        const SizedBox(width: 12),
                        Expanded(child: headerTitle),
                      ],
                    ),
                    const SizedBox(height: 12),
                    resolutionBadge,
                  ],
                );
              }

              return Row(
                children: [
                  headerIcon,
                  const SizedBox(width: 12),
                  Expanded(child: headerTitle),
                  const SizedBox(width: 12),
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

    final dataSpansDays = provider.dataRangeStart != null
        && provider.dataRangeEnd != null
        && !DateUtils.isSameDay(provider.dataRangeStart!, provider.dataRangeEnd!);

    DateTime pickedDate = initialDate;
    if (dataSpansDays) {
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: provider.dataRangeStart!,
        lastDate: provider.dataRangeEnd!,
        builder: (context, child) => Localizations.override(
          context: context,
          locale: const Locale('es'),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _accent,
                onPrimary: Colors.white,
                onSurface: _text,
              ),
            ),
            child: child!,
          ),
        ),
      );
      if (date == null || !context.mounted) return;
      pickedDate = date;
    }

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
        pickedDate.year, pickedDate.month, pickedDate.day,
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

    final dataSpansDays = provider.dataRangeStart != null
        && provider.dataRangeEnd != null
        && !DateUtils.isSameDay(provider.dataRangeStart!, provider.dataRangeEnd!);
    final startStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.cardiacoStart!)}\n${DateFormat('HH:mm').format(provider.cardiacoStart!)}'
        : DateFormat('HH:mm').format(provider.cardiacoStart!);
    final endStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.cardiacoEnd!)}\n${DateFormat('HH:mm').format(provider.cardiacoEnd!)}'
        : DateFormat('HH:mm').format(provider.cardiacoEnd!);
    final spansDays = !DateUtils.isSameDay(provider.cardiacoStart!, provider.cardiacoEnd!);
    final dateStr = spansDays
        ? '${DateFormat('dd MMM').format(provider.cardiacoStart!)} → ${DateFormat('dd MMM').format(provider.cardiacoEnd!)}'
        : DateFormat('dd MMM yyyy').format(provider.cardiacoStart!);

    final isMobile = MediaQuery.of(context).size.width < 600;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: isMobile ? 8 : 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarDays, size: 13, color: _muted),
            const SizedBox(width: 6),
            Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: _text, fontWeight: FontWeight.w600)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock, size: 13, color: _muted),
            const SizedBox(width: 6),
            if (!isMobile)
              Text('Tramo:', style: GoogleFonts.inter(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
            if (!isMobile) const SizedBox(width: 8),
            _TimeButton(time: startStr, onTap: () => _pickTime(context, true)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('-', style: TextStyle(color: _muted))),
            _TimeButton(time: endStr, onTap: () => _pickTime(context, false)),
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
          textAlign: TextAlign.center,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _hrColor,
          ),
        ),
      ),
    );
  }
}

class _KPIsLayer extends StatelessWidget {
  final List<Biomarker> hrData;
  final List<Biomarker> rrData;
  final DashboardProvider provider;

  const _KPIsLayer({required this.hrData, required this.rrData, required this.provider});

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

    final compliance = provider.compliancePercentage ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final kpis = [
          _KPICard(
            title: 'Frecuencia Cardíaca (HR)',
            value: validHR.isEmpty ? '--' : '${avgHR.round()} BPM',
            subtitle: validHR.isEmpty ? 'Sin datos' : 'Min: ${minHR.round()}  |  Max: ${maxHR.round()}',
            tooltip: 'Ritmo cardíaco promedio en el tramo. Valores sostenidos por encima de 100 BPM en reposo activan alertas de taquicardia.',
            icon: LucideIcons.activity,
            color: _hrColor,
          ),
          _KPICard(
            title: 'Frecuencia Ventilatoria (RR)',
            value: validRR.isEmpty ? '--' : '${avgRR.round()} BrPM',
            subtitle: 'Media del tramo',
            tooltip: 'Tasa respiratoria media. Un adulto sano en reposo oscila entre 12 y 20 BrPM. Alteraciones pueden indicar estrés metabólico o respiratorio.',
            icon: LucideIcons.wind,
            color: _rrLine,
          ),
          _KPICard(
            title: 'Índice de Acoplamiento',
            value: ratioCount == 0 ? '--' : avgRatio.toStringAsFixed(1),
            subtitle: 'Latidos por respiración',
            tooltip: 'Proporción de latidos por cada ciclo respiratorio. Una desviación drástica de la media normal (aprox. 4.0) indica un desacoplamiento fisiológico.',
            icon: LucideIcons.infinity,
            color: _ratioColor,
          ),
          _KPICard(
            title: 'Tasa de Uso',
            value: '${compliance.toStringAsFixed(1)}%',
            subtitle: 'Compliance del sensor',
            icon: LucideIcons.checkCircle2,
            color: AppColors.cyberBlue,
            tooltip: "Porcentaje de tiempo en el que el dispositivo ha estado correctamente colocado y registrando datos de calidad suficiente para el análisis clínico.",
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              Row(children: [Expanded(child: kpis[0]), const SizedBox(width: 12), Expanded(child: kpis[1])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: kpis[2]), const SizedBox(width: 12), Expanded(child: kpis[3])]),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: kpis[0]), const SizedBox(width: 16),
            Expanded(child: kpis[1]), const SizedBox(width: 16),
            Expanded(child: kpis[2]), const SizedBox(width: 16),
            Expanded(child: kpis[3]),
          ],
        );
      },
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String? tooltip;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.tooltip,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                ),
                child: Icon(icon, size: isMobile ? 16 : 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(title, style: GoogleFonts.inter(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold, color: _muted)),
                        if (tooltip != null) ...[
                          Tooltip(
                            message: tooltip!,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: _text.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                            ),
                            textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11, height: 1.4),
                            child: Icon(LucideIcons.info, size: 12, color: _muted.withValues(alpha: 0.5)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: _text, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: _muted), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _CouplingGraphLayer extends StatelessWidget {
  final List<Biomarker> hrData;
  final List<Biomarker> rrData;
  final DateTime startTime;
  final DateTime endTime;

  const _CouplingGraphLayer({required this.hrData, required this.rrData, required this.startTime, required this.endTime});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.activity, size: 20, color: _text),
                        const SizedBox(width: 12),
                        Text('Dinámica de Acoplamiento Temporal', style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text)),
                      ],
                    ),
                    Tooltip(
                      message: "Evaluación de la sincronía entre el pulso y la respiración. Una base rítmica estable indica un buen estado autonómico.",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _tooltipBg, borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Superposición de la variabilidad del pulso sobre la base de frecuencia respiratoria.', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
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
                  : LineChart(_buildChartData(context)),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // RR (12–20 BrPM) × 4 → ~48–80, alineado con HR (60–100 BPM) en el mismo eje
    const double rrScale = 4.0;

    final List<LineChartBarData> bars = [];

    final extraLines = ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: 100,
          color: _hrColor.withValues(alpha: 0.3),
          strokeWidth: 1.5,
          dashArray: [5, 5],
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

    final double fallbackMinX = startTime.toUtc().millisecondsSinceEpoch.toDouble();
    final double fallbackMaxX = endTime.toUtc().millisecondsSinceEpoch.toDouble();
    double minX = fallbackMinX;
    double maxX = fallbackMaxX;
    final allT = [...hrData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble()), ...rrData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble())];
    if (allT.isNotEmpty) {
      minX = allT.reduce(math.min);
      maxX = allT.reduce(math.max);
    }
    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000;
    final bool axisSpansDays = !DateUtils.isSameDay(
        DateTime.fromMillisecondsSinceEpoch(minX.toInt(), isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(maxX.toInt(), isUtc: true));

    final List<VerticalLine> dayLines = [];
    if (axisSpansDays) {
      final startDt = DateTime.fromMillisecondsSinceEpoch(minX.toInt(), isUtc: true);
      DateTime midnight = DateTime.utc(startDt.year, startDt.month, startDt.day).add(const Duration(days: 1));
      while (midnight.millisecondsSinceEpoch.toDouble() <= maxX) {
        final dayLabel = DateFormat('dd MMM').format(midnight);
        dayLines.add(VerticalLine(
          x: midnight.millisecondsSinceEpoch.toDouble(),
          color: _muted.withValues(alpha: 0.25),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            style: GoogleFonts.inter(color: _muted, fontSize: 9),
            labelResolver: (_) => dayLabel,
          ),
        ));
        midnight = midnight.add(const Duration(days: 1));
      }
    }

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: 160,
      lineBarsData: bars,
      extraLinesData: ExtraLinesData(
        horizontalLines: extraLines.horizontalLines,
        verticalLines: dayLines,
      ),
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
            reservedSize: 28,
            getTitlesWidget: (v, meta) {
              if (v < minX + (xInterval * 0.5) || v > maxX - (xInterval * 0.25)) return const SizedBox();
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: _muted, fontSize: isMobile ? 8 : 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Text('HR', style: GoogleFonts.inter(fontSize: 10, color: _hrColor, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: isMobile ? 25 : 35,
            interval: 40,
            getTitlesWidget: (v, meta) {
              return Text(v.toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _hrColor, fontSize: 9, fontWeight: FontWeight.bold));
            }
          )
        ),
        rightTitles: AxisTitles(
          axisNameWidget: Text('RR', style: GoogleFonts.inter(fontSize: 10, color: _rrLine, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: isMobile ? 25 : 35,
            interval: 40,
            getTitlesWidget: (v, meta) {
              return Text((v / rrScale).toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _rrLine, fontSize: 9, fontWeight: FontWeight.bold));
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _tooltipBg,
          tooltipBorder: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final isRR = spot.bar.color == _rrLine;
              final val = isRR ? spot.y / rrScale : spot.y;
              final label = isRR ? 'RR' : 'HR';
              return LineTooltipItem(
                '$label: ${val.toStringAsFixed(1)}',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class _ScatterPlotLayer extends StatelessWidget {
  final List<Biomarker> hrData;
  final List<Biomarker> rrData;

  const _ScatterPlotLayer({required this.hrData, required this.rrData});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
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
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.scatterChart, size: 20, color: _ratioColor),
                        const SizedBox(width: 12),
                        Text('Matriz de Dispersión Cardiorrespiratoria', style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text)),
                      ],
                    ),
                    Tooltip(
                      message: "Análisis bivariado. Una dispersión lineal ascendente sugiere un sistema cardiorrespiratorio sano y reactivo. Nubes de puntos erráticas señalan falta de sincronización autonómica.",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _tooltipBg, borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Correlación entre tasa respiratoria (X) y frecuencia cardíaca (Y).', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 300,
              child: spots.isEmpty
                  ? Center(child: Text('Datos insuficientes para el análisis de dispersión', style: GoogleFonts.inter(color: _muted)))
                  : ScatterChart(_buildScatterData(context, spots)),
            ),
          ),
        ],
      ),
    );
  }

  ScatterChartData _buildScatterData(BuildContext context, List<ScatterSpot> spots) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final minRR = spots.map((s) => s.x).reduce(math.min);
    final maxRR = spots.map((s) => s.x).reduce(math.max);
    final minHR = spots.map((s) => s.y).reduce(math.min);
    final maxHR = spots.map((s) => s.y).reduce(math.max);
    final xPad = ((maxRR - minRR) < 1 ? 1.0 : (maxRR - minRR)) * 0.15;
    final yPad = ((maxHR - minHR) < 1 ? 1.0 : (maxHR - minHR)) * 0.15;

    return ScatterChartData(
      scatterSpots: spots,
      minX: (minRR - xPad).clamp(0.0, double.infinity),
      maxX: maxRR + xPad,
      minY: (minHR - yPad).clamp(0.0, double.infinity),
      maxY: maxHR + yPad,
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
          axisNameWidget: Text('Pulso', style: GoogleFonts.inter(fontSize: 10, color: _hrColor, fontWeight: FontWeight.bold)),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            reservedSize: isMobile ? 25 : 35,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _muted, fontSize: 9)),
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: _border)),
      scatterTouchData: ScatterTouchData(
        enabled: true,
        touchTooltipData: ScatterTouchTooltipData(
          getTooltipColor: (_) => _tooltipBg,
          getTooltipItems: (touchedSpot) => ScatterTooltipItem(
            'HR: ${touchedSpot.y.toInt()}\nRR: ${touchedSpot.x.toInt()}',
            textStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            bottomMargin: 8,
          ),
        ),
      ),
    );
  }
}
