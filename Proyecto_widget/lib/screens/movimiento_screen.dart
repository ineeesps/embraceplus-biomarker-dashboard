import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/biomarker.dart';
import '../providers/dashboard_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/analisis_exportacion_tab.dart';

const Color _bg      = AppColors.bgScreen;
const Color _surface = AppColors.bgCard;
const Color _border  = AppColors.border;
const Color _text    = AppColors.textPrimary;
const Color _muted   = AppColors.textSecondary;
const Color _identidad = AppColors.clinicalMove;
const Color _pizarra   = AppColors.clinicalSlate;

// ── Activity class colours (activity_class values 0–3) ─────────────────────
const Color _clsGap     = AppColors.statusGap;
const Color _clsStill   = Color(0xFFCBD5E1); // 0 — sedentary / still
const Color _clsWalk    = Color(0xFF64748B); // 1 — walking
const Color _clsRun     = Color(0xFF1E293B); // 2 — running
const Color _clsGeneric = Color(0xFF94A3B8); // 3 — generic activity

// ── Activity intensity colours (activity_intensity values 0–3) ────────────
const Color _intGap = AppColors.statusGap;
const Color _intSed = Color(0xFFF8FAFC); // 0 — sedentary
const Color _intLPA = Color(0xFFFEF3C7); // 1 — light physical activity
const Color _intMPA = Color(0xFFFB923C); // 2 — moderate physical activity
const Color _intVPA = AppColors.clinicalMove; // 3 — vigorous physical activity

const Color _kMagnitude = AppColors.clinicalMove;
const Color _kStability = AppColors.clinicalTeal;

const Color _targetColor = Color(0xFFCBD5E1);

const Color _axisX = Color(0xFFFDBA74);
const Color _axisY = Color(0xFF5EEAD4);
const Color _axisZ = Color(0xFFCBD5E1);

const Color _tooltipBg = Color(0xFF0F172A);

/// Movement clinical module.
///
/// Visualises actigraphy (step count, acticounts, accelerometer), activity
/// classification (STILL/WALK/RUN/GENERIC), intensity (SED/LPA/MPA/VPA),
/// and the 3-axis biomechanical signal for the selected time window.
/// Uses two tabs: Dashboard and Export/Analysis.
class MovimientoScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const MovimientoScreen({super.key, required this.participantId, required this.username});

  @override
  State<MovimientoScreen> createState() => _MovimientoScreenState();
}

class _MovimientoScreenState extends State<MovimientoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchMovimientoMetrics(
            widget.participantId, widget.username);
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
      builder: (context, provider, _) => Column(
        children: [
          _ControlPanel(
            provider: provider,
            participantId: widget.participantId,
            username: widget.username,
          ),
          Container(
            color: AppColors.bgCard,
            child: TabBar(
              controller: _tabController,
              labelColor: _identidad,
              unselectedLabelColor: _muted,
              indicatorColor: _identidad,
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
                Container(
                  color: _bg,
                  child: provider.isMovimientoLoading
                      ? const Center(child: CircularProgressIndicator(color: _identidad))
                      : _buildDashboard(provider),
                ),
                AnalisisExportacionTab(
                  participantId: widget.participantId,
                  username: widget.username,
                  metrics: provider.movimientoMetrics,
                  availableSensors: kMovimientoSensores,
                  accentColor: _identidad,
                  startTime: provider.movimientoStart,
                  endTime: provider.movimientoEnd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(DashboardProvider provider) {
    final metrics = provider.movimientoMetrics;
    if (metrics.isEmpty) return _NoDataPlaceholder();

    final byType = <String, List<Biomarker>>{};
    for (final m in metrics) {
      final type = m.sensorType.toLowerCase().replaceAll('-', '_');
      byType.putIfAbsent(type, () => []).add(m);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isLaptop = constraints.maxWidth > 1100;
        final padding  = isMobile ? 12.0 : (constraints.maxWidth > 720 ? 24.0 : 16.0);

        final sections = [
          _KPIsLayer(byType: byType, provider: provider),
          const SizedBox(height: 24),
          _ActivitySpectrum(byType: byType),
          _CargaCinetica(byType: byType),
          _EficienciaMarcha(
            stepData:    byType['step_count'] ?? [],
            wearingData: byType['wearing_detection'] ?? [],
          ),
          _AnalisisBiomecanico(byType: byType),
        ];

        if (isLaptop) {
          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              sections[0],
              const SizedBox(height: 24),
              sections[2],
              const SizedBox(height: 4),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: sections[3]),
                    const SizedBox(width: 20),
                    Expanded(child: sections[4]),
                  ],
                ),
              ),
              sections[5],
            ],
          );
        }
        return ListView(padding: EdgeInsets.all(padding), children: sections);
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
                  color: _identidad.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.move, size: 16, color: _identidad),
              );
              final headerTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movimiento y Actividad Física',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
                  ),
                  Text(
                    'Evaluación de los pasos, la intensidad del esfuerzo y la estabilidad del movimiento.',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted),
                  ),
                ],
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
                    _ResolutionBadge(label: provider.movimientoResolucion),
                  ],
                );
              }

              return Row(
                children: [
                  headerIcon,
                  const SizedBox(width: 12),
                  Expanded(child: headerTitle),
                  const SizedBox(width: 12),
                  _ResolutionBadge(label: provider.movimientoResolucion),
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

class _ResolutionBadge extends StatelessWidget {
  final String label;
  const _ResolutionBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _identidad.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _identidad.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.gauge, size: 11, color: _identidad),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: _identidad),
          ),
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
    final initialDate = isStart ? provider.movimientoStart : provider.movimientoEnd;
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
                primary: _identidad,
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
              primary: _identidad,
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

      DateTime start = provider.movimientoStart!;
      DateTime end = provider.movimientoEnd!;

      if (isStart) {
        start = newDate;
        if (start.isAfter(end)) end = start.add(const Duration(hours: 1));
      } else {
        end = newDate;
        if (end.isBefore(start)) start = end.subtract(const Duration(hours: 1));
      }

      provider.setMovimientoRango(start, end, participantId, username);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (provider.movimientoStart == null || provider.movimientoEnd == null) return const SizedBox();

    final dataSpansDays = provider.dataRangeStart != null
        && provider.dataRangeEnd != null
        && !DateUtils.isSameDay(provider.dataRangeStart!, provider.dataRangeEnd!);
    final startStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.movimientoStart!)}\n${DateFormat('HH:mm').format(provider.movimientoStart!)}'
        : DateFormat('HH:mm').format(provider.movimientoStart!);
    final endStr = dataSpansDays
        ? '${DateFormat('dd MMM').format(provider.movimientoEnd!)}\n${DateFormat('HH:mm').format(provider.movimientoEnd!)}'
        : DateFormat('HH:mm').format(provider.movimientoEnd!);
    final spansDays = !DateUtils.isSameDay(provider.movimientoStart!, provider.movimientoEnd!);
    final dateStr = spansDays
        ? '${DateFormat('dd MMM').format(provider.movimientoStart!)} → ${DateFormat('dd MMM').format(provider.movimientoEnd!)}'
        : DateFormat('dd MMM yyyy').format(provider.movimientoStart!);

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

class _KPIsLayer extends StatelessWidget {
  final Map<String, List<Biomarker>> byType;
  final DashboardProvider provider;

  const _KPIsLayer({required this.byType, required this.provider});

  @override
  Widget build(BuildContext context) {
    final stepsData = byType['step_count'] ?? [];
    final int totalSteps = stepsData.where((e) => e.value != null).fold(0, (a, b) => a + b.value!.toInt());

    final intensityData = byType['activity_intensity'] ?? [];
    double avgIntensity = 0;
    if (intensityData.isNotEmpty) {
      final validIntensity = intensityData.where((e) => e.value != null).map((e) => e.value!).toList();
      if (validIntensity.isNotEmpty) avgIntensity = validIntensity.reduce((a, b) => a + b) / validIntensity.length;
    }

    final vecData = byType['actigraphy_vector'] ?? byType['acticounts_total'] ?? [];
    double avgVec = 0;
    if (vecData.isNotEmpty) {
      final validVec = vecData.where((e) => e.value != null).map((e) => e.value!).toList();
      if (validVec.isNotEmpty) avgVec = validVec.reduce((a, b) => a + b) / validVec.length;
    }

    final compliance = provider.compliancePercentage ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final kpis = [
          _KPICard(
            title: 'Pasos Totales',
            value: totalSteps == 0 ? '--' : '$totalSteps',
            subtitle: 'Pasos registrados',
            icon: LucideIcons.footprints,
            color: _identidad,
            tooltip: "[Sensor: \"step_count\"]. Suma total de pasos detectados. Los objetivos saludables recomiendan más de 250 pasos por hora activa. Un pico de ejercicio vigoroso puede superar los 100 pasos/minuto.",
          ),
          _KPICard(
            title: 'Esfuerzo Promedio',
            value: intensityData.isEmpty ? '--' : avgIntensity.toStringAsFixed(1),
            subtitle: 'Intensidad metabólica',
            icon: LucideIcons.gauge,
            color: _intMPA,
            tooltip: "[Sensor: \"met\"]. Intensidad de esfuerzo (METs). Valores de 1.0 a 1.5 representan sedentarismo; de 1.5 a 3.0 indican actividad ligera (caminar despacio) y valores mayores a 3.0 indican actividad moderada o vigorosa.",
          ),
          _KPICard(
            title: 'Volumen de Movimiento',
            value: vecData.isEmpty ? '--' : avgVec.toStringAsFixed(0),
            subtitle: 'Intensidad del movimiento',
            icon: LucideIcons.activity,
            color: _kStability,
            tooltip: "[Sensores: \"actigraphy_vector\" / \"activity_counts\"]. Media de acticounts (potencia de movimiento). Periodos de reposo registran valores bajos (<50 counts). Actividades muy dinámicas generan picos que superan los 800 o 1000 counts.",
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
            color: _identidad,
          ),
        ),
      ),
    );
  }
}

class _ActivitySpectrum extends StatelessWidget {
  final Map<String, List<Biomarker>> byType;
  const _ActivitySpectrum({required this.byType});

  static bool _isGap(String flag) =>
      flag.contains('device_not_recording') || flag.contains('device_not_worn_correctly');

  Color _colorCls(Biomarker m) {
    if (_isGap(m.qualityFlag)) return _clsGap;
    if (m.value == null) return _clsGap;
    switch (m.value!.toInt().clamp(0, 3)) {
      case 0: return _clsStill;
      case 1: return _clsWalk;
      case 2: return _clsRun;
      case 3: return _clsGeneric;
      default: return _clsGap;
    }
  }

  Color _colorInt(Biomarker m) {
    if (_isGap(m.qualityFlag)) return _intGap;
    if (m.value == null) return _intGap;
    switch (m.value!.toInt().clamp(0, 3)) {
      case 0: return _intSed;
      case 1: return _intLPA;
      case 2: return _intMPA;
      case 3: return _intVPA;
      default: return _intGap;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cls     = byType['activity_class']     ?? [];
    final intData = byType['activity_intensity'] ?? [];

    return _SectionCard(
      icon: LucideIcons.layers,
      title: 'Espectro de Actividad y Postura',
      subtitle: 'Comparativa temporal entre el tipo de actividad y la intensidad del esfuerzo.',
      tooltip: '[Sensores: "activity_class" (tipo de movimiento) y "activity_intensity" (intensidad)]. Mapa de calor que permite identificar rápidamente periodos de sedentarismo prolongado y evaluar si los episodios de deambulación alcanzan los umbrales de intensidad vigorosa o moderada requeridos.',
      child: Column(
        children: [
          _HeatmapRow(label: 'POSTURA', data: cls, colorFn: _colorCls),
          const SizedBox(height: 12),
          _HeatmapRow(label: 'INTENSIDAD', data: intData, colorFn: _colorInt),
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            return narrow
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SpectrumLegendCls(),
                    const SizedBox(height: 20),
                    _SpectrumLegendInt(),
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _SpectrumLegendCls()),
                    const SizedBox(width: 40),
                    Expanded(child: _SpectrumLegendInt()),
                  ]);
          }),
        ],
      ),
    );
  }
}

class _SpectrumLegendCls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TIPO DE MOVIMIENTO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 10, children: [
        _LegendItem('En reposo',    _clsStill),
        _LegendItem('Caminando',  _clsWalk),
        _LegendItem('Corriendo',   _clsRun),
        _LegendItem('Actividad general',  _clsGeneric),
        _LegendItem('Desconectado', _clsGap),
      ]),
    ]);
  }
}

class _SpectrumLegendInt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INTENSIDAD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 10, children: [
        _LegendItem('Sedentario', _intSed),
        _LegendItem('Ligero (LPA)',        _intLPA),
        _LegendItem('Moderado (MPA)',        _intMPA),
        _LegendItem('Vigoroso (VPA)',        _intVPA),
        _LegendItem('Desconectado',  _intGap),
      ]),
    ]);
  }
}

class _CargaCinetica extends StatelessWidget {
  final Map<String, List<Biomarker>> byType;
  const _CargaCinetica({required this.byType});

  @override
  Widget build(BuildContext context) {
    final vec = byType['actigraphy_vector'] ?? byType['acticounts_total'] ?? [];
    final std = byType['accelerometer_std'] ?? [];
    final sensoresAusentes = !byType.containsKey('actigraphy_vector') && !byType.containsKey('acticounts_total');

    return _SectionCard(
      icon: LucideIcons.trendingUp,
      title: 'Intensidad y Estabilidad del Movimiento',
      subtitle: 'Comparativa entre la fuerza del movimiento y la regularidad del ritmo.',
      tooltip: '[Sensores: "actigraphy_vector" / "activity_counts" (fuerza) y "accelerometer_std" (irregularidad)]. Compara la fuerza del movimiento y la irregularidad o temblor. Permite evaluar la regularidad de la marcha.',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: vec.isEmpty
                ? _emptyChart(sinSensores: sensoresAusentes)
                : LineChart(_buildChart(vec, std)),
          ),
          const SizedBox(height: 24),
          Wrap(spacing: 28, runSpacing: 12, children: [
            _LegendItem('Fuerza', _kMagnitude),
            _LegendItem('Irregularidad',  _kStability),
          ]),
        ],
      ),
    );
  }

  Widget _emptyChart({bool sinSensores = false}) => Center(
    child: Text(
      sinSensores
          ? 'Sin datos de movimiento vectorial.\nSube el sensor actigraphy-counts o acticounts para ver este gráfico.'
          : 'Datos insuficientes por baja calidad de señal (Compliance < 80%)',
      style: GoogleFonts.inter(color: _muted, fontSize: 13),
      textAlign: TextAlign.center,
    ),
  );

  LineChartData _buildChart(List<Biomarker> vec, List<Biomarker> std) {
    final t0  = vec.first.time.millisecondsSinceEpoch;
    final span = vec.last.time.millisecondsSinceEpoch - t0;
    if (span <= 0) return LineChartData();

    final maxVec = vec.map((e) => e.value ?? 0).fold(0.0, (a, b) => a > b ? a : b);
    final maxStd = std.isNotEmpty ? std.map((e) => e.value ?? 0).fold(0.0, (a, b) => a > b ? a : b) : 1.0;
    final scale  = maxStd > 0 ? maxVec / maxStd : 1.0;

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: vec.where((m) => m.value != null).map((m) => FlSpot((m.time.millisecondsSinceEpoch - t0) / span * 100, m.value!)).toList(),
          isCurved: true,
          color: _kMagnitude,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _kMagnitude.withValues(alpha: 0.2),
          ),
        ),
        if (std.isNotEmpty)
          LineChartBarData(
            spots: std.where((m) => m.value != null).map((m) => FlSpot((m.time.millisecondsSinceEpoch - t0) / span * 100, m.value! * scale)).toList(),
            isCurved: true,
            color: _kStability,
            barWidth: 1.0,
            dotData: const FlDotData(show: false),
          ),
      ],
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _tooltipBg,
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            final label = spot.bar.color == _kMagnitude ? 'Fuerza' : 'Irregularidad';
            return LineTooltipItem(
              '$label: ${spot.y.toStringAsFixed(0)}',
              GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EficienciaMarcha extends StatelessWidget {
  final List<Biomarker> stepData;
  final List<Biomarker> wearingData;
  const _EficienciaMarcha({required this.stepData, required this.wearingData});

  @override
  Widget build(BuildContext context) {
    final stepsPerEpochHour = <int, int>{};
    final epochHourDataCount = <int, int>{};
    for (var m in stepData) {
      final key = m.time.millisecondsSinceEpoch ~/ 3600000;
      epochHourDataCount[key] = (epochHourDataCount[key] ?? 0) + 1;
      if (m.value != null) {
        stepsPerEpochHour[key] = (stepsPerEpochHour[key] ?? 0) + m.value!.toInt();
      }
    }
    final allKeys = stepsPerEpochHour.keys.toList()..sort();
    final sortedKeys = allKeys.where((k) => (epochHourDataCount[k] ?? 0) >= 2).toList();
    final stepSpansDays = sortedKeys.length > 1 &&
        DateTime.fromMillisecondsSinceEpoch(sortedKeys.first * 3600000).day !=
        DateTime.fromMillisecondsSinceEpoch(sortedKeys.last * 3600000).day;
    const double target = 250.0;

    return _SectionCard(
      icon: LucideIcons.footprints,
      title: 'Pasos por Hora',
      subtitle: 'Pasos acumulados en cada hora comparados con el objetivo clínico de movilidad.',
      tooltip: '[Sensor: "step_count"]. Cuantificación del volumen de marcha. Las barras que superan la línea punteada indican que el paciente ha cumplido el objetivo mínimo de movilidad para esa franja horaria.',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: sortedKeys.isEmpty
                ? Center(child: Text('Dispositivo desconectado', style: GoogleFonts.inter(color: _muted, fontSize: 13)))
                : BarChart(BarChartData(
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => _tooltipBg,
                        getTooltipItem: (group, _, rod, __) {
                          final epochHour = sortedKeys[group.x.toInt()];
                          final dt = DateTime.fromMillisecondsSinceEpoch(epochHour * 3600000);
                          final label = stepSpansDays ? DateFormat('dd/MM HH:mm').format(dt) : DateFormat('HH:mm').format(dt);
                          return BarTooltipItem(
                            '$label: ${rod.toY.toInt()} pasos',
                            GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    barGroups: sortedKeys.asMap().entries.map((entry) {
                      final index = entry.key;
                      final val = stepsPerEpochHour[entry.value]!.toDouble();
                      final isAbove = val >= target;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: val,
                            color: isAbove ? _identidad : _identidad.withValues(alpha: 0.6),
                            width: 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ],
                      );
                    }).toList(),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: target,
                          color: _targetColor,
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: GoogleFonts.jetBrainsMono(fontSize: 9, color: _pizarra, fontWeight: FontWeight.bold),
                            labelResolver: (_) => 'OBJETIVO (250)',
                          ),
                        ),
                      ],
                    ),
                    titlesData: const FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData:   const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  )),
          ),
          const SizedBox(height: 24),
          _LegendItem('Pasos registrados', _identidad),
        ],
      ),
    );
  }
}

class _AnalisisBiomecanico extends StatefulWidget {
  final Map<String, List<Biomarker>> byType;
  const _AnalisisBiomecanico({required this.byType});
  @override
  State<_AnalisisBiomecanico> createState() => _AnalisisBiomecanicoState();
}

class _AnalisisBiomecanicoState extends State<_AnalisisBiomecanico> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final x = widget.byType['acticounts_x'] ?? [];
    final y = widget.byType['acticounts_y'] ?? [];
    final z = widget.byType['acticounts_z'] ?? [];

    return _SectionCard(
      icon: LucideIcons.box,
      title: 'Movimiento en 3 Dimensiones',
      subtitle: 'Detalle de la aceleración tridimensional en los ejes X, Y y Z.',
      tooltip: '[Sensores: "acticounts_x", "acticounts_y", "acticounts_z"]. Representación tridimensional de la aceleración. Exclusivo para análisis del movimiento detallado, asimetrías de la marcha o cambios posturales.',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _expanded = !_expanded),
        icon: Icon(_expanded ? LucideIcons.eyeOff : LucideIcons.eye, size: 15, color: _identidad),
        label: Text(
          _expanded ? 'OCULTAR' : 'VER EJES',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _identidad),
        ),
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 350),
        crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Despliega para ver el movimiento en las 3 dimensiones del espacio.', style: GoogleFonts.inter(fontSize: 13, color: _muted)),
        ),
        secondChild: x.isEmpty
            ? Text('Dispositivo desconectado', style: GoogleFonts.inter(color: _muted, fontSize: 13))
            : Column(
                children: [
                  SizedBox(height: 220, child: LineChart(_buildChart(x, y, z))),
                  const SizedBox(height: 24),
                  Wrap(spacing: 20, runSpacing: 12, children: [
                    _LegendItem('Eje Lateral (Derecha-Izquierda) [X]', _axisX),
                    _LegendItem('Eje Vertical (Arriba-Abajo) [Y]',     _axisY),
                    _LegendItem('Eje Frontal (Adelante-Atrás) [Z]',      _axisZ),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _identidad.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _identidad.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.info, size: 16, color: _identidad),
                            const SizedBox(width: 8),
                            Text(
                              '¿Cómo interpretar este gráfico?',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _identidad),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'El acelerómetro mide la fuerza de aceleración en las tres dimensiones físicas:\n'
                          '• Eje X (Lateral): Movimiento hacia los lados. Refleja braceos laterales.\n'
                          '• Eje Y (Vertical): Movimiento vertical. Muy alto durante el impacto de la pisada al caminar o correr.\n'
                          '• Eje Z (Frontal): Movimiento adelante/atrás. Refleja el balanceo del brazo al avanzar en el espacio.',
                          style: GoogleFonts.inter(fontSize: 11, color: _muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  LineChartData _buildChart(List<Biomarker> x, List<Biomarker> y, List<Biomarker> z) {
    if (x.isEmpty) return LineChartData();
    final t0 = x.first.time.millisecondsSinceEpoch;
    final span = x.last.time.millisecondsSinceEpoch - t0;
    if (span <= 0) return LineChartData();

    final allValues = [
      ...x.where((e) => e.value != null).map((e) => e.value!),
      ...y.where((e) => e.value != null).map((e) => e.value!),
      ...z.where((e) => e.value != null).map((e) => e.value!),
    ];
    double minY = 0;
    double maxY = 100;
    if (allValues.isNotEmpty) {
      final absoluteMin = allValues.reduce(math.min);
      final absoluteMax = allValues.reduce(math.max);
      final range = absoluteMax - absoluteMin;
      minY = absoluteMin - (range > 0 ? range * 0.15 : 10);
      maxY = absoluteMax + (range > 0 ? range * 0.15 : 10);
      if (minY < 0) minY = 0;
    }

    LineChartBarData bar(List<Biomarker> data, Color color) => LineChartBarData(
      spots: data.where((m) => m.value != null).map((m) => FlSpot((m.time.millisecondsSinceEpoch - t0) / span * 100, m.value!)).toList(),
      isCurved: true,
      color: color,
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
    );

    return LineChartData(
      minY: minY,
      maxY: maxY,
      lineBarsData: [bar(x, _axisX), bar(y, _axisY), bar(z, _axisZ)],
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _tooltipBg,
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            final String label;
            if (spot.bar.color == _axisX) {
              label = 'X';
            } else if (spot.bar.color == _axisY) {
              label = 'Y';
            } else {
              label = 'Z';
            }
            return LineTooltipItem(
              '$label: ${spot.y.toStringAsFixed(0)}',
              GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? tooltip;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.icon, required this.title, required this.subtitle, this.tooltip, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 24),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _identidad.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 20, color: _identidad),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
                          if (tooltip != null)
                            Tooltip(
                              message: tooltip!,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(color: _text.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(8)),
                              textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                              child: Icon(LucideIcons.info, size: 14, color: _muted.withValues(alpha: 0.6)),
                            ),
                        ],
                      ),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _muted)),
      ],
    );
  }
}

class _HeatmapRow extends StatelessWidget {
  final String label;
  final List<Biomarker> data;
  final Color Function(Biomarker) colorFn;
  const _HeatmapRow({required this.label, required this.data, required this.colorFn});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 40, child: CustomPaint(painter: _HeatmapPainter(data: data, colorFn: colorFn))))),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<Biomarker> data;
  final Color Function(Biomarker) colorFn;
  _HeatmapPainter({required this.data, required this.colorFn});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final start = data.first.time.millisecondsSinceEpoch;
    final range = data.last.time.millisecondsSinceEpoch - start;
    if (range <= 0) return;
    for (int i = 0; i < data.length; i++) {
      paint.color = colorFn(data[i]);
      final x    = (data[i].time.millisecondsSinceEpoch - start) / range * size.width;
      final next = i < data.length - 1
          ? (data[i + 1].time.millisecondsSinceEpoch - start) / range * size.width
          : size.width;
      canvas.drawRect(Rect.fromLTRB(x, 0, next, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _NoDataPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.database, size: 48, color: _muted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Datos insuficientes por baja calidad de señal (Compliance < 80%)', style: GoogleFonts.inter(color: _muted, fontSize: 14)),
        ],
      ),
    );
  }
}
