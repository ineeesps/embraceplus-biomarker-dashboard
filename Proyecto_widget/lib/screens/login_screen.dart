import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/api_service.dart';
import 'participant_selection_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  static const Color kTextPrimary    = Color(0xFF0F172A);
  static const Color kCyberBlue      = Color(0xFF0EA5E9);
  static const Color kBgScreen       = Color(0xFFF8FAFC);
  static const Color kTextSecondary  = Color(0xFF64748B);
  static const Color kBorderColor    = Color(0xFFE2E8F0);

  Future<void> _login() async {
    setState(() => _errorMessage = null);

    final api = ApiService();
    final username = _userController.text.trim();
    final password = _passwordController.text;

    try {
      final assignedParticipants = await api.login(username, password);
      if (!mounted) return;

      final summaryRaw = await api.getParticipantsSummary(username);
      if (!mounted) return;

      final preloaded = summaryRaw.map((j) => ParticipantData.fromJson(j)).toList();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParticipantSelectionScreen(
            username: username,
            assignedParticipants: assignedParticipants,
            preloadedData: preloaded,
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE2E8F0),
              Color(0xFFF8FAFC),
              Color(0xFFCBD5E1),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(LucideIcons.barChart2, size: 48, color: kTextPrimary),
                          const SizedBox(height: 12),
                          Text(
                            'EmbracePlus',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'CLINICAL RESEARCH PLATFORM',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: kCyberBlue,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          Text(
                            'Iniciar Sesión',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Acceso exclusivo para investigadores',
                            style: GoogleFonts.inter(fontSize: 14, color: kTextSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          TextField(
                            controller: _userController,
                            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              labelStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 13),
                              prefixIcon: const Icon(LucideIcons.badge, color: kTextPrimary, size: 18),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: kBorderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: kBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: kTextPrimary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 13),
                              prefixIcon: const Icon(LucideIcons.lock, color: kTextPrimary, size: 18),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                                  color: kTextSecondary,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: kBorderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: kBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: kTextPrimary, width: 2),
                              ),
                            ),
                          ),
                          
                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.alertCircle, color: Colors.red.shade700, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.inter(
                                        color: Colors.red.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 32),
                          
                          ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kTextPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Acceder al sistema',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kBgScreen,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.shield, size: 15, color: kTextSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Entorno seguro y anonimizado (RGPD).',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      color: kTextSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
