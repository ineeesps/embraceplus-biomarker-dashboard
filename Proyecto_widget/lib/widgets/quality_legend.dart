import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QualityLegend extends StatelessWidget {
  const QualityLegend({super.key});

  static const Color kBorderColor = Color(0xFFE2E8F0);
  static const Color kBgScreen    = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorderColor),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildItem(const Color(0xFF94A3B8), LucideIcons.minusCircle, 'Inactivo/Apagado'),
            _buildItem(const Color(0xFFFACC15), LucideIcons.alertTriangle, 'Mal colocado'),
            _buildItem(const Color(0xFFEF4444), LucideIcons.zap, 'Ruido/Movimiento crítico'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
