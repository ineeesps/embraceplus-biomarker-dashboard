import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

// --- MOCK DATA CLASS ---
class ParticipantMockData {
  final String id;
  final double compliance;
  final String status; 
  final String dateRange;
  final int totalHours;

  ParticipantMockData(this.id)
      : compliance = _generateCompliance(id),
        status = _generateStatus(_generateCompliance(id)),
        dateRange = '12 Ene 2026 - 19 Ene 2026',
        totalHours = _generateHours(id);

  static double _generateCompliance(String id) {
    int hash = id.hashCode.abs();
    if (hash % 10 < 2) return 65.0 + (hash % 15); 
    if (hash % 10 < 5) return 80.0 + (hash % 10); 
    return 92.0 + (hash % 8); 
  }

  static String _generateStatus(double comp) {
    if (comp >= 90) return 'ÓPTIMO';
    if (comp >= 80) return 'REVISIÓN';
    return 'CRÍTICO';
  }

  static int _generateHours(String id) {
    return 120 + (id.hashCode.abs() % 48);
  }
}
// ----------------------

class ParticipantSelectionScreen extends StatefulWidget {
  final List<String> assignedParticipants;
  const ParticipantSelectionScreen({super.key, required this.assignedParticipants});

  @override
  State<ParticipantSelectionScreen> createState() => _ParticipantSelectionScreenState();
}

class _ParticipantSelectionScreenState extends State<ParticipantSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = true;

  late List<ParticipantMockData> _mockData;

  // Colors
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color bgColor = Color(0xFFF1F5F9);
  
  @override
  void initState() {
    super.initState();
    _mockData = widget.assignedParticipants.map((id) => ParticipantMockData(id)).toList();
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
        builder: (context) => DashboardScreen(participantId: id.trim()),
      ),
    );
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // --- FILTRADO ---
  List<ParticipantMockData> get _filteredParticipants {
    if (_searchQuery.isEmpty) return _mockData;
    return _mockData
        .where((p) => p.id.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    int totalAlerts = _mockData.where((p) => p.compliance < 80).length;
    double avgCompliance = _mockData.isEmpty ? 0 : 
        _mockData.fold(0.0, (sum, p) => sum + p.compliance) / _mockData.length;

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
              'Investigador Activo',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KPIs
            Row(
              children: [
                Expanded(child: _buildKPICard('Total Participantes', '${_mockData.length}', Icons.people_outline, Colors.blue)),
                const SizedBox(width: 24),
                Expanded(child: _buildKPICard('Cumplimiento Medio', '${avgCompliance.toStringAsFixed(1)}%', Icons.check_circle_outline, Colors.green)),
                const SizedBox(width: 24),
                Expanded(child: _buildKPICard('Alertas Activas', '$totalAlerts', Icons.warning_amber_rounded, totalAlerts > 0 ? Colors.orange : Colors.grey)),
              ],
            ),
            const SizedBox(height: 32),

            // 2. BUSCADOR Y VISTAS
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
              ],
            ),
            const SizedBox(height: 24),

            // 3. MAIN CONTENT
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

  // --- OPTION A: GRID VIEW ---
  Widget _buildGridView() {
    return GridView.builder(
      itemCount: _filteredParticipants.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        mainAxisExtent: 220, // Altura fija de tarjeta
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
              const SizedBox(height: 16),
              _buildDataRow(Icons.date_range, data.dateRange),
              const SizedBox(height: 8),
              _buildDataRow(Icons.timer_outlined, '${data.totalHours} horas registradas'),
              const SizedBox(height: 8),
              _buildDataRow(Icons.data_usage, 'Calidad: ${data.compliance.toStringAsFixed(1)}%'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _navigateToDashboard(data.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('VER DASHBOARD', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- OPTION B: TABLE VIEW ---
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
                      DataColumn(label: Text('Calidad de Datos', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      if (!isMobile) ...[
                        DataColumn(label: Text('Horas', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                        DataColumn(label: Text('Fechas', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                      ],
                      const DataColumn(label: SizedBox.shrink()), // Sin el texto "Acción"
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                onPressed: () => _navigateToDashboard(data.id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F766E),
                                  side: const BorderSide(color: Color(0xFF0F766E)),
                                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('VER DASHBOARD', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ),
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

  // --- HELPERS ---
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
    if (status == 'ÓPTIMO') return _BadgeConfig(const Color(0xFFDCFCE7), const Color(0xFF166534)); // Green
    if (status == 'REVISIÓN') return _BadgeConfig(const Color(0xFFFEF9C3), const Color(0xFF854D0E)); // Yellow
    return _BadgeConfig(const Color(0xFFFEE2E2), const Color(0xFF991B1B)); // Red
  }
}

class _BadgeConfig {
  final Color bgColor;
  final Color textColor;
  _BadgeConfig(this.bgColor, this.textColor);
}
