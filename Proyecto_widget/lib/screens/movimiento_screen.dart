import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/biomarker.dart';
import '../providers/dashboard_provider.dart';
import '../utils/app_colors.dart';

const Color _bg      = AppColors.bgScreen;
const Color _surface = AppColors.bgCard;
const Color _border  = AppColors.border;
const Color _text    = AppColors.textPrimary;
const Color _muted   = AppColors.textSecondary;
const Color _accent  = AppColors.cyberBlue;
const Color _iconAccent = Colors.orange;

const Color _clsGap     = Color(0xFFF1F5F9);
const Color _clsStill   = Color(0xFF94A3B8);
const Color _clsWalk    = Color(0xFF10B981);
const Color _clsRun     = Color(0xFF8B5CF6);
const Color _clsGeneric = Color(0xFF64748B);

const Color _intGap = Color(0xFFF1F5F9);
const Color _intSed = Color(0xFFE2E8F0);
const Color _intLPA = Color(0xFFFDE047);
const Color _intMPA = Color(0xFFFB923C);
const Color _intVPA = Color(0xFFEA580C);

const Color _kVec = Color(0xFF8B5CF6);
const Color _kStd = Color(0xFF10B981);

const Color _gaitBar = Colors.orange;
const Color _gaitBg  = Color(0xFFF8FAFC);

const Color _axisX = Color(0xFF8B5CF6);
const Color _axisY = Color(0xFF10B981);
const Color _axisZ = Color(0xFFF59E0B);

class MovimientoScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const MovimientoScreen({super.key, required this.participantId, required this.username});

  @override
  State<MovimientoScreen> createState() => _MovimientoScreenState();
}

class _MovimientoScreenState extends State<MovimientoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchMovimientoMetrics(
            widget.participantId, widget.username);
    });
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
          Expanded(
            child: Container(
              color: _bg,
              child: provider.isMovimientoLoading
                  ? const Center(child: CircularProgressIndicator(color: _accent))
                  : _buildDashboard(provider),
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
      byType.putIfAbsent(m.sensorType, () => []).add(m);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLaptop = constraints.maxWidth > 1100;
        final padding  = constraints.maxWidth > 720 ? 24.0 : 16.0;

        final sections = [
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
              const SizedBox(height: 4),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: sections[1]),
                    const SizedBox(width: 20),
                    Expanded(child: sections[2]),
                  ],
                ),
              ),
              sections[3],
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
                  color: _iconAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.personStanding, size: 16, color: _iconAccent),
              );
              final headerTitle = Text(
                'Movimiento y Actividad',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: _text),
              );
              final resolutionBadge = provider.movimientoResolucion.isEmpty
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
                            provider.movimientoResolucion,
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
    final initialDate = isStart ? provider.movimientoStart : provider.movimientoEnd;
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

    final startStr = DateFormat('HH:mm').format(provider.movimientoStart!);
    final endStr = DateFormat('HH:mm').format(provider.movimientoEnd!);
    final dateStr = DateFormat('dd MMM yyyy').format(provider.movimientoStart!);

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
    final cls = byType['activity_class']     ?? [];
    final int = byType['activity_intensity'] ?? [];

    return _SectionCard(
      icon: LucideIcons.flame,
      title: 'Activity Spectrum',
      subtitle: 'activity-intensity + activity-classification',
      child: Column(
        children: [
          _HeatmapRow(label: 'MOTOR', data: cls, colorFn: _colorCls),
          const SizedBox(height: 12),
          _HeatmapRow(label: 'INTENSIDAD', data: int, colorFn: _colorInt),
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
      Text('CLASIFICACIÓN', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 10, children: [
        _LegendItem('Quieto',    _clsStill),
        _LegendItem('Caminata',  _clsWalk),
        _LegendItem('Carrera',   _clsRun),
        _LegendItem('Genérico',  _clsGeneric),
        _LegendItem('Sin datos', _clsGap),
      ]),
    ]);
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
        SizedBox(
          width: 88,
          child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(height: 40, child: CustomPaint(painter: _HeatmapPainter(data: data, colorFn: colorFn))),
          ),
        ),
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



class _SpectrumLegendInt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INTENSIDAD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.5)),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 10, children: [
        _LegendItem('Sedentario', _intSed),
        _LegendItem('LPA',        _intLPA),
        _LegendItem('MPA',        _intMPA),
        _LegendItem('VPA',        _intVPA),
        _LegendItem('Sin datos',  _intGap),
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

    return _SectionCard(
      icon: LucideIcons.barChart3,
      title: 'Carga Cinética',
      subtitle: 'actigraphy-counts + accelerometers-std',
      child: Column(
        children: [
          SizedBox(height: 200, child: vec.isEmpty ? _emptyChart() : LineChart(_buildChart(vec, std))),
          const SizedBox(height: 24),
          Wrap(spacing: 28, runSpacing: 12, children: [
            _LegendItem('Magnitud Vectorial', _kVec),
            _LegendItem('Estabilidad (STD)',  _kStd),
          ]),
        ],
      ),
    );
  }

  Widget _emptyChart() => Center(
    child: Text('Sin datos de carga cinética', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
  );

  LineChartData _buildChart(List<Biomarker> vec, List<Biomarker> std) {
    final t0  = vec.first.time.millisecondsSinceEpoch;
    final span = vec.last.time.millisecondsSinceEpoch - t0;
    if (span <= 0) return LineChartData();

    final maxVec = vec.map((e) => e.value ?? 0).fold(0.0, (a, b) => a > b ? a : b);
    final maxStd = std.isNotEmpty ? std.map((e) => e.value ?? 0).fold(0.0, (a, b) => a > b ? a : b) : 1.0;
    final scale  = maxStd > 0 ? maxVec / maxStd : 1.0;

    List<FlSpot> vecSpots = vec
        .where((m) => m.value != null)
        .map((m) => FlSpot((m.time.millisecondsSinceEpoch - t0) / span * 100, m.value!))
        .toList();

    List<FlSpot> stdSpots = std
        .where((m) => m.value != null)
        .map((m) => FlSpot((m.time.millisecondsSinceEpoch - t0) / span * 100, m.value! * scale))
        .toList();

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: vecSpots,
          isCurved: true,
          color: _kVec,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kVec.withValues(alpha: 0.18), _kVec.withValues(alpha: 0.01)],
            ),
          ),
        ),
        if (stdSpots.isNotEmpty)
          LineChartBarData(
            spots: stdSpots,
            isCurved: true,
            color: _kStd.withValues(alpha: 0.8),
            barWidth: 0.9,
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
          getTooltipColor: (_) => _surface,
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
            '${s.barIndex == 0 ? "MAG" : "STD"}: ${s.y.toStringAsFixed(1)}',
            GoogleFonts.jetBrainsMono(color: _text, fontSize: 11, fontWeight: FontWeight.bold),
          )).toList(),
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
    final stepsPerHour    = <int, int>{};
    final wearingPerHour  = <int, int>{};
    final totalPerHour    = <int, int>{};

    for (var m in stepData) {
      if (m.value != null) {
        stepsPerHour[m.time.hour] = (stepsPerHour[m.time.hour] ?? 0) + m.value!.toInt();
      }
    }
    for (var m in wearingData) {
      final h = m.time.hour;
      totalPerHour[h] = (totalPerHour[h] ?? 0) + 1;
      if (!m.qualityFlag.contains('device_not_worn_correctly') && !m.qualityFlag.contains('device_not_recording')) {
        wearingPerHour[h] = (wearingPerHour[h] ?? 0) + 1;
      }
    }

    final hours   = stepsPerHour.keys.toList()..sort();
    final maxSteps = stepsPerHour.values.isEmpty ? 1 : stepsPerHour.values.reduce((a, b) => a > b ? a : b);

    return _SectionCard(
      icon: LucideIcons.footprints,
      title: 'Eficiencia de Marcha',
      subtitle: 'step-counts',
      child: Column(
        children: [
          SizedBox(
            height: 200,
        child: hours.isEmpty
            ? Center(child: Text('Sin datos de pasos', style: GoogleFonts.inter(color: _muted, fontSize: 13)))
            : BarChart(BarChartData(
                barGroups: hours.map((h) {
                  final compliance = totalPerHour[h] != null && totalPerHour[h]! > 0
                      ? (wearingPerHour[h] ?? 0) / totalPerHour[h]!
                      : 0.0;
                  return BarChartGroupData(
                    x: h,
                    barRods: [
                      BarChartRodData(
                        toY: stepsPerHour[h]!.toDouble(),
                        color: Color.lerp(_gaitBar.withValues(alpha: 0.5), _gaitBar, compliance)!,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxSteps.toDouble(),
                          color: _gaitBg,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${v.toInt()}h', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _muted, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData:   const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _surface,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toInt()} pasos',
                      GoogleFonts.jetBrainsMono(color: _gaitBar, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(spacing: 28, runSpacing: 12, children: [
            _LegendItem('Pasos detectados', _gaitBar),
            _LegendItem('Periodo de inactividad', _gaitBg),
          ]),
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
      title: 'Análisis Biomecánico',
      subtitle: 'acticounts (Ejes X, Y, Z)',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _expanded = !_expanded),
        icon: Icon(_expanded ? LucideIcons.eyeOff : LucideIcons.eye, size: 15, color: _accent),
        label: Text(
          _expanded ? 'OCULTAR' : 'VER EJES',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _accent),
        ),
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 350),
        crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Despliega para ver los ejes X, Y, Z del acelerómetro.',
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
          ),
        ),
        secondChild: x.isEmpty
            ? Text('Sin datos de ejes', style: GoogleFonts.inter(color: _muted, fontSize: 13))
            : Column(
                children: [
                  SizedBox(height: 220, child: LineChart(_buildChart(x, y, z))),
                  const SizedBox(height: 24),
                  Wrap(spacing: 20, runSpacing: 12, children: [
                    _LegendItem('Eje X — Lateral',         _axisX),
                    _LegendItem('Eje Y — Vertical',        _axisY),
                    _LegendItem('Eje Z — Anteroposterior', _axisZ),
                  ]),
                ],
              ),
      ),
    );
  }

  LineChartData _buildChart(List<Biomarker> x, List<Biomarker> y, List<Biomarker> z) {
    if (x.isEmpty) return LineChartData();
    final t0   = x.first.time.millisecondsSinceEpoch;
    final span = x.last.time.millisecondsSinceEpoch - t0;
    if (span <= 0) return LineChartData();

    LineChartBarData bar(List<Biomarker> data, Color color) => LineChartBarData(
      spots: data.where((m) => m.value != null).map((m) =>
          FlSpot((m.time.millisecondsSinceEpoch - t0) / span * 100, m.value!)).toList(),
      isCurved: true,
      color: color,
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.0)],
        ),
      ),
    );

    return LineChartData(
      lineBarsData: [bar(x, _axisX), bar(y, _axisY), bar(z, _axisZ)],
      titlesData: const FlTitlesData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _surface,
          getTooltipItems: (spots) => spots.map((s) {
            final label = ['X', 'Y', 'Z'][s.barIndex.clamp(0, 2)];
            final c     = [_axisX, _axisY, _axisZ][s.barIndex.clamp(0, 2)];
            return LineTooltipItem(
              '$label: ${s.y.toStringAsFixed(1)}',
              GoogleFonts.jetBrainsMono(color: c, fontSize: 11, fontWeight: FontWeight.bold),
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
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _iconAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 20, color: _iconAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(padding: const EdgeInsets.all(20), child: child),
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
    ]);
  }
}

class _NoDataPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.database, size: 64, color: _border),
        const SizedBox(height: 20),
        Text('Sin registros en este periodo', style: GoogleFonts.outfit(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Selecciona otro intervalo de tiempo.', style: GoogleFonts.inter(color: _muted, fontSize: 13)),
      ]),
    );
  }
}

