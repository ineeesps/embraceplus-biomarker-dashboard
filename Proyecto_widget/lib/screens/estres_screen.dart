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
const Color _border  = AppColors.border;

const Color _edaColor  = Color(0xFF10B981);
const Color _prvColor  = Color(0xFF8B5CF6);
const Color _metsColor = Color(0xFF64748B);
const Color _tempColor = Color(0xFFF59E0B);
const Color _tooltipBg = Color(0xFF0F172A);

class EstresScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const EstresScreen({super.key, required this.participantId, required this.username});

  @override
  State<EstresScreen> createState() => _EstresScreenState();
}

class _EstresScreenState extends State<EstresScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchEstresMetrics(widget.participantId, widget.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isEstresLoading) {
          return const Center(child: CircularProgressIndicator(color: _edaColor));
        }

        final byType = <String, List<Biomarker>>{};
        for (var m in provider.estresMetrics) {
          final type = m.sensorType.toLowerCase().replaceAll('-', '_');
          byType.putIfAbsent(type, () => []).add(m);
        }

        final edaData  = byType['eda'] ?? [];
        final prvData  = byType['prv'] ?? [];
        final metsData = byType['met'] ?? [];
        final tempData = byType['temperature'] ?? [];

        final listSections = [
          if (edaData.isEmpty && prvData.isEmpty && tempData.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Text('Sin datos fisiológicos en el tramo seleccionado', style: GoogleFonts.inter(color: _muted)),
              ),
            )
          else ...[
            _KPIsLayer(edaData: edaData, prvData: prvData, metsData: metsData, tempData: tempData),
            const SizedBox(height: 24),
            _ReactividadGraphLayer(edaData: edaData, prvData: prvData, startTime: provider.estresStart!, endTime: provider.estresEnd!),
            const SizedBox(height: 24),
            _ContextoGraphLayer(metsData: metsData, tempData: tempData, startTime: provider.estresStart!, endTime: provider.estresEnd!),
          ]
        ];

        return Column(
          children: [
            _ControlPanel(provider: provider, participantId: widget.participantId, username: widget.username),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final padding  = isMobile ? 12.0 : (constraints.maxWidth > 720 ? 24.0 : 16.0);

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
                  color: _edaColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.brainCircuit, size: 16, color: _edaColor),
              );
              final headerTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance y Reactividad Autonómica',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
                  ),
                  Text(
                    'Evaluación de la respuesta simpática (EDA), recuperación parasimpática (HRV) y eficiencia termorreguladora.',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
              );
              final resolutionBadge = provider.estresResolucion.isEmpty
                  ? const SizedBox()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _edaColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _edaColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.gauge, size: 11, color: _edaColor),
                          const SizedBox(width: 6),
                          Text(
                            provider.estresResolucion,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: _edaColor),
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
    final initialDate = isStart ? provider.estresStart : provider.estresEnd;
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
                primary: _edaColor,
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
              primary: _edaColor,
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

      DateTime start = provider.estresStart!;
      DateTime end = provider.estresEnd!;

      if (isStart) {
        start = newDate;
        if (start.isAfter(end)) end = start.add(const Duration(hours: 1));
      } else {
        end = newDate;
        if (end.isBefore(start)) start = end.subtract(const Duration(hours: 1));
      }

      provider.setEstresRango(start, end, participantId, username);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (provider.estresStart == null || provider.estresEnd == null) return const SizedBox();

    final dataSpansDays = provider.dataRangeStart != null
        && provider.dataRangeEnd != null
        && !DateUtils.isSameDay(provider.dataRangeStart!, provider.dataRangeEnd!);
    final startStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.estresStart!)}\n${DateFormat('HH:mm').format(provider.estresStart!)}'
        : DateFormat('HH:mm').format(provider.estresStart!);
    final endStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.estresEnd!)}\n${DateFormat('HH:mm').format(provider.estresEnd!)}'
        : DateFormat('HH:mm').format(provider.estresEnd!);
    final spansDays = !DateUtils.isSameDay(provider.estresStart!, provider.estresEnd!);
    final dateStr = spansDays
        ? '${DateFormat('dd MMM').format(provider.estresStart!)} → ${DateFormat('dd MMM').format(provider.estresEnd!)}'
        : DateFormat('dd MMM yyyy').format(provider.estresStart!);

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
            color: _edaColor,
          ),
        ),
      ),
    );
  }
}

class _KPIsLayer extends StatelessWidget {
  final List<Biomarker> edaData;
  final List<Biomarker> prvData;
  final List<Biomarker> metsData;
  final List<Biomarker> tempData;

  const _KPIsLayer({required this.edaData, required this.prvData, required this.metsData, required this.tempData});

  @override
  Widget build(BuildContext context) {
    final validEda = edaData.where((e) => e.value != null).map((e) => e.value!).toList();
    final validPrv = prvData.where((e) => e.value != null).map((e) => e.value!).toList();
    final validMets = metsData.where((e) => e.value != null).map((e) => e.value!).toList();
    final validTemp = tempData.where((e) => e.value != null).map((e) => e.value!).toList();

    double avgEda = 0;
    if (validEda.isNotEmpty) avgEda = validEda.reduce((a, b) => a + b) / validEda.length;

    double avgPrv = 0;
    if (validPrv.isNotEmpty) avgPrv = validPrv.reduce((a, b) => a + b) / validPrv.length;

    double sumMets = 0;
    if (validMets.isNotEmpty) sumMets = validMets.reduce((a, b) => a + b);

    double avgTemp = 0, minTemp = 0, maxTemp = 0;
    if (validTemp.isNotEmpty) {
      avgTemp = validTemp.reduce((a, b) => a + b) / validTemp.length;
      minTemp = validTemp.reduce(math.min);
      maxTemp = validTemp.reduce(math.max);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
        
        final kpis = [
          _KPICard(
            title: 'Nivel de Estrés (EDA)',
            value: validEda.isEmpty ? '--' : '${avgEda.toStringAsFixed(2)} µS',
            subtitle: 'Media de conductancia',
            icon: LucideIcons.zap,
            color: _edaColor,
            tooltip: "Mide la conductancia eléctrica de la piel en microsiemens (μS). Los aumentos rápidos o picos (SCR) son indicadores directos de la activación del sistema nervioso simpático ante estímulos estresantes, emocionales o de alerta cognitiva.",
          ),
          _KPICard(
            title: 'Capacidad de Recuperación',
            value: validPrv.isEmpty ? '--' : '${avgPrv.toStringAsFixed(0)} ms',
            subtitle: 'Valor RMSSD (PRV)',
            icon: LucideIcons.heartHandshake,
            color: _prvColor,
            tooltip: "Variabilidad de la frecuencia cardíaca calculada mediante la métrica RMSSD (milisegundos). Es el marcador principal del tono vagal; una PRV alta indica una buena capacidad de recuperación y equilibrio del sistema nervioso parasimpático.",
          ),
          _KPICard(
            title: 'Gasto Metabólico',
            value: validMets.isEmpty ? '--' : '${sumMets.toStringAsFixed(1)} METs',
            subtitle: 'Valor acumulado',
            icon: LucideIcons.flame,
            color: _metsColor,
            tooltip: "Equivalente Metabólico de Tarea. Representa la razón entre la tasa metabólica durante una actividad y la tasa metabólica en reposo (1.0 MET). Es esencial para discernir si la activación fisiológica es debida a esfuerzo físico o estrés psicológico.",
          ),
          _KPICard(
            title: 'Estabilidad Térmica',
            value: validTemp.isEmpty ? '--' : '${avgTemp.toStringAsFixed(1)} °C',
            subtitle: validTemp.isEmpty ? 'Sin datos' : 'Rango: ${minTemp.toStringAsFixed(1)} - ${maxTemp.toStringAsFixed(1)}',
            icon: LucideIcons.thermometer,
            color: _tempColor,
            tooltip: "Temperatura monitorizada continuamente en la muñeca (ºC). En contextos de estrés agudo, es común observar descensos leves debido a la vasoconstricción periférica, mientras que una temperatura estable sugiere un estado homeostático.",
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
        } else if (isTablet) {
          return Column(
            children: [
              Row(children: [Expanded(child: kpis[0]), const SizedBox(width: 16), Expanded(child: kpis[1])]),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: kpis[2]), const SizedBox(width: 16), Expanded(child: kpis[3])]),
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
  final IconData icon;
  final Color color;
  final String tooltip;

  const _KPICard({
    required this.title, 
    required this.value, 
    required this.subtitle, 
    required this.icon, 
    required this.color,
    required this.tooltip,
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
                        Tooltip(
                          message: tooltip,
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

class _ReactividadGraphLayer extends StatelessWidget {
  final List<Biomarker> edaData;
  final List<Biomarker> prvData;
  final DateTime startTime;
  final DateTime endTime;

  const _ReactividadGraphLayer({required this.edaData, required this.prvData, required this.startTime, required this.endTime});

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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _edaColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.activity, size: 16, color: _edaColor),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Análisis de Respuesta al Estrés',
                          style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text),
                        ),
                      ],
                    ),
                    Tooltip(
                      message: "Permite identificar eventos de activación del sistema nervioso simpático. Una caída de la PRV coincidente con un aumento de la EDA es un biomarcador robusto de estrés psicológico.",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _text.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Correlación entre picos de conductancia galvánica y variabilidad vagal.', 
                        style: GoogleFonts.inter(color: _muted, fontSize: 12)),
                      const SizedBox(height: 12),
                      _GraphLegend(items: [
                        _LegendItem(label: 'EDA', color: _edaColor),
                        _LegendItem(label: 'PRV', color: _prvColor, isDashed: true),
                      ]),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Correlación entre picos de conductancia galvánica y variabilidad vagal.', 
                          style: GoogleFonts.inter(color: _muted, fontSize: 13)),
                      ),
                      const SizedBox(width: 16),
                      _GraphLegend(items: [
                        _LegendItem(label: 'EDA', color: _edaColor),
                        _LegendItem(label: 'PRV', color: _prvColor, isDashed: true),
                      ]),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 300,
              child: edaData.isEmpty && prvData.isEmpty
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
    final edaMax = edaData.where((e) => e.value != null).fold(0.0, (acc, e) => math.max(acc, e.value!));
    final prvMax = prvData.where((e) => e.value != null).fold(0.0, (acc, e) => math.max(acc, e.value!));
    final double prvScale = (prvMax > 0 && edaMax > 0) ? edaMax / prvMax : 0.1;

    final List<LineChartBarData> bars = [];

    if (edaData.isNotEmpty) {
      final valid = edaData.where((e) => e.value != null).map((e) => e.value!);
      if (valid.isNotEmpty) {
        List<FlSpot> spots = [];
        for (var d in edaData) {
          if (d.value != null) spots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), d.value!));
        }
        if (spots.isNotEmpty) {
          bars.add(LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _edaColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _edaColor.withValues(alpha: 0.1),
            ),
          ));
        }
      }
    }

    if (prvData.isNotEmpty) {
      final valid = prvData.where((e) => e.value != null).map((e) => (e.value! * prvScale));
      if (valid.isNotEmpty) {
        List<FlSpot> spots = [];
        for (var d in prvData) {
          if (d.value != null) spots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), d.value! * prvScale));
        }
        if (spots.isNotEmpty) {
          bars.add(LineChartBarData(
            spots: spots,
            isCurved: false,
            isStepLineChart: true,
            color: _prvColor,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
          ));
        }
      }
    }

    final double fallbackMinX = startTime.toUtc().millisecondsSinceEpoch.toDouble();
    final double fallbackMaxX = endTime.toUtc().millisecondsSinceEpoch.toDouble();
    double minX = fallbackMinX, maxX = fallbackMaxX;
    double maxVal = 5;

    final allT = [...edaData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble()), ...prvData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble())];
    if (allT.isNotEmpty) {
      minX = allT.reduce(math.min);
      maxX = allT.reduce(math.max);
    }
    final bool axisSpansDays = !DateUtils.isSameDay(
        DateTime.fromMillisecondsSinceEpoch(minX.toInt(), isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(maxX.toInt(), isUtc: true));

    final allV = [
      ...edaData.where((e) => e.value != null).map((e) => e.value!),
      ...prvData.where((e) => e.value != null).map((e) => e.value! * prvScale),
    ];
    if (allV.isNotEmpty) {
      maxVal = allV.reduce(math.max) * 1.15;
    }
    if (maxVal < 1) maxVal = 1;

    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000;
    double yInterval = maxVal / 5;

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
      maxY: maxVal,
      lineBarsData: bars,
      extraLinesData: ExtraLinesData(verticalLines: dayLines),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        getDrawingHorizontalLine: (v) => FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1),
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
                space: 8,
                child: Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: _muted, fontSize: isMobile ? 8 : 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: isMobile ? 32 : 44,
            getTitlesWidget: (v, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(v.toStringAsFixed(1), style: GoogleFonts.jetBrainsMono(color: _edaColor, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold)),
            ),
          )
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: isMobile ? 32 : 44,
            getTitlesWidget: (v, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text((v / prvScale).toInt().toString(), style: GoogleFonts.jetBrainsMono(color: _prvColor, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold)),
            ),
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _tooltipBg,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final isPRV = spot.bar.color == _prvColor;
              final val = isPRV ? spot.y / prvScale : spot.y;
              final label = isPRV ? 'PRV' : 'EDA';
              return LineTooltipItem('$label: ${val.toStringAsFixed(1)}', GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11));
            }).toList();
          },
        ),
      ),
    );
  }
}

class _ContextoGraphLayer extends StatelessWidget {
  final List<Biomarker> metsData;
  final List<Biomarker> tempData;
  final DateTime startTime;
  final DateTime endTime;

  const _ContextoGraphLayer({required this.metsData, required this.tempData, required this.startTime, required this.endTime});

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
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _tempColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.thermometer, size: 16, color: _tempColor),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Demanda Metabólica y Termorregulación',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                      ],
                    ),
                    Tooltip(
                      message: "Utilice esta vista para descartar falsos positivos de estrés. Si los METs son bajos, los cambios en la EDA y temperatura se atribuyen a estados emocionales o cognitivos.",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _tooltipBg, borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                      child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Validación de la carga física frente a la respuesta térmica cutánea.', 
                        style: GoogleFonts.inter(color: _muted, fontSize: 12)),
                      const SizedBox(height: 12),
                      _GraphLegend(items: [
                        _LegendItem(label: 'METs', color: _metsColor),
                        _LegendItem(label: 'Temp', color: _tempColor),
                      ]),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Validación de la carga física frente a la respuesta térmica cutánea.', 
                          style: GoogleFonts.inter(color: _muted, fontSize: 13)),
                      ),
                      const SizedBox(width: 16),
                      _GraphLegend(items: [
                        _LegendItem(label: 'METs', color: _metsColor),
                        _LegendItem(label: 'Temp', color: _tempColor),
                      ]),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 300,
              child: metsData.isEmpty && tempData.isEmpty
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
    final metsMax = metsData.where((e) => e.value != null).fold(0.0, (acc, e) => math.max(acc, e.value!));
    final tempValidValues = tempData.where((e) => e.value != null).map((e) => e.value!).toList();
    final tempMid = tempValidValues.isNotEmpty
        ? tempValidValues.reduce((a, b) => a + b) / tempValidValues.length
        : 35.0;
    final double metScale = metsMax > 0 ? tempMid / metsMax : 5.0;

    final List<LineChartBarData> bars = [];

    if (metsData.isNotEmpty) {
      List<FlSpot> spots = [];
      for (var d in metsData) {
        if (d.value != null) spots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), d.value! * metScale));
      }
      if (spots.isNotEmpty) {
        bars.add(LineChartBarData(
          spots: spots,
          isCurved: false,
          isStepLineChart: true,
          color: _metsColor,
          barWidth: 1,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _metsColor.withValues(alpha: 0.2),
          ),
        ));
      }
    }

    if (tempData.isNotEmpty) {
      List<FlSpot> spots = [];
      for (var d in tempData) {
        if (d.value != null) spots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), d.value!));
      }
      if (spots.isNotEmpty) {
        bars.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: _tempColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ));
      }
    }

    final double fallbackMinX = startTime.toUtc().millisecondsSinceEpoch.toDouble();
    final double fallbackMaxX = endTime.toUtc().millisecondsSinceEpoch.toDouble();
    double minX = fallbackMinX, maxX = fallbackMaxX;
    double minVal = 25, maxVal = 40;

    final allT = [...metsData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble()), ...tempData.map((e) => e.time.toUtc().millisecondsSinceEpoch.toDouble())];
    if (allT.isNotEmpty) {
      minX = allT.reduce(math.min);
      maxX = allT.reduce(math.max);
    }
    final bool axisSpansDays = !DateUtils.isSameDay(
        DateTime.fromMillisecondsSinceEpoch(minX.toInt(), isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(maxX.toInt(), isUtc: true));

    final allV = [
      ...metsData.where((e) => e.value != null).map((e) => e.value! * metScale),
      ...tempData.where((e) => e.value != null).map((e) => e.value!),
    ];
    if (allV.isNotEmpty) {
      final vMin = allV.reduce(math.min);
      final vMax = allV.reduce(math.max);
      minVal = (vMin - 1).clamp(0, 50);
      maxVal = vMax + 1;
    }

    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000;
    double yInterval = (maxVal - minVal) / 5;

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
      minY: minVal,
      maxY: maxVal,
      lineBarsData: bars,
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 30,
            color: Colors.grey.withValues(alpha: 0.4),
            strokeWidth: 0,
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: isMobile ? 8 : 10, fontWeight: FontWeight.bold),
              labelResolver: (_) => 'Posible pérdida de contacto térmico (<30ºC)',
            ),
          ),
        ],
        verticalLines: dayLines,
        extraLinesOnTop: false,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        getDrawingHorizontalLine: (v) {
          if (v < 30 && v >= minVal) {
            return FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 10); 
          }
          return FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1);
        },
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
                space: 8,
                child: Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: _muted, fontSize: isMobile ? 8 : 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: isMobile ? 32 : 44,
            getTitlesWidget: (v, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text((v / metScale).toStringAsFixed(1), style: GoogleFonts.jetBrainsMono(color: _metsColor, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold)),
            ),
          )
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: isMobile ? 32 : 44,
            getTitlesWidget: (v, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(v.toStringAsFixed(1), style: GoogleFonts.jetBrainsMono(color: _tempColor, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold)),
            ),
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
              final isMet = spot.bar.color == _metsColor ||
                  (spot.barIndex == 0 && metsData.any((e) => e.value != null));
              final val    = isMet ? spot.y / metScale : spot.y;
              final label  = isMet ? 'METs' : 'Temp';
              final unit   = isMet ? '' : ' °C';
              final dt     = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt(), isUtc: true);
              final time   = DateFormat('HH:mm').format(dt);
              return LineTooltipItem(
                '$label: ${val.toStringAsFixed(1)}$unit',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                children: [
                  TextSpan(
                    text: '\n$time',
                    style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.6), fontSize: 9),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class _GraphLegend extends StatelessWidget {
  final List<_LegendItem> items;
  const _GraphLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _muted,
            ),
          ),
        ],
      )).toList(),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  final bool isDashed;
  _LegendItem({required this.label, required this.color, this.isDashed = false});
}
