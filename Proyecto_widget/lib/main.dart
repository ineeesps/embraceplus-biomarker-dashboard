import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'providers/dashboard_provider.dart';

/// Punto de entrada principal de la aplicación EmbracePlus Dashboard.
/// Configura el estado global mediante Provider y el tema visual clínico.
void main() {
  // Deshabilitar la búsqueda de fuentes en red para evitar errores sin conexión
  GoogleFonts.config.allowRuntimeFetching = false;
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Paleta de colores oficial para el TFG (Navy Blue & Clinical Clean)
  static const Color primaryBlue = Color(0xFF1E293B);
  static const Color accentTeal = Color(0xFF0F766E);
  static const Color bgLight = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmbracePlus Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: accentTeal,
          surface: Colors.white,
          onSurface: primaryBlue,
        ),
        scaffoldBackgroundColor: bgLight,
        
        // Fix para el color del cursor y la selección de texto
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primaryBlue,
          selectionColor: primaryBlue.withOpacity(0.2),
          selectionHandleColor: primaryBlue,
        ),
        
        // Estilo global para inputs
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.grey),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
