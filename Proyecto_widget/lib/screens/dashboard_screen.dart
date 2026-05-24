import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/dashboard_provider.dart';
import '../models/biomarker.dart';
import '../widgets/sidebar_layout.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/app_toast.dart';
import '../utils/app_colors.dart';
import 'movimiento_screen.dart';
import 'cardiaco_screen.dart';
import 'estres_screen.dart';
import 'sueno_screen.dart';
import 'login_screen.dart';

const Color primaryBlue  = AppColors.textPrimary;
const Color accentTeal   = AppColors.cyberBlue;
const Color nudeColor    = AppColors.textSecondary;
const Color kBorderColor = AppColors.border;
const Color kBgScreen    = AppColors.bgScreen;
const Color _dsSurface   = AppColors.bgCard;

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

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas cerrar la sesión? Volverás a la pantalla de inicio.',
      confirmLabel: 'Cerrar Sesión',
      icon: LucideIcons.logOut,
    );
    if (confirmed && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showUploadNotAvailable() {
    AppToast.show(context, 'Para subir datos, ve a la pantalla de Inicio', type: ToastType.info);
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
            return MovimientoScreen(
              participantId: widget.participantId,
              username: widget.username,
            );
          case 2:
            return CardiacoScreen(
              participantId: widget.participantId,
              username: widget.username,
            );
          case 3:
            return EstresScreen(
              participantId: widget.participantId,
              username: widget.username,
            );
          case 4:
            return SuenoScreen(
              participantId: widget.participantId,
              username: widget.username,
            );
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
                    _buildIAStatusLabel(LucideIcons.move, 'Estado actual', provider.lastActivity, isMobile),
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
      constraints: BoxConstraints(maxWidth: isMobile ? 140 : 220),
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
    final bool isCritical = pct < 70;
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
                        fontSize: isMobile ? 30 : 44,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'TASA DE USO',
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
                  'ALERTA: Tasa de uso crítica',
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
      crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
      mainAxisSpacing: isMobile ? 12 : 20,
      crossAxisSpacing: isMobile ? 12 : 20,
      childAspectRatio: isMobile ? 0.95 : (isTablet ? 1.1 : 1.0),
      children: [
        _buildKPICard('Pasos Totales', provider.totalSteps?.toString() ?? '--', LucideIcons.footprints, Colors.orange, isMobile),
        _buildKPICard('FC Media Global', provider.avgBpm != null ? '${provider.avgBpm} BPM' : '--', LucideIcons.heartPulse, const Color(0xFFE11D48), isMobile),
        _buildKPICard('Horas de Sueño', provider.sleepHours == null ? '--' : provider.sleepHours! == 0.0 ? '0h' : '${provider.sleepHours!.toStringAsFixed(1)}h', LucideIcons.moon, const Color(0xFF6366F1), isMobile),
        _buildKPICard('Nivel de Estrés', provider.avgStress?.toStringAsFixed(2) ?? '--', LucideIcons.zap, const Color(0xFF10B981), isMobile),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmallCard = constraints.maxHeight < 140;
        return Container(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 16 : (isSmallCard ? 12 : 24), 
            horizontal: 8
          ),
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
          SizedBox(height: isMobile ? 12 : (isSmallCard ? 8 : 20)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: primaryBlue),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.inter(fontSize: isMobile ? 9 : 11, color: nudeColor, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
          );
        },
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





  Color _getComplianceColor(double pct) {
    if (pct >= 90) return const Color(0xFF10B981);
    if (pct >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class BiomarkerCard extends StatelessWidget {
  final String sensorType;
  final List<Biomarker> data;
  final DashboardProvider provider;

  const BiomarkerCard({super.key, required this.sensorType, required this.data, required this.provider});

  @override
  Widget build(BuildContext context) {
    final sensorColor = _sensorColor(sensorType);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _dsSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sensorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_sensorIcon(sensorType), size: 22, color: sensorColor),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSensorTitle(sensorType),
                        style: GoogleFonts.outfit(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _sensorSubtitle(sensorType),
                        style: GoogleFonts.inter(color: nudeColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _buildStatusTag(data.first.qualityFlag),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.any((b) => b.value != null)) _buildStatsTable(context, data, sensorColor),
                if (data.any((b) => b.value != null)) const SizedBox(height: 24),
                if (data.any((b) => b.value != null))
                  SizedBox(
                    height: 250,
                    child: LineChart(_buildChartData(context, data)),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'Sin valores para mostrar debido a baja calidad de señal',
                        style: GoogleFonts.inter(color: nudeColor),
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

  Widget _buildStatsTable(BuildContext context, List<Biomarker> data, Color sensorColor) {
    final validValues = data.where((e) => e.value != null).map((e) => e.value!).toList();
    if (validValues.isEmpty) return const SizedBox();

    double mean = validValues.reduce((a, b) => a + b) / validValues.length;
    double min = validValues.reduce((a, b) => a < b ? a : b);
    double max = validValues.reduce((a, b) => a > b ? a : b);
    double variance = validValues.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / validValues.length;
    double sd = math.sqrt(variance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgScreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'MEDIA', value: mean.toStringAsFixed(2), color: sensorColor),
          _StatItem(label: 'SD', value: sd.toStringAsFixed(2), color: nudeColor),
          _StatItem(label: 'MIN', value: min.toStringAsFixed(2), color: nudeColor),
          _StatItem(label: 'MAX', value: max.toStringAsFixed(2), color: nudeColor),
        ],
      ),
    );
  }

  String _formatSensorTitle(String sensorType) {
    const titles = {
      'pulse_rate': 'Frecuencia Cardíaca',
      'respiratory_rate': 'Tasa Respiratoria',
      'prv': 'Variabilidad Cardíaca (PRV)',
      'eda': 'Actividad Electrodérmica',
      'temperature': 'Temperatura Cutánea',
      'sleep_detection': 'Detección de Sueño',
      'activity_class': 'Clasificación de Actividad',
      'activity_intensity': 'Intensidad de Actividad',
      'accelerometer_std': 'Acelerómetro (STD)',
      'acticounts_total': 'Acticounts (Total)',
    };
    return titles[sensorType] ?? sensorType.replaceAll('_', ' ').toUpperCase();
  }

  String _sensorSubtitle(String sensorType) {
    const subtitles = {
      'pulse_rate': 'lpm · Señal fotopletismográfica',
      'respiratory_rate': 'rpm · Estimación acelerométrica',
      'prv': 'ms · Intervalo R-R',
      'eda': 'µS · Respuesta galvánica de la piel',
      'temperature': '°C · Sensor cutáneo periférico',
      'sleep_detection': 'Estadios de sueño y vigilia',
      'activity_class': 'Categorías de movimiento',
      'activity_intensity': 'Equivalentes metabólicos',
      'accelerometer_std': 'Dispersión de la señal inercial',
      'acticounts_total': 'Magnitud vectorial de actividad',
    };
    return subtitles[sensorType] ?? 'Sensor biomecánico';
  }

  IconData _sensorIcon(String sensorType) {
    switch (sensorType) {
      case 'pulse_rate':         return LucideIcons.heartPulse;
      case 'prv':                return LucideIcons.activity;
      case 'respiratory_rate':   return LucideIcons.wind;
      case 'eda':                return LucideIcons.zap;
      case 'temperature':        return LucideIcons.thermometer;
      case 'sleep_detection':    return LucideIcons.moon;
      case 'activity_class':     return LucideIcons.personStanding;
      case 'activity_intensity': return LucideIcons.gauge;
      default:                   return LucideIcons.barChart2;
    }
  }

  Widget _buildStatusTag(String flag) {
    Color color = const Color(0xFF34D399);
    String label = 'NORMAL';
    if (flag == 'worn_during_motion') { color = const Color(0xFFFBBF24); label = 'MOVIMIENTO'; }
    else if (flag == 'worn_with_low_signal_quality' || flag == 'low_signal_quality') { color = const Color(0xFFFB7185); label = 'SEÑAL BAJA'; }
    else if (flag == 'device_not_recording') { color = nudeColor; label = 'GAP'; }
    else if (flag == 'device_not_worn_correctly') { color = nudeColor; label = 'NO PUESTO'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Color _sensorColor(String sensorType) {
    switch (sensorType) {
      case 'pulse_rate':         return AppColors.sensorHeart;
      case 'prv':                return AppColors.sensorPRV;
      case 'respiratory_rate':   return AppColors.sensorBreath;
      case 'eda':                return AppColors.sensorEDA;
      case 'temperature':        return AppColors.sensorTemp;
      case 'sleep_detection':    return AppColors.sensorSleep;
      case 'activity_class':
      case 'activity_intensity': return AppColors.sensorMove;
      case 'accelerometer_std':
      case 'acticounts_total':   return AppColors.cyberBlue;
      default:                   return accentTeal;
    }
  }

  LineChartData _buildChartData(BuildContext context, List<Biomarker> data) {
    final List<LineChartBarData> bars = [];
    
    List<List<FlSpot>> segments = [];
    List<String> segmentQualities = [];
    
    if (data.isNotEmpty) {
      List<FlSpot> currentSegment = [];
      String currentQuality = data[0].qualityFlag;
      DateTime? lastTime = data[0].time;
      const int splitThresholdMs = 5 * 60 * 1000;

      for (int i = 0; i < data.length; i++) {
        final currentDT = data[i].time;
        double xVal = currentDT.toUtc().millisecondsSinceEpoch.toDouble();
        
        bool timeGap = lastTime != null && (currentDT.difference(lastTime).inMilliseconds).abs() > splitThresholdMs;
        bool qualityChange = data[i].qualityFlag != currentQuality;

        if (qualityChange || timeGap) {
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            segmentQualities.add(currentQuality);
          }
          currentSegment = [];
          currentQuality = data[i].qualityFlag;
        }

        if (data[i].value != null) {
          currentSegment.add(FlSpot(xVal, data[i].value!));
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

    bool isCategorical = ['activity_class', 'body_position', 'activity_intensity', 'sleep_detection'].contains(sensorType);
    final allValues = data.where((e) => e.value != null).map((e) => e.value!);
    double minY = allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    double maxY = allValues.isEmpty ? 100.0 : allValues.reduce((a, b) => a > b ? a : b);
    double padding = (maxY - minY) * 0.15;
    if (padding == 0) padding = 1.0;
    minY = (minY - padding).clamp(0.0, double.infinity);
    maxY = maxY + padding;
    double yInterval = (maxY - minY) / 5;
    if (yInterval <= 0) yInterval = 1.0;

    double minX = data.isNotEmpty ? data.first.time.toUtc().millisecondsSinceEpoch.toDouble() : 0.0;
    double maxX = data.isNotEmpty ? data.last.time.toUtc().millisecondsSinceEpoch.toDouble() : 0.0;
    
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
        getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
        getDrawingVerticalLine: (v) => FlLine(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6), strokeWidth: 1),
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
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
              final format = (maxX - minX) > 86400000 ? 'dd/MM HH:mm' : 'HH:mm';
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(DateFormat(format).format(dt), style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 10))
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
                return SideTitleWidget(axisSide: meta.axisSide, space: 10, child: Text(text, style: GoogleFonts.inter(color: nudeColor, fontSize: 8)));
              }
              return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: Text(v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0), style: GoogleFonts.inter(color: nudeColor, fontSize: 10, fontWeight: FontWeight.bold)));
            }
          )
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: bars,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          tooltipBorder: BorderSide(color: kBorderColor),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                spot.y.toStringAsFixed(2),
                GoogleFonts.inter(color: primaryBlue, fontWeight: FontWeight.bold),
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
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? accentTeal;
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
