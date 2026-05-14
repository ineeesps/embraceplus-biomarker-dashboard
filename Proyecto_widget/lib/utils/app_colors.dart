import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color bgScreen = Color(0xFFF8FAFC);
  static const Color bgCard   = Colors.white;

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF94A3B8);

  static const Color cyberBlue = Color(0xFF0EA5E9);

  static const Color border = Color(0xFFE2E8F0);

  static const Color sidebarBg     = Color(0xFF1E293B);
  static const Color sidebarBorder = Color(0xFF334155);
  static const Color sidebarHover  = Color(0xFF334155);

  // PALETA CLÍNICA ESTANDARIZADA
  static const Color clinicalHeart  = Color(0xFFE11D48); // Rose 600
  static const Color clinicalBreath = Color(0xFF06B6D4); // Cyan 500
  static const Color clinicalMove   = Color(0xFFF97316); // Orange 500
  static const Color clinicalTeal   = Color(0xFF0D9488); // Teal 600
  static const Color clinicalViolet = Color(0xFF8B5CF6); // Violet 500
  static const Color clinicalSlate  = Color(0xFF64748B); // Slate 500

  // SENSORES (Alias para compatibilidad)
  static const Color sensorHeart  = clinicalHeart;
  static const Color sensorPRV    = Color(0xFFF43F5E); // Mantenemos el tono rojizo específico
  static const Color sensorBreath = clinicalBreath;
  static const Color sensorMove   = clinicalMove;
  static const Color sensorEDA    = Color(0xFF10B981);
  static const Color sensorTemp   = Color(0xFFFBBF24);
  static const Color sensorSleep  = clinicalViolet;

  static const Color statusGood     = Color(0xFF10B981);
  static const Color statusWarning  = Color(0xFFF59E0B);
  static const Color statusCritical = Color(0xFFEF4444);
  static const Color statusGap      = Color(0xFFE2E8F0);
}
