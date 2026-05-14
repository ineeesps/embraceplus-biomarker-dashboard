import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'providers/dashboard_provider.dart';
import 'utils/app_colors.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = true;
  
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

  static const Color kTextPrimary  = AppColors.textPrimary;
  static const Color kCyberBlue    = AppColors.cyberBlue;
  static const Color kBgScreen     = AppColors.bgScreen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmbracePlus Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kTextPrimary,
          primary: kTextPrimary,
          secondary: kCyberBlue,
          surface: Colors.white,
          onSurface: kTextPrimary,
        ),
        scaffoldBackgroundColor: kBgScreen,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: kTextPrimary,
          selectionColor: kTextPrimary.withValues(alpha: 0.2),
          selectionHandleColor: kTextPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.grey),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kTextPrimary, width: 2),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
