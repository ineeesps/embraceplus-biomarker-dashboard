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

const Color _bg          = AppColors.bgScreen;
const Color _surface     = AppColors.bgCard;
const Color _text        = AppColors.textPrimary;
const Color _muted       = AppColors.textSecondary;
const Color _border      = AppColors.border;

const Color _accentIndigo = Color(0xFF4F46E5);
const Color _accentAmber  = Color(0xFFF59E0B);
const Color _accentTeal   = Color(0xFF14B8A6);
const Color _accentRed    = Color(0xFFEF4444);
const Color _tooltipBg    = Color(0xFF0F172A);

const Color _deepSleep    = Color(0xFF312E81);
const Color _lightSleep   = Color(0xFF818CF8);

const Color _posSupine    = Color(0xFF4F46E5);
const Color _posLateral   = Color(0xFFC7D2FE);
const Color _posProne     = Color(0xFF14B8A6);
const Color _posSitting   = Color(0xFF64748B);
const Color _posStanding  = Color(0xFFEA580C);
const Color _posMisc      = Color(0xFFE2E8F0);

class SuenoScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const SuenoScreen({super.key, required this.participantId, required this.username});

  @override
  State<SuenoScreen> createState() => _SuenoScreenState();
}

class _SuenoScreenState extends State<SuenoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchSuenoMetrics(widget.participantId, widget.username);
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
        for (var m in provider.suenoMetrics) {
          final type = m.sensorType.toLowerCase().replaceAll('-', '_');
          byType.putIfAbsent(type, () => []).add(m);
        }

        final sleepDetData = byType['sleep_detection'] ?? [];
        final posData      = byType['body_position'] ?? [];
        final activity     = byType['activity_class'] ?? [];

        bool hasGoodHygiene = false;
        if (sleepDetData.isNotEmpty) {
          final sleepMins = sleepDetData.where((e) => e.value != null && e.value! > 0).length;
          if ((sleepMins / sleepDetData.length) * 100 > 85) hasGoodHygiene = true;
        }

        Widget tab0;
        if (provider.isSuenoLoading) {
          tab0 = const Center(child: CircularProgressIndicator(color: _accentIndigo));
        } else {
          final listSections = [
            if (sleepDetData.isEmpty && posData.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Center(
                  child: Text('Sin datos fisiológicos en el tramo seleccionado', style: GoogleFonts.inter(color: _muted)),
                ),
              )
            else ...[
              _KPIsLayer(sleepData: sleepDetData, posData: posData, provider: provider),
              const SizedBox(height: 24),
              _HipnogramaLayer(sleepData: sleepDetData, activity: activity),
              const SizedBox(height: 24),
              _GanttPosturalLayer(posData: posData, sleepData: sleepDetData),
            ]
          ];
          tab0 = LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final padding  = isMobile ? 12.0 : (constraints.maxWidth > 720 ? 24.0 : 16.0);
              return ListView(padding: EdgeInsets.all(padding), children: listSections);
            },
          );
        }

        return Column(
          children: [
            _ControlPanel(
              provider: provider,
              participantId: widget.participantId,
              username: widget.username,
              hasGoodHygiene: hasGoodHygiene,
            ),
            Container(
              color: AppColors.bgCard,
              child: TabBar(
                controller: _tabController,
                labelColor: _accentIndigo,
                unselectedLabelColor: _muted,
                indicatorColor: _accentIndigo,
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
                    metrics: provider.suenoMetrics,
                    availableSensors: kSuenoSensores,
                    accentColor: _accentIndigo,
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
  final bool hasGoodHygiene;

  const _ControlPanel({
    required this.provider, 
    required this.participantId, 
    required this.username,
    required this.hasGoodHygiene,
  });

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
                  color: _accentIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.moon, size: 16, color: _accentIndigo),
              );
              final headerTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Análisis de Arquitectura del Sueño y Ergonomía',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
                  ),
                  Text(
                    'Evaluación de ciclos de descanso, fragmentación nocturna y carga postural.',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
              );
              
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (hasGoodHygiene ? const Color(0xFF10B981) : _accentAmber).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (hasGoodHygiene ? const Color(0xFF10B981) : _accentAmber).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(hasGoodHygiene ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle, size: 11, color: hasGoodHygiene ? const Color(0xFF10B981) : _accentAmber),
                    const SizedBox(width: 6),
                    Text(
                      hasGoodHygiene ? 'Higiene Circadiana Óptima' : 'Fragmentación Detectada',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: hasGoodHygiene ? const Color(0xFF10B981) : _accentAmber),
                    ),
                  ],
                ),
              );

              final resolutionBadge = provider.suenoResolucion.isEmpty
                  ? const SizedBox()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentIndigo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accentIndigo.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.gauge, size: 11, color: _accentIndigo),
                          const SizedBox(width: 6),
                          Text(
                            provider.suenoResolucion,
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: _accentIndigo),
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
                    Wrap(spacing: 8, runSpacing: 8, children: [badge, resolutionBadge]),
                  ],
                );
              }

              return Row(
                children: [
                  headerIcon,
                  const SizedBox(width: 12),
                  Expanded(child: headerTitle),
                  const SizedBox(width: 12),
                  badge,
                  const SizedBox(width: 8),
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
    final initialDate = isStart ? provider.suenoStart : provider.suenoEnd;
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
                primary: _accentIndigo,
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
              primary: _accentIndigo,
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

      DateTime start = provider.suenoStart!;
      DateTime end = provider.suenoEnd!;

      if (isStart) {
        start = newDate;
        if (start.isAfter(end)) end = start.add(const Duration(hours: 1));
      } else {
        end = newDate;
        if (end.isBefore(start)) start = end.subtract(const Duration(hours: 1));
      }

      provider.setSuenoRango(start, end, participantId, username);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (provider.suenoStart == null || provider.suenoEnd == null) return const SizedBox();

    final dataSpansDays = provider.dataRangeStart != null
        && provider.dataRangeEnd != null
        && !DateUtils.isSameDay(provider.dataRangeStart!, provider.dataRangeEnd!);
    final startStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.suenoStart!)}\n${DateFormat('HH:mm').format(provider.suenoStart!)}'
        : DateFormat('HH:mm').format(provider.suenoStart!);
    final endStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.suenoEnd!)}\n${DateFormat('HH:mm').format(provider.suenoEnd!)}'
        : DateFormat('HH:mm').format(provider.suenoEnd!);
    final spansDays = !DateUtils.isSameDay(provider.suenoStart!, provider.suenoEnd!);
    final dateStr = spansDays
        ? '${DateFormat('dd MMM').format(provider.suenoStart!)} → ${DateFormat('dd MMM').format(provider.suenoEnd!)}'
        : DateFormat('dd MMM yyyy').format(provider.suenoStart!);

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
            color: _accentIndigo,
          ),
        ),
      ),
    );
  }
}

class _KPIsLayer extends StatelessWidget {
  final List<Biomarker> sleepData;
  final List<Biomarker> posData;
  final DashboardProvider provider;

  const _KPIsLayer({required this.sleepData, required this.posData, required this.provider});

  @override
  Widget build(BuildContext context) {
    final int totalPoints = sleepData.length;
    final int asleepPoints = sleepData.where((d) => d.value != null && d.value! > 0).length;

    final double efficiency = totalPoints > 0 ? (asleepPoints / totalPoints) * 100 : 0.0;

    final int minsPorPunto = provider.suenoMinutosPorPunto;
    final int tstMinutes = asleepPoints * minsPorPunto;
    final int tstHours   = tstMinutes ~/ 60;
    final int tstRemMins = tstMinutes % 60;

    int wasoPoints = 0;
    bool sleepOnsetReached = false;
    for (var d in sleepData) {
      if (!sleepOnsetReached && d.value != null && d.value! > 0) {
        sleepOnsetReached = true;
        continue;
      }
      if (sleepOnsetReached && d.value != null && d.value! == 0) {
        wasoPoints++;
      }
    }
    final int wasoMinutes = wasoPoints * minsPorPunto;

    int postureChanges = 0;
    double? lastPos;
    for (var d in posData) {
      if (d.value != null) {
        if (lastPos != null && d.value != lastPos) postureChanges++;
        lastPos = d.value;
      }
    }
    final double durationHours = provider.selectedSuenoHours.toDouble();
    final double rotationIndex = durationHours > 0 ? postureChanges / durationHours : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 800;
        final kpis = [
          _KPICard(
            title: 'Eficiencia del Sueño',
            value: asleepPoints == 0 ? '--' : '${efficiency.toStringAsFixed(1)}%',
            subtitle: asleepPoints == 0 ? 'Sin sueño detectado' : 'Higiene Circadiana',
            icon: LucideIcons.activitySquare,
            color: _accentIndigo,
            tooltip: "Porcentaje de tiempo efectivo de sueño en relación al tiempo total en cama.",
          ),
          _KPICard(
            title: 'Tiempo Total (TST)',
            value: asleepPoints == 0 ? '--' : '${tstHours}h ${tstRemMins}m',
            subtitle: asleepPoints == 0 ? 'Ajuste el rango horario' : 'Arquitectura Real',
            icon: LucideIcons.clock,
            color: _lightSleep,
            tooltip: "Suma neta de minutos detectados en fases de sueño (Ligero/Profundo).",
          ),
          _KPICard(
            title: 'Índice WASO',
            value: !sleepOnsetReached ? '--' : '$wasoMinutes min',
            subtitle: 'Despertares Pos-Onset',
            icon: LucideIcons.bellRing,
            color: _accentAmber,
            tooltip: "Wake After Sleep Onset. Minutos que el paciente pasó despierto después de haber conciliado el sueño inicialmente.",
          ),
          _KPICard(
            title: 'Índice de Rotación',
            value: posData.isEmpty ? '--' : '${rotationIndex.toStringAsFixed(1)}/h',
            subtitle: 'Estabilidad Mecánica',
            icon: LucideIcons.user,
            color: _accentTeal,
            tooltip: "Número de cambios de postura significativos normalizados por hora de registro.",
          ),
        ];

        if (isSmall) {
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

class _HipnogramaLayer extends StatelessWidget {
  final List<Biomarker> sleepData;
  final List<Biomarker> activity;

  const _HipnogramaLayer({required this.sleepData, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LayerHeader(
            title: 'Hipnograma de Fases de Descanso',
            subtitle: 'Distribución temporal de la profundidad del sueño y microdespertares motores.',
            icon: LucideIcons.activity,
            iconColor: _accentIndigo,
            tooltip: "El eje vertical invertido representa la inmersión en el sueño. Los ciclos saludables (aprox. 90 min) muestran un descenso progresivo. Las marcas rojas inferiores indican alta variabilidad acelerométrica (espasmos/arousals) sin vigilia consciente.",
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: SizedBox(
              height: 250,
              child: (() {
                final asleepPoints = sleepData.where((d) => d.value != null && d.value! > 0).length;
                if (asleepPoints == 0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.moonStar, size: 32, color: _muted.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text(
                          'Sin fases de sueño detectadas en este tramo.',
                          style: GoogleFonts.inter(color: _muted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajuste el rango temporal para incluir las horas nocturnas.',
                          style: GoogleFonts.inter(color: _muted.withValues(alpha: 0.7), fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return LineChart(_buildChartData(context));
              })(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _SleepArchitectureLegend(),
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context) {
    final List<FlSpot> spots = [];
    for (var d in sleepData) {
      if (d.value == null) continue;
      double yVal;
      if (d.value! == 0)      { yVal = 3; }
      else if (d.value! == 1) { yVal = 2; }
      else                    { yVal = 1; }
      spots.add(FlSpot(d.time.toUtc().millisecondsSinceEpoch.toDouble(), yVal));
    }

    final List<VerticalLine> redMarkers = [];
    for (var act in activity) {
      if (act.value != null && act.value! > 0) {
        final t = act.time.toUtc().millisecondsSinceEpoch.toDouble();
        final correspondingSleep = sleepData.where((s) => (s.time.toUtc().millisecondsSinceEpoch.toDouble() - t).abs() < 60000).firstOrNull;
        if (correspondingSleep != null && correspondingSleep.value != null && correspondingSleep.value! > 0) {
          redMarkers.add(VerticalLine(x: t, color: _accentRed.withValues(alpha: 0.6), strokeWidth: 2));
        }
      }
    }

    double minX = 0, maxX = 0;
    if (spots.isNotEmpty) {
      minX = spots.map((s) => s.x).reduce(math.min);
      maxX = spots.map((s) => s.x).reduce(math.max);
    }
    double xInterval = (maxX - minX) / 5;
    if (xInterval <= 0) xInterval = 3600000;
    final bool axisSpansDays = spots.isNotEmpty && !DateUtils.isSameDay(
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
      minX: minX, maxX: maxX, minY: 0.5, maxY: 3.5,
      extraLinesData: ExtraLinesData(verticalLines: [...redMarkers, ...dayLines]),
      lineBarsData: [
        LineChartBarData(
          spots: spots, isCurved: false, isStepLineChart: true, color: _accentIndigo, barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [_deepSleep.withValues(alpha: 0.3), _lightSleep.withValues(alpha: 0.1)],
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
            ),
          ),
        ),
      ],
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, interval: xInterval, reservedSize: 28,
            getTitlesWidget: (v, meta) {
              if (v < minX + (xInterval * 0.5) || v > maxX - (xInterval * 0.25)) return const SizedBox();
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
              return Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.jetBrainsMono(color: _muted, fontSize: 9));
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, interval: 1, reservedSize: 70,
            getTitlesWidget: (v, meta) {
              if (v == 3) return _AxisLabel('DESPIERTO', _accentAmber);
              if (v == 2) return _AxisLabel('LIGERO', _lightSleep);
              if (v == 1) return _AxisLabel('PROFUNDO', _deepSleep);
              return const SizedBox();
            },
          ),
        ),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: _border.withValues(alpha: 0.3))),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF0F172A),
          getTooltipItems: (pts) => pts.map((s) {
            String label = s.y <= 1.5 ? 'PROFUNDO' : (s.y <= 2.5 ? 'LIGERO' : 'DESPIERTO');
            return LineTooltipItem(label, GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11));
          }).toList(),
        ),
      ),
    );
  }
}

class _GanttPosturalLayer extends StatelessWidget {
  final List<Biomarker> posData;
  final List<Biomarker> sleepData;

  const _GanttPosturalLayer({required this.posData, required this.sleepData});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LayerHeader(
            title: 'Dinámica de Carga Postural',
            subtitle: 'Mantenimiento de decúbito y transiciones ergonómicas.',
            icon: LucideIcons.user,
            iconColor: _accentTeal,
            tooltip: "Permite correlacionar la fragmentación del sueño (picos en el hipnograma) con las posiciones físicas. Un alto índice de rotación puede indicar incomodidad articular o problemas respiratorios posicionales.",
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: posData.isEmpty 
                    ? Center(child: Text('Sin datos de postura', style: GoogleFonts.inter(color: _muted)))
                    : CustomPaint(painter: _PosturalGanttPainter(data: posData, sleepData: sleepData)),
                ),
                const SizedBox(height: 24),
                _PosturalSummary(data: posData),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String tooltip;

  const _LayerHeader({required this.title, required this.subtitle, required this.icon, required this.iconColor, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
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
                  Icon(icon, size: 20, color: _text),
                  const SizedBox(width: 12),
                  Text(title, style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _text)),
                ],
              ),
              Tooltip(
                message: tooltip,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _tooltipBg, borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }
}

class _PosturalSummary extends StatelessWidget {
  final List<Biomarker> data;
  const _PosturalSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    
    final counts = <int, int>{};
    for (var d in data) {
      if (d.value != null) {
        final v = d.value!.toInt();
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return Text('Sin datos de postura en el tramo', style: GoogleFonts.inter(color: _muted, fontSize: 12));
    }
    final total = data.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ESTADOS POSTURALES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: counts.entries.map((e) {
            String label; Color color;
            switch (e.key) {
              case 0: label = 'Sentado/Tumbado'; color = _posSitting; break;
              case 1: label = 'De pie';        color = _posStanding; break;
              case 2: label = 'Lado izq.';     color = _posLateral; break;
              case 3: label = 'Lado der.';     color = _posLateral; break;
              case 4: label = 'Boca abajo';    color = _posProne; break;
              case 5: label = 'Boca arriba';   color = _posSupine; break;
              default: label = 'Transición';   color = _posMisc;
            }
            final pct = (e.value / total * 100).toStringAsFixed(0);
            return _LegendItem('$label ($pct%)', color);
          }).toList(),
        ),
      ],
    );
  }
}


class _AxisLabel extends StatelessWidget {
  final String text; final Color color;
  const _AxisLabel(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 8, fontWeight: FontWeight.w900), textAlign: TextAlign.right),
    );
  }
}

class _SleepArchitectureLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ARQUITECTURA DEL SUEÑO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _LegendItem('Vigilia', _accentAmber),
            _LegendItem('Ligero', _lightSleep),
            _LegendItem('Profundo', _deepSleep),
            _LegendItem('Arousals Motores', _accentRed),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: _muted,
          ),
        ),
      ],
    );
  }
}

class _PosturalGanttPainter extends CustomPainter {
  final List<Biomarker> data;
  final List<Biomarker> sleepData;
  _PosturalGanttPainter({required this.data, required this.sleepData});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final minX = data.first.time.toUtc().millisecondsSinceEpoch.toDouble();
    final maxX = data.last.time.toUtc().millisecondsSinceEpoch.toDouble();
    final range = maxX - minX;
    if (range <= 0) return;

    for (int i = 0; i < data.length; i++) {
      final val = data[i].value?.toInt();
      Color color;
      switch (val) {
        case 0: color = _posSitting; break;
        case 1: color = _posStanding; break;
        case 2: color = _posLateral; break;
        case 3: color = _posLateral; break;
        case 4: color = _posProne; break;
        case 5: color = _posSupine; break;
        default: color = _posMisc;
      }
      paint.color = color;
      final x = (data[i].time.toUtc().millisecondsSinceEpoch.toDouble() - minX) / range * size.width;
      final nextX = (i < data.length - 1) 
        ? (data[i+1].time.toUtc().millisecondsSinceEpoch.toDouble() - minX) / range * size.width 
        : size.width;
      if (nextX >= x) canvas.drawRRect(RRect.fromLTRBR(x, 0, nextX, size.height, const Radius.circular(2)), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
