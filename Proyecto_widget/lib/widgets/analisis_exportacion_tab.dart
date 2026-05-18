import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/biomarker.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/interpolation_utils.dart';
import 'app_toast.dart';

const _surface   = AppColors.bgCard;
const _bg        = AppColors.bgScreen;
const _border    = AppColors.border;
const _text      = AppColors.textPrimary;
const _muted     = AppColors.textSecondary;
const _cardBg    = Color(0xFFF1F5F9);

const _bucketOptions = [
  '30 seconds', '1 minute', '2 minutes',
  '5 minutes', '10 minutes', '15 minutes', '1 hour',
];

const _methodOptions = [
  ('linear', 'Lineal'),
  ('spline', 'Spline Cúbica'),
  ('ffill', 'Forward Fill (Categórico)'),
];

const _categoricalSensors = {
  'activity_class', 'sleep_detection', 'body_position', 'activity_intensity',
};

class AnalisisExportacionTab extends StatefulWidget {
  final String participantId;
  final String username;
  final List<Biomarker> metrics;
  final List<String> availableSensors;
  final Color accentColor;
  final DateTime? startTime;
  final DateTime? endTime;

  const AnalisisExportacionTab({
    super.key,
    required this.participantId,
    required this.username,
    required this.metrics,
    required this.availableSensors,
    required this.accentColor,
    this.startTime,
    this.endTime,
  });

  @override
  State<AnalisisExportacionTab> createState() => _AnalisisExportacionTabState();
}

class _AnalisisExportacionTabState extends State<AnalisisExportacionTab> {
  String? _selectedSensor;
  String _selectedMethod = 'linear';
  String _selectedBucket = '1 minute';
  late Map<String, bool> _sensorEnabled;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _sensorEnabled = {for (final s in widget.availableSensors) s: true};
    _refreshSensor();
  }

  @override
  void didUpdateWidget(covariant AnalisisExportacionTab old) {
    super.didUpdateWidget(old);
    if (old.metrics != widget.metrics) {
      final sensors = _sensorsWithData;
      if (_selectedSensor == null || !sensors.contains(_selectedSensor)) {
        setState(() => _selectedSensor = sensors.isNotEmpty ? sensors.first : null);
      }
    }
  }

  void _refreshSensor() {
    final sensors = _sensorsWithData;
    _selectedSensor = sensors.isNotEmpty ? sensors.first : null;
  }

  List<String> get _sensorsWithData {
    final types = widget.metrics.map((m) => m.sensorType).toSet();
    return widget.availableSensors.where((s) => types.contains(s)).toList();
  }

  List<Biomarker> get _sensorData {
    if (_selectedSensor == null) return [];
    return widget.metrics.where((m) => m.sensorType == _selectedSensor).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildBlockA(),
        const SizedBox(height: 24),
        _buildBlockB(),
        const SizedBox(height: 24),
        _buildBlockC(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── BLOCK A: Signal Reconstruction ──────────────────────────────────────────

  Widget _buildBlockA() {
    final data   = _sensorData;
    final result = data.isEmpty ? null : InterpolationUtils.compute(data, _selectedMethod);

    return _BlockCard(
      icon: LucideIcons.trendingUp,
      title: 'Reconstrucción Computacional de Señal',
      subtitle: 'Estimación de valores en periodos de baja calidad de señal.',
      accentColor: widget.accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _LabeledDropdown<String>(
                  label: 'Sensor',
                  value: _sensorsWithData.contains(_selectedSensor) ? _selectedSensor : null,
                  items: _sensorsWithData.isEmpty
                      ? [const DropdownMenuItem(value: null, child: Text('Sin datos'))]
                      : _sensorsWithData
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                  onChanged: (v) => setState(() => _selectedSensor = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LabeledDropdown<String>(
                  label: 'Método',
                  value: _selectedMethod,
                  items: _methodOptions
                      .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedMethod = v); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 13, color: widget.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La pulsera EmbracePlus marca los datos afectados por movimiento brusco o '
                    'mala señal. Esta herramienta estima los valores perdidos usando el método '
                    'seleccionado. El Spline real se aplica al exportar desde el servidor.',
                    style: GoogleFonts.inter(fontSize: 11, color: _muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: result == null
                ? Center(
                    child: Text(
                      'Selecciona un sensor con datos para ver la previsualización.',
                      style: GoogleFonts.inter(color: _muted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _PreviewChart(
                    original:     result.original,
                    interpolated: result.interpolated,
                    accentColor:  widget.accentColor,
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _MiniLegend('Datos Originales', widget.accentColor, dashed: false),
              _MiniLegend('Interpolado', widget.accentColor.withValues(alpha: 0.5), dashed: true),
            ],
          ),
        ],
      ),
    );
  }

  // ── BLOCK B: Stochastic Metrics ─────────────────────────────────────────────

  Widget _buildBlockB() {
    final data = _sensorData;
    final valid = data
        .where((m) => !InterpolationUtils.isBad(m.qualityFlag) && m.value != null)
        .map((m) => m.value!)
        .toList();

    double? mean, stdDev, modeVal, minVal, maxVal;
    double noisePercent = 0;

    if (data.isNotEmpty) {
      final badCount = data.where((m) => InterpolationUtils.isBad(m.qualityFlag)).length;
      noisePercent   = badCount / data.length * 100;
    }

    if (valid.isNotEmpty) {
      final m = valid.reduce((a, b) => a + b) / valid.length;
      mean = m;
      minVal = valid.reduce((a, b) => a < b ? a : b);
      maxVal = valid.reduce((a, b) => a > b ? a : b);
      if (valid.length >= 2) {
        final variance = valid.fold(0.0, (s, v) => s + (v - m) * (v - m)) / valid.length;
        stdDev = math.sqrt(variance);
      }
      if (_selectedSensor != null && _categoricalSensors.contains(_selectedSensor)) {
        final counts = <double, int>{};
        for (final v in valid) { counts[v] = (counts[v] ?? 0) + 1; }
        modeVal = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
    }

    return _BlockCard(
      icon: LucideIcons.activity,
      title: 'Métricas Estocásticas Avanzadas',
      subtitle: 'Estadísticos calculados sobre registros con calidad validada.',
      accentColor: widget.accentColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            _MetricCard(label: 'Media', value: mean?.toStringAsFixed(2) ?? '--'),
            _MetricCard(label: 'σ Desv. Típica', value: stdDev?.toStringAsFixed(2) ?? '--'),
            _MetricCard(label: 'Valor Mínimo', value: minVal?.toStringAsFixed(2) ?? '--'),
            _MetricCard(label: 'Valor Máximo', value: maxVal?.toStringAsFixed(2) ?? '--'),
            _MetricCard(
              label: 'Moda',
              value: modeVal?.toStringAsFixed(0) ?? (valid.isEmpty ? '--' : 'N/A'),
            ),
            _MetricCard(
              label: 'Carga de Ruido',
              value: data.isEmpty ? '--' : '${noisePercent.toStringAsFixed(1)}%',
            ),
          ];
          if (constraints.maxWidth < 600) {
            return Column(children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: cards[4]), const SizedBox(width: 12), Expanded(child: cards[5])]),
            ]);
          } else if (constraints.maxWidth < 900) {
            return Column(children: [
              Row(children: [
                Expanded(child: cards[0]), const SizedBox(width: 12),
                Expanded(child: cards[1]), const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: cards[3]), const SizedBox(width: 12),
                Expanded(child: cards[4]), const SizedBox(width: 12),
                Expanded(child: cards[5]),
              ]),
            ]);
          }
          return Row(children: [
            Expanded(child: cards[0]), const SizedBox(width: 12),
            Expanded(child: cards[1]), const SizedBox(width: 12),
            Expanded(child: cards[2]), const SizedBox(width: 12),
            Expanded(child: cards[3]), const SizedBox(width: 12),
            Expanded(child: cards[4]), const SizedBox(width: 12),
            Expanded(child: cards[5]),
          ]);
        },
      ),
    );
  }

  // ── BLOCK C: Export Config ───────────────────────────────────────────────────

  Widget _buildBlockC() {
    return _BlockCard(
      icon: LucideIcons.download,
      title: 'Configuración del DataSet de Salida',
      subtitle: 'Selecciona variables y resolución temporal para la exportación.',
      accentColor: widget.accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Variables a exportar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.availableSensors.map((s) {
              final enabled = _sensorEnabled[s] ?? true;
              return FilterChip(
                label: Text(s, style: GoogleFonts.jetBrainsMono(fontSize: 10)),
                selected: enabled,
                onSelected: (v) => setState(() => _sensorEnabled[s] = v),
                selectedColor: widget.accentColor.withValues(alpha: 0.15),
                checkmarkColor: widget.accentColor,
                side: BorderSide(
                  color: enabled ? widget.accentColor.withValues(alpha: 0.4) : _border,
                ),
                backgroundColor: _bg,
                labelStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: enabled ? widget.accentColor : _muted,
                  fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _LabeledDropdown<String>(
            label: 'Resolución temporal (bucket)',
            value: _selectedBucket,
            items: _bucketOptions
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) { if (v != null) setState(() => _selectedBucket = v); },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportData,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.download, size: 16),
              label: Text(
                _isExporting ? 'Procesando…' : 'Procesar y Exportar DataSet (CSV)',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await ApiService().exportParticipantCsv(
        widget.participantId,
        widget.username,
        bucketSize: _selectedBucket,
        method: _selectedMethod,
        startTime: widget.startTime?.toUtc().toIso8601String(),
        endTime: widget.endTime?.toUtc().toIso8601String(),
      );

      // Filtrado local de columnas (Brecha 1)
      String csvString = utf8.decode(bytes);
      List<String> lines = csvString.split('\n');
      if (lines.isNotEmpty) {
        List<String> headers = lines.first.split(',');
        
        List<int> keepIndices = [0]; // Siempre mantenemos la columna 'timestamp' (índice 0)
        for (int i = 1; i < headers.length; i++) {
          final colName = headers[i].trim().replaceAll('\r', '');
          if (_sensorEnabled[colName] ?? false) {
            keepIndices.add(i);
          }
        }

        List<String> filteredLines = [];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          List<String> cols = line.split(',');
          List<String> filteredCols = [];
          for (int idx in keepIndices) {
            if (idx < cols.length) {
              filteredCols.add(cols[idx]);
            }
          }
          filteredLines.add(filteredCols.join(','));
        }
        csvString = filteredLines.join('\n');
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'export_${widget.participantId}_$ts.csv';

      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Seleccione dónde guardar el archivo CSV:',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csvString)),
      );

      if (outputPath != null && !kIsWeb) {
        final file = File(outputPath);
        await file.writeAsString(csvString);
        if (mounted) {
          AppToast.show(context, 'CSV guardado con éxito en: $outputPath', type: ToastType.success);
        }
      } else if (kIsWeb) {
        if (mounted) {
          AppToast.show(context, 'CSV descargado con éxito', type: ToastType.success);
        }
      } else {
        if (mounted) {
          AppToast.show(context, 'Exportación cancelada', type: ToastType.info);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error al exportar: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _BlockCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _BlockCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accentColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _muted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: _text, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;

  const _MiniLegend(this.label, this.color, {required this.dashed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 5, height: 2, color: color),
                const SizedBox(width: 2),
                Container(width: 5, height: 2, color: color),
              ])
            : Container(width: 12, height: 2, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _muted)),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _muted)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 13, color: _text),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewChart extends StatelessWidget {
  final List<double?> original;
  final List<double?> interpolated;
  final Color accentColor;

  const _PreviewChart({
    required this.original,
    required this.interpolated,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final originalSpots     = <FlSpot>[];
    final interpolatedSpots = <FlSpot>[];

    for (int i = 0; i < interpolated.length; i++) {
      if (interpolated[i] != null) {
        interpolatedSpots.add(FlSpot(i.toDouble(), interpolated[i]!));
      }
      if (original[i] != null) {
        originalSpots.add(FlSpot(i.toDouble(), original[i]!));
      }
    }

    if (interpolatedSpots.isEmpty && originalSpots.isEmpty) {
      return Center(
        child: Text(
          'Sin valores válidos para previsualizar.',
          style: GoogleFonts.inter(color: _muted, fontSize: 13),
        ),
      );
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          if (interpolatedSpots.isNotEmpty)
            LineChartBarData(
              spots: interpolatedSpots,
              isCurved: true,
              color: accentColor.withValues(alpha: 0.45),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [4, 4],
            ),
          if (originalSpots.isNotEmpty)
            LineChartBarData(
              spots: originalSpots,
              isCurved: false,
              color: accentColor,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 2.5,
                  color: accentColor,
                  strokeWidth: 0,
                ),
              ),
            ),
        ],
        titlesData: const FlTitlesData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: _border.withValues(alpha: 0.4), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF0F172A),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipMargin: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final isOriginal = barSpot.barIndex == (interpolatedSpots.isNotEmpty ? 1 : 0);
                final label = isOriginal ? 'Real' : 'Interpolado';
                return LineTooltipItem(
                  '$label: ${barSpot.y.toStringAsFixed(2)}',
                  GoogleFonts.inter(
                    color: isOriginal ? accentColor : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
