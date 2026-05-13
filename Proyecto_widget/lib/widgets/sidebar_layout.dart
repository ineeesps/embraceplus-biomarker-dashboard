import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SidebarLayout extends StatefulWidget {
  final Widget body;
  final String username;
  final String? participantId;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onUpload;
  final VoidCallback onLogout;
  final VoidCallback onHome;

  const SidebarLayout({
    super.key,
    required this.body,
    required this.username,
    this.participantId,
    this.selectedIndex = 0,
    required this.onItemSelected,
    required this.onUpload,
    required this.onLogout,
    required this.onHome,
  });

  @override
  State<SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<SidebarLayout> {
  bool _isExpanded = false;

  static const Color primaryBlue = Color(0xFF1E293B);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color activeBg = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.participantId != null ? 'Dashboard: ${widget.participantId}' : 'EmbracePlus',
            style: GoogleFonts.inter(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: primaryBlue),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: primaryBlue,
          child: _buildSidebarContent(isExpanded: true, isDrawer: true),
        ),
        body: widget.body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isExpanded = true),
            onExit: (_) => setState(() => _isExpanded = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _isExpanded ? 260 : 72,
              color: primaryBlue,
              child: _buildSidebarContent(isExpanded: _isExpanded, isDrawer: false),
            ),
          ),

          Expanded(
            child: widget.body,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent({required bool isExpanded, required bool isDrawer}) {
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
                const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    'EmbracePlus',
                    style: GoogleFonts.inter(
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
              _buildNavItem(
                icon: Icons.home_rounded,
                title: 'Home',
                isSelected: widget.participantId == null && widget.selectedIndex == 0,
                isExpanded: isExpanded,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  widget.onHome();
                },
              ),
              
              if (widget.participantId != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: isExpanded
                      ? Text(
                          'DASHBOARD: ${widget.participantId}',
                          style: GoogleFonts.inter(
                            color: textLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : const Divider(color: textLight, indent: 4, endIndent: 4),
                ),
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Inicio',
                  isSelected: widget.selectedIndex == 0,
                  isExpanded: isExpanded,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    widget.onItemSelected(0);
                  },
                ),
                _buildNavItem(
                  icon: Icons.directions_run_rounded,
                  title: 'Movimiento y Actividad',
                  isSelected: widget.selectedIndex == 1,
                  isExpanded: isExpanded,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    widget.onItemSelected(1);
                  },
                ),
                _buildNavItem(
                  icon: Icons.favorite_rounded,
                  title: 'Cardíaco y Respiratorio',
                  isSelected: widget.selectedIndex == 2,
                  isExpanded: isExpanded,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    widget.onItemSelected(2);
                  },
                ),
                _buildNavItem(
                  icon: Icons.thermostat_rounded,
                  title: 'Estrés y Temperatura',
                  isSelected: widget.selectedIndex == 3,
                  isExpanded: isExpanded,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    widget.onItemSelected(3);
                  },
                ),
                _buildNavItem(
                  icon: Icons.fact_check_rounded,
                  title: 'Clasificación',
                  isSelected: widget.selectedIndex == 4,
                  isExpanded: isExpanded,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    widget.onItemSelected(4);
                  },
                ),
              ],
            ],
          ),
        ),

        // Bottom Actions
        const Divider(color: Color(0xFF334155), height: 1),
        _buildNavItem(
          icon: Icons.cloud_upload_rounded,
          title: 'Subir Participante',
          isSelected: false,
          isExpanded: isExpanded,
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            widget.onUpload();
          },
        ),
        _buildNavItem(
          icon: Icons.logout_rounded,
          title: 'Cerrar Sesión',
          isSelected: false,
          isExpanded: isExpanded,
          onTap: () {
            if (isDrawer) Navigator.pop(context);
            widget.onLogout();
          },
        ),
        
        // User Profile
        Container(
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 24 : 20, vertical: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: accentTeal.withOpacity(0.15),
                  child: const Icon(Icons.person, color: accentTeal, size: 16),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.username,
                        style: GoogleFonts.inter(
                          color: Colors.white, 
                          fontSize: 13, 
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Investigador',
                        style: GoogleFonts.inter(
                          color: textLight.withOpacity(0.8), 
                          fontSize: 10,
                        ),
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

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accentTeal.withOpacity(0.2),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 24 : 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? accentTeal : Colors.transparent,
                width: 4,
              ),
            ),
            color: isSelected ? activeBg.withOpacity(0.5) : Colors.transparent,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : textLight,
                    size: 22,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : textLight,
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
}
