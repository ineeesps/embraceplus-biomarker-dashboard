import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../widgets/sidebar_layout.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ParticipantData {
  final String id;
  final double compliance;
  final String status; 
  final String dateRange;
  final int totalHours;

  ParticipantData({
    required this.id,
    required this.compliance,
    required this.status,
    required this.dateRange,
    required this.totalHours,
  });

  factory ParticipantData.fromJson(Map<String, dynamic> json) {
    return ParticipantData(
      id: json['id'],
      compliance: (json['compliance'] as num).toDouble(),
      status: json['status'],
      dateRange: json['dateRange'],
      totalHours: json['totalHours'],
    );
  }
}

class ParticipantSelectionScreen extends StatefulWidget {
  final String username;
  final List<String> assignedParticipants;
  const ParticipantSelectionScreen({super.key, required this.username, required this.assignedParticipants});

  @override
  State<ParticipantSelectionScreen> createState() => _ParticipantSelectionScreenState();
}

class _ParticipantSelectionScreenState extends State<ParticipantSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;
  bool _isLoading = true;
  String? _errorMessage;

  List<ParticipantData> _realData = [];

  // Configuración estética del dashboard (Clinical Research Theme)
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color accentTeal = Color(0xFF0F766E);
  static const Color nudeColor = Color(0xFF6B728E);
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Carga los datos de los participantes asignados al investigador actual
  Future<void> _loadData() async {
    try {
      final api = ApiService();
      final data = await api.getParticipantsSummary(widget.username);
      if (mounted) {
        setState(() {
          _realData = data.map((json) => ParticipantData.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Navega al dashboard de un participante específico
  void _navigateToDashboard(String id) {
    if (id.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(participantId: id.trim(), username: widget.username),
      ),
    );
  }

  /// Muestra el modal para la subida de archivos CSV de un participante
  void _showUploadModal({String? prefilledId}) {
    final TextEditingController idController = TextEditingController(text: prefilledId);
    bool isUploading = false;
    String statusMessage = '';
    String errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Subir Nuevos Datos', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: primaryBlue)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID del Participante:', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: idController,
                      enabled: !isUploading && prefilledId == null,
                      decoration: InputDecoration(
                        hintText: 'Ej: nuevo_participante_01',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isUploading) ...[
                      const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
                      const SizedBox(height: 16),
                      Center(child: Text(statusMessage, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center)),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pId = idController.text.trim();
                            if (pId.isEmpty) {
                              setModalState(() => errorMessage = 'Por favor, introduce un ID válido.');
                              return;
                            }
                            setModalState(() => errorMessage = '');

                            final result = await FilePicker.pickFiles(
                              allowMultiple: true,
                              type: FileType.custom,
                              allowedExtensions: ['csv'],
                            );

                            if (result != null && result.files.isNotEmpty) {
                              setModalState(() {
                                isUploading = true;
                                statusMessage = 'Preparando subida de ${result.files.length} archivos...';
                              });

                              final api = ApiService();
                              int successCount = 0;
                              int errorCount = 0;

                                for (int i = 0; i < result.files.length; i++) {
                                  final file = result.files[i];
                                  setModalState(() => statusMessage = 'Subiendo archivo ${i + 1} de ${result.files.length}...\n${file.name}');
                                  
                                  try {
                                    // Detectar tipo de sensor
                                    String? sensorType;
                                    final fileNameLower = file.name.toLowerCase();
                                    final patrones = {
                                      'temperature': 'temperature', 'eda': 'eda', 'pulse-rate': 'pulse_rate',
                                      'respiratory-rate': 'respiratory_rate', 'accelerometers-std': 'accelerometer_std',
                                      'prv': 'prv', 'step-counts': 'step_count', 'met': 'met',
                                      'activity-intensity': 'activity_intensity', 'wearing-detection': 'wearing_detection',
                                      'activity-classification': 'activity_class', 'activity-counts': 'activity_counts',
                                      'actigraphy-counts': 'actigraphy_vector', 'body-position': 'body_position',
                                      'acticounts': 'acticounts_total', 'sleep-detection': 'sleep_detection'
                                    };
                                    
                                    for (var entry in patrones.entries) {
                                      if (fileNameLower.contains(entry.key)) {
                                        sensorType = entry.value;
                                        break;
                                      }
                                    }

                                    bool shouldReplace = false;
                                    if (sensorType != null) {
                                      final exists = await api.checkSensorDataExists(pId, sensorType, widget.username);
                                      if (exists) {
                                        // Pausamos la subida para preguntar
                                        setModalState(() => isUploading = false);
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Archivo ya existente'),
                                            content: Text('Este archivo ya existe o el participante ya tiene datos de $sensorType. ¿Desea reemplazarlo o cancelamos?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('REEMPLAZAR', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (confirm != true) {
                                          setModalState(() {
                                            isUploading = true;
                                            statusMessage = 'Saltando ${file.name}...';
                                          });
                                          continue;
                                        }
                                        shouldReplace = true;
                                        setModalState(() {
                                          isUploading = true;
                                          statusMessage = 'Reemplazando datos de ${file.name}...';
                                        });
                                      }
                                    }

                                    List<int> bytes = file.bytes ?? [];
                                    if (bytes.isEmpty && file.path != null) {
                                      bytes = await File(file.path!).readAsBytes();
                                    }
                                    
                                    if (bytes.isNotEmpty) {
                                      await api.uploadCsv(pId, widget.username, bytes, file.name, replace: shouldReplace);
                                      successCount++;
                                    } else {
                                      errorCount++;
                                    }
                                  } catch (e) {
                                    errorCount++;
                                  }
                                }

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Subida completada: $successCount correctos, $errorCount errores.'),
                                    backgroundColor: errorCount == 0 ? Colors.green : Colors.orange,
                                  )
                                );
                                setState(() {
                                  _isLoading = true;
                                });
                                _loadData();
                              }
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: Text('Seleccionar CSVs', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(errorMessage, style: GoogleFonts.inter(color: Colors.red, fontSize: 13)),
                      ]
                    ]
                  ],
                ),
              ),
              actions: [
                if (!isUploading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                  ),
              ],
            );
          }
        );
      }
    );
  }
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Elimina un participante y todos sus datos asociados
  Future<void> _deleteParticipant(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Participante', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que quieres eliminar a $id? Esta acción borrará todos sus datos clínicos de forma permanente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService().deleteParticipant(id, widget.username);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participante eliminado correctamente')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// Muestra las opciones de edición (renombrar o subir más datos)
  void _showEditOptions(String id) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gestionar Participante: $id', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: primaryBlue),
              title: const Text('Renombrar Participante'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined, color: Color(0xFF0F766E)),
              title: const Text('Subir nuevos datos (CSV)'),
              onTap: () {
                Navigator.pop(context);
                _showUploadModal(prefilledId: id);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo para cambiar el identificador de un participante
  Future<void> _showRenameDialog(String oldId) async {
    final controller = TextEditingController(text: oldId);
    final newId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar Participante'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newId != null && newId.isNotEmpty && newId != oldId) {
      try {
        await ApiService().renameParticipant(oldId, newId, widget.username);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  List<ParticipantData> get _filteredParticipants {
    if (_searchQuery.isEmpty) return _realData;
    return _realData
        .where((p) => p.id.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    int totalAlerts = _realData.where((p) => p.compliance < 80).length;
    double avgCompliance = _realData.isEmpty ? 0 : 
        _realData.fold(0.0, (sum, p) => sum + p.compliance) / _realData.length;

    return SidebarLayout(
      username: widget.username,
      onItemSelected: (index) {},
      onUpload: _showUploadModal,
      onLogout: _logout,
      onHome: () {},
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmall = constraints.maxWidth < 700;
          final bool isMedium = constraints.maxWidth < 1100;

          return Padding(
            padding: EdgeInsets.all(isSmall ? 16.0 : 32.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : ListView(
                    children: [
                      // KPIs con disposición flexible
                      if (isSmall)
                        Column(
                          children: [
                            _buildKPICard('Total Participantes', '${_realData.length}', Icons.people_rounded, primaryBlue),
                            const SizedBox(height: 16),
                            _buildKPICard('Cumplimiento Medio', '${avgCompliance.toStringAsFixed(1)}%', Icons.verified_user_rounded, accentTeal),
                            const SizedBox(height: 16),
                            _buildKPICard('Alertas Activas', '$totalAlerts', Icons.error_outline_rounded, totalAlerts > 0 ? const Color(0xFF92400E) : nudeColor),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: _buildKPICard('Total Participantes', '${_realData.length}', Icons.people_rounded, primaryBlue)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildKPICard('Cumplimiento Medio', '${avgCompliance.toStringAsFixed(1)}%', Icons.verified_user_rounded, accentTeal)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildKPICard('Alertas Activas', '$totalAlerts', Icons.error_outline_rounded, totalAlerts > 0 ? const Color(0xFF92400E) : nudeColor)),
                          ],
                        ),
                      const SizedBox(height: 32),

                      // Barra de búsqueda y botones responsive
                      if (isSmall)
                        Column(
                          children: [
                            _buildSearchField(),
                            const SizedBox(height: 16),
                            _buildViewToggles(),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: _buildSearchField()),
                            const SizedBox(width: 24),
                            _buildViewToggles(),
                          ],
                        ),
                      const SizedBox(height: 24),

                      _filteredParticipants.isEmpty
                          ? SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'No se encontraron participantes',
                                  style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16),
                                ),
                              ),
                            )
                          : _isGridView
                              ? _buildGridView(isSmall ? 1 : (isMedium ? 2 : 3))
                              : _buildTableView(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildToggleButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;
    return InkWell(
      onTap: () => setState(() => _isGridView = isGrid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isGrid ? const Radius.circular(8) : Radius.zero,
            right: !isGrid ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? primaryBlue : nudeColor.withOpacity(0.4),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: GoogleFonts.inter(color: primaryBlue, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar por ID de participante...',
        hintStyle: GoogleFonts.inter(color: nudeColor.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.search, color: nudeColor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue),
        ),
      ),
    );
  }

  Widget _buildViewToggles() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(Icons.grid_view_rounded, true),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildToggleButton(Icons.table_rows_rounded, false),
        ],
      ),
    );
  }

  Widget _buildGridView(int crossAxisCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredParticipants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        mainAxisExtent: 220,
      ),
      itemBuilder: (context, index) {
        final data = _filteredParticipants[index];
        final badgeConfig = _getBadgeConfig(data.status);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
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
                    child: Text(
                      data.id,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeConfig.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data.status,
                      style: GoogleFonts.inter(color: badgeConfig.textColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              _buildDataRow(Icons.date_range, data.dateRange),
              const SizedBox(height: 4),
              _buildDataRow(Icons.timer_outlined, '${data.totalHours} horas registradas'),
              const SizedBox(height: 4),
              _buildDataRow(Icons.data_usage, 'Calidad: ${data.compliance.toStringAsFixed(1)}%'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined, color: accentTeal, size: 20),
                      onPressed: () => _navigateToDashboard(data.id),
                      tooltip: 'Ver Dashboard',
                    ),
                    IconButton(
                      icon: const Icon(Icons.drive_file_rename_outline_rounded, color: nudeColor, size: 20),
                      onPressed: () => _showEditOptions(data.id),
                      tooltip: 'Editar/Subir',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF991B1B), size: 20),
                      onPressed: () => _deleteParticipant(data.id),
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 700;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade50),
                    columnSpacing: isMobile ? 10 : 24, 
                    horizontalMargin: 24,
                    headingRowHeight: 64,
                    dataRowMinHeight: 72,
                    dataRowMaxHeight: 72,
                    columns: [
                      DataColumn(label: Text('ID Participante', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      DataColumn(label: Text('Calidad', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      if (!isMobile) ...[
                        DataColumn(label: Text('Horas', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                        DataColumn(label: Text('Fechas', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      ],
                      const DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _filteredParticipants.map((data) {
                      final badgeConfig = _getBadgeConfig(data.status);
                      return DataRow(
                        cells: [
                          DataCell(Text(data.id, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryBlue))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: isMobile ? 60 : 100,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: data.compliance / 100,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: AlwaysStoppedAnimation<Color>(badgeConfig.textColor),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('${data.compliance.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          if (!isMobile) ...[
                            DataCell(Text('${data.totalHours}h', style: GoogleFonts.inter(color: Colors.grey.shade700))),
                            DataCell(Text(data.dateRange, style: GoogleFonts.inter(color: Colors.grey.shade700))),
                          ],
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.analytics_outlined, color: accentTeal, size: 20),
                                  onPressed: () => _navigateToDashboard(data.id),
                                  tooltip: 'Ver Dashboard',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.drive_file_rename_outline_rounded, color: nudeColor, size: 20),
                                  onPressed: () => _showEditOptions(data.id),
                                  tooltip: 'Editar/Subir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF991B1B), size: 20),
                                  onPressed: () => _deleteParticipant(data.id),
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: nudeColor),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  _BadgeConfig _getBadgeConfig(String status) {
    if (status == 'ÓPTIMO') return _BadgeConfig(accentTeal.withOpacity(0.1), accentTeal);
    if (status == 'REVISIÓN') return _BadgeConfig(const Color(0xFFFEF3C7), const Color(0xFF92400E));
    return _BadgeConfig(const Color(0xFFFEE2E2), const Color(0xFF991B1B));
  }
}

class _BadgeConfig {
  final Color bgColor;
  final Color textColor;
  _BadgeConfig(this.bgColor, this.textColor);
}
