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
import '../widgets/analisis_exportacion_tab.dart';

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

class _CardiacoScreenState extends State<CardiacoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchCardiacoMetrics(widget.participantId, widget.username);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final byType = <String, List<Biomarker>>{};
        for (var m in provider.cardiacoMetrics) {
          final type = m.sensorType.toLowerCase().replaceAll('-', '_');
          byType.putIfAbsent(type, () => []).add(m);
        }

        final hrData = byType['pulse_rate'] ?? [];
        final rrData = byType['respiratory_rate'] ?? [];

        // Calcular promedios para el ecualizador
        final validHR = hrData.where((e) => e.value != null).map((e) => e.value!).toList();
        final validRR = rrData.where((e) => e.value != null).map((e) => e.value!).toList();
        final avgHR = validHR.isEmpty ? 0.0 : validHR.reduce((a, b) => a + b) / validHR.length;
        final avgRR = validRR.isEmpty ? 0.0 : validRR.reduce((a, b) => a + b) / validRR.length;

        Widget tab0;
        if (provider.isCardiacoLoading) {
          tab0 = const Center(child: CircularProgressIndicator(color: _accent));
        } else {
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
              _EcualizadorVitalLayer(avgHR: avgHR, avgRR: avgRR),
            ]
          ];
          tab0 = LayoutBuilder(
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
              return ListView(padding: EdgeInsets.all(padding), children: listSections);
            },
          );
        }

        return Column(
          children: [
            _ControlPanel(provider: provider, participantId: widget.participantId, username: widget.username),
            Container(
              color: AppColors.bgCard,
              child: TabBar(
                controller: _tabController,
                labelColor: _accent,
                unselectedLabelColor: _muted,
                indicatorColor: _accent,
                dividerColor: _border,
                tabs: const [
                  Tab(icon: Icon(LucideIcons.layoutDashboard, size: 16), text: 'Dashboard'),
                  Tab(icon: Icon(LucideIcons.barChart2, size: 16), text: 'Análisis y Exportación'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  tab0,
                  AnalisisExportacionTab(
                    participantId: widget.participantId,
                    username: widget.username,
                    metrics: provider.cardiacoMetrics,
                    availableSensors: kCardiacoSensores,
                    accentColor: _accent,
                    startTime: provider.cardiacoStart,
                    endTime: provider.cardiacoEnd,
                  ),
                ],
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
                    'Análisis del Pulso y la Respiración',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
                  ),
                  Text(
                    'Evaluación del ritmo cardíaco, frecuencia respiratoria y la relación de latidos por respiración.',
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
            title: 'Frecuencia Cardíaca (Pulso)',
            value: validHR.isEmpty ? '--' : '${avgHR.round()} BPM',
            subtitle: validHR.isEmpty ? 'Sin datos' : 'Mín: ${minHR.round()} BPM | Máx: ${maxHR.round()} BPM',
            tooltip: '[Sensor: "pulse_rate"]. Latidos por minuto (BPM). En reposo, el rango normal es de 60 a 100 BPM. Valores de esfuerzo o picos de taquicardia clínica superan los 100 BPM (zona roja en la gráfica).',
            icon: LucideIcons.activity,
            color: _hrColor,
          ),
          _KPICard(
            title: 'Frecuencia Respiratoria',
            value: validRR.isEmpty ? '--' : '${avgRR.round()} BrPM',
            subtitle: 'Ciclos respiratorios promedio',
            tooltip: '[Sensor: "respiratory_rate"]. Ciclos respiratorios por minuto (BrPM). En reposo, un adulto sano suele respirar entre 12 y 20 veces. Durante un ejercicio vigoroso, la tasa puede superar las 30 BrPM.',
            icon: LucideIcons.wind,
            color: _rrLine,
          ),
          _KPICard(
            title: 'Relación Latidos / Respiración',
            value: ratioCount == 0 ? '--' : avgRatio.toStringAsFixed(1),
            subtitle: 'Latidos por cada ciclo respiratorio',
            tooltip: '[Calculado de: "pulse_rate" / "respiratory_rate"]. Cociente entre pulso y respiración. El acoplamiento normal suele estar entre 4.0 y 5.0. Valores elevados indican desacoplamiento (arritmias o esfuerzo asimétrico).',
            icon: LucideIcons.infinity,
            color: _ratioColor,
          ),
          _KPICard(
            title: 'Tiempo de Uso',
            value: '${compliance.toStringAsFixed(1)}%',
            subtitle: 'Tiempo con registro de calidad',
            icon: LucideIcons.checkCircle2,
            color: AppColors.cyberBlue,
            tooltip: "[Sensor: \"wearing_detection\"]. Porcentaje de tiempo en el que la pulsera ha estado colocada correctamente registrando datos limpios y analizables.",
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
                        Text('Relación Temporal entre Pulso y Respiración', style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text)),
                      ],
                    ),
                    Tooltip(
                      message: '[Sensores: "pulse_rate" y "respiratory_rate"]. Compara el ritmo del corazón con la respiración. Un acoplamiento estable refleja un estado de calma y buen funcionamiento del cuerpo.',
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _tooltipBg, borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Comparativa visual del pulso y los ciclos de respiración a lo largo del tiempo.', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
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
            labelResolver: (_) => 'Zona de Taquicardia (>100 BPM)',
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
        DateTime.fromMillisecondsSinceEpoch(minX.toInt()),
        DateTime.fromMillisecondsSinceEpoch(maxX.toInt()));

    final List<VerticalLine> dayLines = [];
    if (axisSpansDays) {
      final startDt = DateTime.fromMillisecondsSinceEpoch(minX.toInt());
      DateTime midnight = DateTime(startDt.year, startDt.month, startDt.day).add(const Duration(days: 1));
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
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: _muted, fontSize: isMobile ? 8 : 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Text('Pulso (BPM)', style: GoogleFonts.inter(fontSize: 10, color: _hrColor, fontWeight: FontWeight.bold)),
          axisNameSize: 24,
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
          axisNameWidget: Text('Respiración (BrPM)', style: GoogleFonts.inter(fontSize: 10, color: _rrLine, fontWeight: FontWeight.bold)),
          axisNameSize: 24,
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
              final label = isRR ? 'Respiración (RR)' : 'Frecuencia Cardíaca (HR)';
              final unit = isRR ? ' BrPM' : ' BPM';
              final dt = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              final timeStr = DateFormat('HH:mm').format(dt);
              return LineTooltipItem(
                '$timeStr\n$label: ${val.toStringAsFixed(1)}$unit',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class _EcualizadorVitalLayer extends StatelessWidget {
  final double avgHR;
  final double avgRR;

  const _EcualizadorVitalLayer({
    required this.avgHR,
    required this.avgRR,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const double maxHR = 160.0;
    const double maxRR = 40.0;

    final double fillHR = (avgHR / maxHR).clamp(0.0, 1.0);
    final double fillRR = (avgRR / maxRR).clamp(0.0, 1.0);

    return Container(
      height: 410,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Balance Cardiorrespiratorio',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '[Sensores: "pulse_rate" y "respiratory_rate"]. Las barras muestran el esfuerzo promedio. En un estado saludable, el pulso y la respiración suben y bajan de forma simétrica. Un desnivel fuerte indica un sobreesfuerzo o desacoplamiento de uno de los de sistemas.',
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _tooltipBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                          child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comparativa de la carga de trabajo entre el corazón y los pulmones.',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 11 : 13,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBar(
                  label: 'Pulso',
                  value: avgHR,
                  unit: 'BPM',
                  fillPercentage: fillHR,
                  color: _hrColor,
                ),
                _buildBar(
                  label: 'Respiración',
                  value: avgRR,
                  unit: 'BrPM',
                  fillPercentage: fillRR,
                  color: _rrLine,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required double value,
    required String unit,
    required double fillPercentage,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: 60,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: fillPercentage),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
              builder: (context, val, child) {
                return FractionallySizedBox(
                  heightFactor: val,
                  widthFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _text,
          ),
        ),
      ],
    );
  }
}
