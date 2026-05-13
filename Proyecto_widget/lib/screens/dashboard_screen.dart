import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/dashboard_provider.dart';
import '../models/biomarker.dart';
import '../widgets/quality_legend.dart';
import '../widgets/sidebar_layout.dart';
import 'login_screen.dart';

const Color primaryBlue  = Color(0xFF0F172A);
const Color bgColor      = Color(0xFFF8FAFC);
const Color accentTeal   = Color(0xFF0EA5E9);
const Color nudeColor    = Color(0xFF64748B);
const Color kBorderColor = Color(0xFFE2E8F0);

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
                const Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 48),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isMobile = width < 600;
        final bool isTablet = width < 1000 && width >= 600;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32, 
            vertical: isMobile ? 20 : 40
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (provider.metrics.isEmpty)
                _buildEmptyState(context, provider)
              else ...[
                Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildIAStatusLabel(LucideIcons.personStanding, 'Estado actual', provider.lastActivity, isMobile),
                    _buildIAStatusLabel(LucideIcons.moon, 'Última posición', provider.lastPosition, isMobile),
                  ],
                ),
                SizedBox(height: isMobile ? 30 : 50),
                _buildComplianceDonut(provider, isMobile),
                SizedBox(height: isMobile ? 30 : 50),
                _buildDailyKPIsGrid(provider, isMobile, isTablet),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildIAStatusLabel(IconData icon, String title, String value, bool isMobile) {
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? 160 : 220),
      padding: const EdgeInsets.fromLTRB(6, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: accentTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: isMobile ? 20 : 24, color: primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: isMobile ? 9 : 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: isMobile ? 12 : 14, color: primaryBlue, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceDonut(DashboardProvider provider, bool isMobile) {
    final double pct = provider.compliancePercentage ?? 0;
    final Color color = _getComplianceColor(pct);
    final bool isCritical = pct < 50;
    final double size = isMobile ? 220 : 300;

    return Column(
      children: [
        SizedBox(
          height: size,
          width: size,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: isMobile ? 70 : 100,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      color: color,
                      value: pct,
                      radius: isMobile ? 20 : 25,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      color: color.withValues(alpha: 0.1),
                      value: 100 - pct,
                      radius: isMobile ? 20 : 25,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 40 : 56,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'CUMPLIMIENTO',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 8 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (isCritical)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Text(
                  'ALERTA: Cumplimiento crítico',
                  style: GoogleFonts.inter(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDailyKPIsGrid(DashboardProvider provider, bool isMobile, bool isTablet) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      mainAxisSpacing: isMobile ? 12 : 20,
      crossAxisSpacing: isMobile ? 12 : 20,
      childAspectRatio: isMobile ? 0.95 : 1.0,
      children: [
        _buildKPICard('Pasos Totales', provider.totalSteps?.toString() ?? '--', LucideIcons.footprints, Colors.orange, isMobile),
        _buildKPICard('Frecuencia Cardíaca', provider.avgBpm?.toString() ?? '--', LucideIcons.heartPulse, const Color(0xFFE11D48), isMobile),
        _buildKPICard('Horas de Sueño', provider.sleepHours?.toStringAsFixed(1) ?? '--', LucideIcons.moon, const Color(0xFF6366F1), isMobile),
        _buildKPICard('Nivel de Estrés', provider.avgStress?.toStringAsFixed(2) ?? '--', LucideIcons.zap, const Color(0xFF10B981), isMobile),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 24, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isMobile ? 22 : 26),
          ),
          SizedBox(height: isMobile ? 12 : 20),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: primaryBlue),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: isMobile ? 9 : 11, color: nudeColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getComplianceColor(double pct) {
    if (pct >= 85) return const Color(0xFF10B981); // Verde esmeralda
    if (pct >= 60) return const Color(0xFFF59E0B); // Naranja ámbar
    return const Color(0xFFEF4444); // Rojo vibrante
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
              unselectedLabelColor: nudeColor,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.heartPulse, size: 18),
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
                      Icon(LucideIcons.flaskConical, size: 18),
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
                        Icon(LucideIcons.wrench, size: 64, color: accentTeal.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('Sección de Análisis en construcción', style: GoogleFonts.inter(color: primaryBlue, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(LucideIcons.download, size: 18),
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
          Icon(LucideIcons.barChart2, size: 80, color: primaryBlue.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(
            'Sin registros históricos',
            style: GoogleFonts.inter(fontSize: 18, color: primaryBlue, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No se han encontrado datos biométricos para este participante.',
            style: GoogleFonts.inter(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => provider.fetchMetrics(widget.participantId, widget.username),
            label: const Text('Reintentar carga de datos'),
          ),
        ],
      ),
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
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
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
        border: Border.all(color: kBorderColor),
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
    // El backend puede devolver 'low_signal_quality' o 'worn_with_low_signal_quality'
    else if (flag == 'worn_with_low_signal_quality' || flag == 'low_signal_quality') { color = const Color(0xFFEF4444); label = 'SEÑAL BAJA'; }
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

  Color _sensorColor(String sensorType) {
    switch (sensorType) {
      case 'pulse_rate':
      case 'prv':              return const Color(0xFFE11D48);
      case 'respiratory_rate': return const Color(0xFF06B6D4);
      case 'eda':              return const Color(0xFF10B981);
      case 'temperature':      return const Color(0xFFF59E0B);
      case 'sleep_detection':  return const Color(0xFF6366F1);
      case 'accelerometer_std':
      case 'acticounts_total':
      case 'step_count':
      case 'activity_class':
      case 'activity_intensity':
      case 'met':
      case 'activity_counts':
      case 'actigraphy_vector':
      case 'body_position':    return const Color(0xFF475569);
      default:                 return accentTeal;
    }
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
      Color color = _sensorColor(sensorType);
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

    final sType = sensorType;
    bool isCategorical = ['activity_class', 'body_position', 'activity_intensity', 'sleep_detection'].contains(sType);
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
              final format = (maxX - minX) > 86400000 ? 'dd/MM HH:mm' : 'HH:mm';
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat(format).format(dt), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 10))
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
                if (sType == 'activity_class') {
                  const labels = ['STILL', 'WALK', 'RUN', 'GENERIC'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                } else if (sType == 'body_position') {
                  const labels = ['SIT/LIE', 'STAND', 'LEFT', 'RIGHT', 'PRONE', 'SUPINE', 'MISC'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                } else if (sType == 'activity_intensity') {
                  const labels = ['SED', 'LPA', 'MPA', 'VPA'];
                  if (intValue >= 0 && intValue < labels.length) text = labels[intValue];
                } else if (sType == 'sleep_detection') {
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
