import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../providers/dashboard_provider.dart';
import '../models/biomarker.dart';
import '../widgets/quality_legend.dart';
import '../widgets/sidebar_layout.dart';
import 'login_screen.dart';

// Constantes de color para la vista clara unificada
const Color primaryBlue = Color(0xFF0F172A);
const Color bgColor = Color(0xFFF1F5F9);
const Color accentTeal = Color(0xFF0F766E);
const Color nudeColor = Color(0xFF6B728E);

class DashboardScreen extends StatefulWidget {
  final String participantId;
  final String username;
  const DashboardScreen({super.key, required this.participantId, required this.username});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchMetrics(widget.participantId, widget.username);
    });
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showUploadNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Para subir datos, vuelve a la pantalla de Inicio (Home)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SidebarLayout(
      username: widget.username,
      participantId: widget.participantId,
      selectedIndex: _selectedIndex,
      onItemSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      onUpload: _showUploadNotAvailable,
      onLogout: _logout,
      onHome: () => Navigator.pop(context),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
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

        switch (_selectedIndex) {
          case 0:
            return _buildInicio(provider);
          case 1:
            return _buildSensorSection(provider, ['accelerometer_std', 'acticounts_total', 'step_count', 'body_position']);
          case 2:
            return _buildSensorSection(provider, ['pulse_rate', 'respiratory_rate', 'prv']);
          case 3:
            return _buildSensorSection(provider, ['eda', 'temperature']);
          case 4:
            return _buildSensorSection(provider, ['sleep_detection', 'activity_class', 'activity_intensity']);
          default:
            return _buildInicio(provider);
        }
      },
    );
  }

  Widget _buildInicio(DashboardProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTopBar(context, provider),
          if (provider.metricsBySensor.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: _buildEmptyState(context, provider),
            ),
        ],
      ),
    );
  }

  Widget _buildSensorSection(DashboardProvider provider, List<String> allowedSensors) {
    final filteredMetrics = Map.fromEntries(
      provider.metricsBySensor.entries.where((e) => allowedSensors.contains(e.key))
    );

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              indicatorColor: accentTeal,
              indicatorWeight: 3,
              labelColor: accentTeal,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monitor_heart_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Monitorización Clínica'),
                    ],
                  ),
                ),
                Tab(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.science_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Análisis y Exportación'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                filteredMetrics.isEmpty
                    ? Center(
                        child: Text(
                          'No hay datos para esta sección.',
                          style: GoogleFonts.inter(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        children: [
                          const QualityLegend(),
                          const SizedBox(height: 16),
                          ...filteredMetrics.entries.map((entry) {
                            return BiomarkerCard(
                              sensorType: entry.key,
                              data: entry.value,
                              provider: provider,
                            );
                          }),
                        ],
                      ),
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(Icons.construction_rounded, size: 64, color: accentTeal.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('Sección de Análisis en construcción', style: GoogleFonts.inter(color: primaryBlue, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Exportar Datos Crudos'),
                          onPressed: () => _exportData(context),
                        ),
                        const SizedBox(height: 40),
                      ],
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

  Widget _buildEmptyState(BuildContext context, DashboardProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: primaryBlue.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('Sin datos en este rango', style: GoogleFonts.inter(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => provider.setTimeRange(null, null, widget.participantId, widget.username),
            label: Text('Ver sesión completa', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, DashboardProvider provider) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('CONTROL TEMPORAL'),
          const SizedBox(height: 12),
          _buildTimeRangeSelector(context, provider),
          const SizedBox(height: 32),
          _buildSectionHeader('CUMPLIMIENTO CLÍNICO'),
          const SizedBox(height: 12),
          _buildComplianceBar(context, provider),
          const SizedBox(height: 32),
          _buildSectionHeader('INDICADORES GLOBALES'),
          const SizedBox(height: 12),
          _buildGlobalKPIs(context, provider),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAppBarBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accentTeal,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Color _getComplianceColor(double pct) {
    if (pct >= 85) return accentTeal;
    if (pct >= 70) return const Color(0xFF854D0E);
    if (pct >= 50) return const Color(0xFF92400E);
    return const Color(0xFF991B1B);
  }

  Widget _buildComplianceBar(BuildContext context, DashboardProvider provider) {
    final pct = provider.compliancePercentage;
    if (pct == null) return const SizedBox();

    final color = _getComplianceColor(pct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Calidad de Uso (Compliance)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            Text('${pct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalKPIs(BuildContext context, DashboardProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 600;
        final bool isMedium = constraints.maxWidth < 1000;
        
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isSmall ? 1 : (isMedium ? 2 : 4),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 100,
          ),
          children: [
            _buildKPICard('Pasos Totales', provider.totalSteps?.toString() ?? '--', Icons.directions_walk, nudeColor),
            _buildKPICard('BPM Medio', provider.avgBpm?.toString() ?? '--', Icons.favorite, nudeColor),
            _buildKPICard('Gasto Energético/METs', provider.totalMets?.toStringAsFixed(1) ?? '--', Icons.local_fire_department, nudeColor),
            _buildKPICard('Temperatura Media', provider.avgTemp != null ? '${provider.avgTemp!.toStringAsFixed(1)}°' : '--', Icons.thermostat, nudeColor),
          ],
        );
      },
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: 22, color: primaryBlue, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(BuildContext context, DashboardProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 650;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: isSmall 
            ? Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: primaryBlue, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        provider.startHour == null && provider.sessionDate == null ? 'Todo el periodo' : 'Rango filtrado',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryBlue, fontSize: 13),
                      ),
                      const Spacer(),
                      if (provider.startHour != null || provider.sessionDate != null)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                          onPressed: () {
                            provider.setDateRange(null, null, widget.participantId, widget.username);
                            provider.setTimeRange(null, null, widget.participantId, widget.username);
                          },
                        ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDateButton(context, provider),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStartTimeButton(context, provider)),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(color: Colors.black26))),
                      Expanded(child: _buildEndTimeButton(context, provider)),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.tune_rounded, color: primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    provider.startHour == null && provider.sessionDate == null ? 'Todo el periodo' : 'Rango filtrado',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryBlue, fontSize: 13),
                  ),
                  const Spacer(),
                  _buildDateButton(context, provider),
                  const SizedBox(width: 10),
                  _buildStartTimeButton(context, provider),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('-', style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold))),
                  _buildEndTimeButton(context, provider),
                  if (provider.startHour != null || provider.endHour != null || provider.sessionDate != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                        tooltip: 'Resetear filtros',
                        onPressed: () {
                          provider.setDateRange(null, null, widget.participantId, widget.username);
                          provider.setTimeRange(null, null, widget.participantId, widget.username);
                        },
                      ),
                    ),
                ],
              ),
        );
      }
    );
  }

  Widget _buildDateButton(BuildContext context, DashboardProvider provider) {
    return _TimeButton(
      icon: Icons.calendar_today_rounded,
      label: provider.sessionDate != null 
          ? (provider.endDate != null 
              ? '${DateFormat('dd/MM').format(provider.sessionDate!)} - ${DateFormat('dd/MM').format(provider.endDate!)}' 
              : DateFormat('dd/MM/yyyy').format(provider.sessionDate!)) 
          : 'Fecha',
      onTap: () async {
        final range = await showDateRangePicker(
          context: context, 
          firstDate: DateTime(2020), 
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: provider.sessionDate != null 
              ? DateTimeRange(start: provider.sessionDate!, end: provider.endDate ?? provider.sessionDate!) 
              : null,
          helpText: 'Seleccionar rango de fechas',
          confirmText: 'Aceptar',
          saveText: 'Guardar',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: primaryBlue,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: primaryBlue,
                ),
              ),
              child: child!,
            );
          },
        );
        if (range != null) {
          provider.setDateRange(range.start, range.end, widget.participantId, widget.username);
        }
      },
    );
  }

  Widget _buildStartTimeButton(BuildContext context, DashboardProvider provider) {
    return _TimeButton(
      label: provider.startHour?.format(context) ?? 'Hora Inicio',
      onTap: () async {
        final time = await showTimePicker(
          context: context, 
          initialTime: provider.startHour ?? const TimeOfDay(hour: 0, minute: 0),
          helpText: 'Seleccionar hora de inicio',
          confirmText: 'Aceptar',
          cancelText: 'Cancelar',
          hourLabelText: 'Hora',
          minuteLabelText: 'Minuto',
        );
        if (time != null) provider.setTimeRange(time, provider.endHour, widget.participantId, widget.username);
      },
    );
  }

  Widget _buildEndTimeButton(BuildContext context, DashboardProvider provider) {
    return _TimeButton(
      label: provider.endHour?.format(context) ?? 'Hora Fin',
      onTap: () async {
        final time = await showTimePicker(
          context: context, 
          initialTime: provider.endHour ?? const TimeOfDay(hour: 23, minute: 59),
          helpText: 'Seleccionar hora de fin',
          confirmText: 'Aceptar',
          cancelText: 'Cancelar',
          hourLabelText: 'Hora',
          minuteLabelText: 'Minuto',
        );
        if (time != null) provider.setTimeRange(provider.startHour, time, widget.participantId, widget.username);
      },
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
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
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
                        style: GoogleFonts.inter(color: primaryBlue, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildStatusTag(data.first.qualityFlag),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.any((b) => b.value != null)) _buildStatsTable(context, data),
            if (data.any((b) => b.value != null)) const SizedBox(height: 24),
            if (data.any((b) => b.value != null))
              SizedBox(
                height: 250,
                child: LineChart(_buildChartData(context, data)),
              )
            else 
               SizedBox(
                 height: 100, 
                 child: Center(child: Text("Sin valores representables (Gaps de calidad)", style: GoogleFonts.inter(color: Colors.grey.shade500)))
               ),
          ],
        ),
      ),
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
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
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

  LineChartData _buildChartData(BuildContext context, List<Biomarker> data) {
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
      Color color = accentTeal; 
      bool isProblematic = false;
      if (quality == 'worn_during_motion') { color = const Color(0xFFF59E0B); isProblematic = true; }
      else if (quality == 'worn_with_low_signal_quality') { color = const Color(0xFFEF4444); isProblematic = true; }
      else if (quality == 'device_not_recording') { color = const Color(0xFF94A3B8).withOpacity(0.6); }
      else if (quality == 'device_not_worn_correctly') { color = const Color(0xFF94A3B8).withOpacity(0.4); }

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
            colors: [color.withOpacity(isProblematic ? 0.2 : 0.1), color.withOpacity(0.0)],
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
          color: const Color(0xFF94A3B8).withOpacity(0.4),
          barWidth: 1.5,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ));
      }
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
    
    if (provider.endHour != null) {
      final targetDate = provider.endDate ?? provider.sessionDate;
      if (targetDate != null) {
        final endDT = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, provider.endHour!.hour, provider.endHour!.minute);
        maxX = endDT.millisecondsSinceEpoch.toDouble();
      }
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
        getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        getDrawingVerticalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
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
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 10))
              );
            }
          )
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            reservedSize: isCategorical ? 65 : 45,
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
                return SideTitleWidget(axisSide: meta.axisSide, space: 10, child: Text(text, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 8)));
              }
              return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: Text(v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0), style: GoogleFonts.inter(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)));
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => primaryBlue,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                spot.y.toStringAsFixed(2),
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
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
        Text(label, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(color: primaryBlue, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const _TimeButton({required this.label, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primaryBlue.withOpacity(0.05),
          border: Border.all(color: primaryBlue.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: primaryBlue),
              const SizedBox(width: 6),
            ],
            Text(label, style: GoogleFonts.inter(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
