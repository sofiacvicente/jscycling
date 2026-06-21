import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Notifier ──────────────────────────────────────────────────────────
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeNotifier(super.initial);

  static Future<ThemeNotifier> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? true;
    return ThemeNotifier(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  bool get isDark => value == ThemeMode.dark;

  Future<void> toggle() async {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}

// ─── Color tokens ─────────────────────────────────────────────────────────────
class AppColors {
  final bool isDark;
  const AppColors(this.isDark);

  // Backgrounds
  Color get bg         => isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F4F8);
  Color get bgTop      => isDark ? const Color(0xFF0A1628) : const Color(0xFFDBE8FF);
  Color get bgBottom   => isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F4F8);

  // Background gradient
  BoxDecoration get bgGradient => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [const Color(0xFF0A1628), const Color(0xFF080E1A)]
          : [const Color(0xFFDBE8FF), const Color(0xFFF2F4F8)],
      stops: const [0.0, 0.55],
    ),
  );
  Color get surface    => isDark ? const Color(0xFF1A1A1A) : Colors.white;
  Color get navBg      => isDark ? const Color(0xFF141414) : Colors.white;

  // Glass panels
  Color get panelBg    => isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
  Color get panelBorder=> isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);

  // Input fields
  Color get inputBg    => isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC);
  Color get inputBorder=> isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);

  // Text
  Color get textPrimary   => isDark ? Colors.white          : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? Colors.white70        : const Color(0xFF64748B);
  Color get textMuted     => isDark ? Colors.white38        : const Color(0xFF94A3B8);

  // Nav icons
  Color get navActive   => const Color(0xFF7AA8F0);
  Color get navInactive => isDark ? Colors.white30 : const Color(0xFFB0BEC5);
  Color get navBorder   => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

  // Accent
  Color get accent => const Color(0xFF2A52A0);
  Color get accentLight => const Color(0xFF7AA8F0);

  // Divider
  Color get divider => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

  // Checklist item
  Color get checklistUnchecked => isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC);
  Color get checklistBorderOff => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

  // Progress bar background
  Color get progressBg  => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

  // Shadow / elevation hints
  List<BoxShadow> get panelShadow => isDark
      ? []
      : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))];
}

// ─── Inherited accessor ───────────────────────────────────────────────────────
class AppTheme extends InheritedWidget {
  final ThemeNotifier notifier;

  const AppTheme({super.key, required this.notifier, required super.child});

  static AppColors colorsOf(BuildContext context) {
    final n = context.dependOnInheritedWidgetOfExactType<AppTheme>()!.notifier;
    return AppColors(n.isDark);
  }

  static ThemeNotifier of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppTheme>()!.notifier;
  }

  @override
  bool updateShouldNotify(AppTheme old) => notifier.value != old.notifier.value;
}