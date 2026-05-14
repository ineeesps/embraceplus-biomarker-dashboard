import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum ToastType { success, error, info }

class AppToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    _show(Overlay.of(context), message, type: type);
  }

  static void showOnOverlay(OverlayState overlay, String message, {ToastType type = ToastType.info}) {
    _show(overlay, message, type: type);
  }

  static void _show(OverlayState overlay, String message, {ToastType type = ToastType.info}) {
    _current?.remove();
    _current = null;

    final config = _toastConfig(type);
    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(message: message, config: config),
    );

    _current = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
      if (_current == entry) _current = null;
    });
  }

  static _ToastConfig _toastConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          icon: LucideIcons.checkCircle2,
          iconColor: const Color(0xFF10B981),
          borderColor: const Color(0xFF10B981),
          bg: const Color(0xFFF0FDF4),
          labelColor: const Color(0xFF065F46),
        );
      case ToastType.error:
        return _ToastConfig(
          icon: LucideIcons.xCircle,
          iconColor: const Color(0xFFEF4444),
          borderColor: const Color(0xFFEF4444),
          bg: const Color(0xFFFFF1F2),
          labelColor: const Color(0xFF991B1B),
        );
      case ToastType.info:
        return _ToastConfig(
          icon: LucideIcons.info,
          iconColor: const Color(0xFF0EA5E9),
          borderColor: const Color(0xFF0EA5E9),
          bg: const Color(0xFFF0F9FF),
          labelColor: const Color(0xFF0C4A6E),
        );
    }
  }
}

class _ToastConfig {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color bg;
  final Color labelColor;
  const _ToastConfig({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.bg,
    required this.labelColor,
  });
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final _ToastConfig config;
  const _ToastWidget({required this.message, required this.config});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360, minWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.config.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.config.borderColor.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.config.icon, color: widget.config.iconColor, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.config.labelColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
