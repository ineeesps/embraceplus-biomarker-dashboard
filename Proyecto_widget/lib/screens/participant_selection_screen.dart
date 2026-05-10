import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
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

  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color bgColor = Color(0xFFF1F5F9);
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

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

  void _navigateToDashboard(String id) {
    if (id.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(participantId: id.trim(), username: widget.username),
      ),
    );
  }

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
                                  List<int> bytes = file.bytes ?? [];
                                  if (bytes.isEmpty && file.path != null) {
                                    bytes = await File(file.path!).readAsBytes();
                                  }
                                  
                                  if (bytes.isNotEmpty) {
                                    await api.uploadCsv(pId, widget.username, bytes, file.name);
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
              title: const Text('Subir más datos (CSV)'),
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: primaryBlue, size: 28),
            const SizedBox(width: 12),
            Text(
              'EmbracePlus',
              style: GoogleFonts.inter(
                color: primaryBlue,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'RESEARCH',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F766E),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Text(
              'Investigador: ${widget.username}',
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.logout, color: primaryBlue),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : _errorMessage != null
                ? Center(child: Text('Error: $_errorMessage', style: GoogleFonts.inter(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Row(
              children: [
                Expanded(child: _buildKPICard('Total Participantes', '${_realData.length}', Icons.people_outline, Colors.blue)),
                const SizedBox(width: 24),
                Expanded(child: _buildKPICard('Cumplimiento Medio', '${avgCompliance.toStringAsFixed(1)}%', Icons.check_circle_outline, Colors.green)),
                const SizedBox(width: 24),
                Expanded(child: _buildKPICard('Alertas Activas', '$totalAlerts', Icons.warning_amber_rounded, totalAlerts > 0 ? Colors.orange : Colors.grey)),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar por ID de participante...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
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
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton(Icons.grid_view_rounded, true),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      _buildToggleButton(Icons.table_rows_rounded, false),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: _showUploadModal,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text('Subir Participante', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E), 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: _filteredParticipants.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron participantes',
                        style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    )
                  : _isGridView
                      ? _buildGridView()
                      : _buildTableView(),
            ),
                   ],
                ),
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
          color: isSelected ? primaryBlue : Colors.grey.shade400,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, MaterialColor color) {
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
            decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color.shade600, size: 28),
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

  Widget _buildGridView() {
    return GridView.builder(
      itemCount: _filteredParticipants.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
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
                      icon: const Icon(Icons.analytics_outlined, color: Color(0xFF0F766E), size: 22),
                      onPressed: () => _navigateToDashboard(data.id),
                      tooltip: 'Ver Dashboard',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 22),
                      onPressed: () => _showEditOptions(data.id),
                      tooltip: 'Editar/Subir',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
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
                                  icon: const Icon(Icons.analytics_outlined, color: Color(0xFF0F766E), size: 20),
                                  onPressed: () => _navigateToDashboard(data.id),
                                  tooltip: 'Ver Dashboard',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
                                  onPressed: () => _showEditOptions(data.id),
                                  tooltip: 'Editar/Subir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  _BadgeConfig _getBadgeConfig(String status) {
    if (status == 'ÓPTIMO') return _BadgeConfig(const Color(0xFFDCFCE7), const Color(0xFF166534));
    if (status == 'REVISIÓN') return _BadgeConfig(const Color(0xFFFEF9C3), const Color(0xFF854D0E));
    return _BadgeConfig(const Color(0xFFFEE2E2), const Color(0xFF991B1B));
  }
}

class _BadgeConfig {
  final Color bgColor;
  final Color textColor;
  _BadgeConfig(this.bgColor, this.textColor);
}
