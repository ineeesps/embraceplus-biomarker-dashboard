import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_dialog.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String username;
  final ApiService? api;

  const AdminDashboardScreen({
    super.key,
    required this.username,
    this.api,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedTab = 0; // Default to Gestión de Investigadores (0)
  bool _isExpanded = false;
  
  // State for Researchers List
  List<Map<String, dynamic>> _investigators = [];
  bool _isLoadingInvestigators = false;
  String _searchQuery = '';
  
  // Available patients in the system
  List<String> _availablePatients = [];
  
  // API instance
  late final ApiService _api;

  // Color Palette
  static const Color kSystemBlue = Color(0xFF2563EB);
  static const Color kDangerRed = Color(0xFFEF4444);
  static const Color kBgScreen = AppColors.bgScreen;
  static const Color kBgCard = Colors.white;
  static const Color kBorder = AppColors.border;
  static const Color kTextPrimary = AppColors.textPrimary;
  static const Color kTextSecondary = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _fetchInvestigators();
    _fetchAvailablePatients();
  }

  Future<void> _fetchInvestigators() async {
    setState(() => _isLoadingInvestigators = true);
    try {
      final data = await _api.getAdminInvestigators();
      setState(() {
        _investigators = data;
        _isLoadingInvestigators = false;
      });
    } catch (e) {
      setState(() => _isLoadingInvestigators = false);
      if (mounted) {
        AppToast.show(context, 'Error al cargar investigadores: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _fetchAvailablePatients() async {
    try {
      final data = await _api.getAdminAllParticipants();
      setState(() {
        _availablePatients = data.isNotEmpty ? data : ['HN', 'PRUEBA 1', 'TEST_CRUD_USER'];
      });
    } catch (e) {
      setState(() {
        _availablePatients = ['HN', 'PRUEBA 1', 'TEST_CRUD_USER'];
      });
    }
  }

  Future<void> _toggleInvestigatorActive(int id, bool currentStatus) async {
    try {
      await _api.toggleInvestigatorStatus(id, !currentStatus);
      if (!mounted) return;
      AppToast.show(context, 'Estado del investigador actualizado con éxito', type: ToastType.success);
      _fetchInvestigators();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error al cambiar estado: $e', type: ToastType.error);
      }
    }
  }

  void _showNewInvestigatorDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final List<String> assignedPatients = [];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Alta de Investigador', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nombre Completo:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ej: Juan Pérez',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        Text('Nombre de Usuario:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: userCtrl,
                          decoration: InputDecoration(
                            hintText: 'Ej: juan_perez',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        Text('Contraseña Temporal:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: passwordCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Mínimo 4 caracteres',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                validator: (v) => v == null || v.trim().length < 4 ? 'Mínimo 4 caracteres' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(LucideIcons.dices, color: kSystemBlue),
                              onPressed: () {
                                const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%';
                                final rand = math.Random();
                                final pwd = List.generate(8, (i) => chars[rand.nextInt(chars.length)]).join();
                                setModalState(() {
                                  passwordCtrl.text = pwd;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Asignación Rápida de Participantes:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: _availablePatients.map((pId) {
                              final isChecked = assignedPatients.contains(pId);
                              return CheckboxListTile(
                                title: Text(pId, style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                                value: isChecked,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                dense: true,
                                onChanged: (v) {
                                  setModalState(() {
                                    if (v == true) {
                                      assignedPatients.add(pId);
                                    } else {
                                      assignedPatients.remove(pId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCELAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await _api.createAdminInvestigator({
                        'username': userCtrl.text.trim(),
                        'password': passwordCtrl.text,
                        'nombre_completo': nameCtrl.text.trim(),
                        'role': 'investigador',
                        'participantes_asignados': assignedPatients,
                      });
                      if (context.mounted) {
                        AppToast.show(context, 'Investigador creado correctamente', type: ToastType.success);
                        Navigator.pop(context);
                      }
                      _fetchInvestigators();
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.show(context, 'Error al crear investigador: $e', type: ToastType.error);
                      }
                    }
                  },
                  child: Text('CREAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kSystemBlue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onNewInvestigatorTap(bool isDrawer) {
    if (isDrawer) {
      Navigator.pop(context);
    }
    _showNewInvestigatorDialog();
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas cerrar la sesión? Volverás a la pantalla de inicio.',
      confirmLabel: 'Cerrar Sesión',
      confirmColor: kSystemBlue,
      icon: LucideIcons.logOut,
    );
    if (confirmed && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    return Scaffold(
      backgroundColor: kBgScreen,
      drawer: isMobile ? Drawer(child: _buildSidebarContent(isDrawer: true)) : null,
      appBar: isMobile
          ? AppBar(
              backgroundColor: AppColors.sidebarBg,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                'EmbracePlus Admin',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            MouseRegion(
              onEnter: (_) => setState(() => _isExpanded = true),
              onExit: (_) => setState(() => _isExpanded = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _isExpanded ? 260 : 72,
                color: AppColors.sidebarBg,
                child: _buildSidebarContent(isDrawer: false),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(isMobile),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildSelectedTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isMobile)
            Text(
              'Directorio de Investigadores y Accesos',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextPrimary,
              ),
            )
          else
            const SizedBox(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kSystemBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.shieldCheck, size: 14, color: kSystemBlue),
                    const SizedBox(width: 6),
                    Text(
                      'Admin activo',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kSystemBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SIDEBAR CONTENT ──────────────────────────────────────────────────────

  Widget _buildSidebarContent({required bool isDrawer}) {
    final bool isExpanded = isDrawer || _isExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kSystemBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.shield, color: kSystemBlue, size: 20),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    'PANEL ADMIN',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSidebarTile(0, LucideIcons.layoutTemplate, 'Panel General', isExpanded, isDrawer),
              _buildSidebarTile(2, LucideIcons.userPlus, 'Nuevo Investigador', isExpanded, isDrawer, onTap: () => _onNewInvestigatorTap(isDrawer)),
            ],
          ),
        ),

        const Divider(color: Color(0xFF334155), height: 1),
        _buildSidebarTile(-1, LucideIcons.logOut, 'Cerrar Sesión', isExpanded, isDrawer, onTap: _logout),
        
        Container(
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 24 : 20, vertical: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: kSystemBlue.withValues(alpha: 0.15),
                  child: Icon(LucideIcons.user, color: kSystemBlue, size: 14),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.username,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Administrador',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSidebarTile(int index, IconData icon, String title, bool isExpanded, bool isDrawer, {VoidCallback? onTap}) {
    final isSelected = _selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          setState(() => _selectedTab = index);
          if (isDrawer) {
            Navigator.pop(context);
          }
        },
        splashColor: kSystemBlue.withValues(alpha: 0.2),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 24 : 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? kSystemBlue : Colors.transparent,
                width: 3,
              ),
            ),
            color: isSelected ? AppColors.sidebarHover.withValues(alpha: 0.5) : Colors.transparent,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(
                    icon,
                    color: isSelected ? kSystemBlue : AppColors.textMuted,
                    size: 18,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ACTIVE CONTENT ROUTER ────────────────────────────────────────────────

  Widget _buildSelectedTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildInvestigatorsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary)),
              const SizedBox(height: 6),
              Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.bold, color: kTextPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  // ── INVESTIGATORS TAB ────────────────────────────────────────────────────

  Widget _buildInvestigatorsTab() {
    final filtered = _investigators.where((i) {
      final match = i['username'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          i['nombre_completo'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return match;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Investigadores Activos', '${_investigators.where((i) => i['is_active'] == true && i['role'] == 'investigador').length}', LucideIcons.users, kSystemBlue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Total Participantes', '${_availablePatients.length}', LucideIcons.database, Colors.teal)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Investigadores Inactivos', '${_investigators.where((i) => i['is_active'] == false && i['role'] == 'investigador').length}', LucideIcons.userX, Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: kTextSecondary),
                    hintText: 'Buscar investigadores por nombre o usuario...',
                    hintStyle: GoogleFonts.inter(color: kTextSecondary.withValues(alpha: 0.5), fontSize: 13),
                    fillColor: Colors.white,
                    filled: true,
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
                      borderSide: const BorderSide(color: kSystemBlue),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingInvestigators
                ? const Center(child: CircularProgressIndicator(color: kSystemBlue))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildSaaSTable(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.users, size: 48, color: kTextSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No hay investigadores registrados en el sistema. Comienza aprovisionando una nueva cuenta.',
            style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSaaSTable(List<Map<String, dynamic>> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Investigador', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: kTextSecondary))),
                Expanded(flex: 2, child: Text('Estado', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: kTextSecondary))),
                Expanded(flex: 2, child: Text('Participantes Asignados', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: kTextSecondary))),
                Expanded(flex: 2, child: Text('Último Acceso', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: kTextSecondary))),
                Container(width: 60, alignment: Alignment.center, child: Text('Acciones', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: kTextSecondary))),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final r = list[index];
                final name = r['nombre_completo'] ?? r['username'];
                final username = '@${r['username']}';
                final isActive = r['is_active'] ?? true;
                final lastAccess = r['last_login'] != null
                    ? _formatLastAccess(r['last_login'])
                    : 'Nunca';
                
                final assignedCount = r['pacientes_count'] ?? 0;
                
                // Get initials
                final words = name.split(' ');
                final initials = words.length > 1
                    ? '${words[0][0]}${words[1][0]}'.toUpperCase()
                    : '${words[0][0]}${words[0][1]}'.toUpperCase();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  child: Row(
                    children: [
                      // Name & Avatar
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: kSystemBlue.withValues(alpha: 0.1),
                              child: Text(
                                initials,
                                style: GoogleFonts.outfit(color: kSystemBlue, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextPrimary, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(username, style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive ? 'Activo' : 'Revocado',
                              style: GoogleFonts.inter(
                                color: isActive ? const Color(0xFF166534) : const Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Assigned Patients
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$assignedCount sujetos',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            color: kTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Last Login
                      Expanded(
                        flex: 2,
                        child: Text(
                          lastAccess,
                          style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                        ),
                      ),
                      // Actions Menu
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: PopupMenuButton<String>(
                          icon: const Icon(LucideIcons.moreHorizontal, color: kTextSecondary),
                          onSelected: (val) {
                            if (val == 'toggle_status') {
                              _toggleInvestigatorActive(r['id'], isActive);
                            } else if (val == 'assign_patients') {
                              _showAssignPatientsModal(r);
                            } else if (val == 'edit_details') {
                              _showEditInvestigatorDialog(r);
                            } else if (val == 'delete_investigator') {
                              _showDeleteConfirmation(r);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit_details',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Editar Datos')),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'assign_patients',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.userCheck, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Asignar Participantes')),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'toggle_status',
                              child: Row(
                                children: [
                                  Icon(isActive ? LucideIcons.userX : LucideIcons.userCheck, size: 16, color: isActive ? kDangerRed : Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isActive ? 'Desactivar cuenta' : 'Activar cuenta',
                                      style: TextStyle(color: isActive ? kDangerRed : Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete_investigator',
                              child: Row(
                                children: [
                                  Icon(LucideIcons.trash2, size: 16, color: kDangerRed),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Eliminar Investigador', style: TextStyle(color: kDangerRed))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastAccess(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return 'Hace ${diff.inMinutes} minutos';
      } else if (diff.inHours < 24) {
        return 'Hace ${diff.inHours} horas';
      } else {
        return 'Hace ${diff.inDays} días';
      }
    } catch (_) {
      return 'Fecha inválida';
    }
  }

  void _showAssignPatientsModal(Map<String, dynamic> investigator) {
    final assigned = List<String>.from(investigator['participantes_asignados'] ?? []);
    final List<String> tempAssigned = List.from(assigned);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Asignar Participantes',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona los participantes asignados a ${investigator['nombre_completo']}:',
                      style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: _availablePatients.map((pId) {
                          final isChecked = tempAssigned.contains(pId);
                          return CheckboxListTile(
                            title: Text(pId, style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                            value: isChecked,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            dense: true,
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  tempAssigned.add(pId);
                                } else {
                                  tempAssigned.remove(pId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCELAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      investigator['participantes_asignados'] = tempAssigned;
                      final api = ApiService();
                      await http.put(
                        Uri.parse('${api.baseUrl}/admin/investigadores/${investigator['id']}/pacientes'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode(tempAssigned),
                      );
                      
                      if (context.mounted) {
                        AppToast.show(context, 'Asignaciones guardadas', type: ToastType.success);
                        Navigator.pop(context);
                      }
                      _fetchInvestigators();
                    } catch (e) {
                      if (context.mounted) {
                        AppToast.show(context, 'Error: $e', type: ToastType.error);
                      }
                    }
                  },
                  child: Text('GUARDAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kSystemBlue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditInvestigatorDialog(Map<String, dynamic> investigator) {
    final nameCtrl = TextEditingController(text: investigator['nombre_completo']);
    final userCtrl = TextEditingController(text: investigator['username']);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Editar Investigador',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nombre Completo:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej: Juan Pérez',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El nombre completo es requerido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Nombre de Usuario:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: userCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ej: juan_perez',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'El nombre de usuario es requerido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCELAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextSecondary)),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _api.updateInvestigatorDetails(
                    investigator['id'],
                    nameCtrl.text.trim(),
                    userCtrl.text.trim(),
                  );
                  if (context.mounted) {
                    AppToast.show(context, 'Investigador actualizado', type: ToastType.success);
                    Navigator.pop(context);
                  }
                  _fetchInvestigators();
                } catch (e) {
                  if (context.mounted) {
                    AppToast.show(context, 'Error: $e', type: ToastType.error);
                  }
                }
              },
              child: Text('GUARDAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kSystemBlue)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> investigator) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar Investigador',
      message: '¿Está seguro de que desea eliminar al investigador "${investigator['nombre_completo']}"? Esta acción no se puede deshacer y desasociará sus participantes.',
      confirmLabel: 'Eliminar',
      confirmColor: kDangerRed,
      icon: LucideIcons.trash2,
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        await _api.deleteInvestigator(investigator['id']);
        if (mounted) {
          AppToast.show(context, 'Investigador eliminado con éxito', type: ToastType.success);
        }
        _fetchInvestigators();
      } catch (e) {
        if (mounted) {
          AppToast.show(context, 'Error: $e', type: ToastType.error);
        }
      }
    }
  }


}

