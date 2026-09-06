import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors (Industrial Deep Blue & Teal)
  static const Color primary = Color(0xFF0A2647); // Deep Navy
  static const Color primaryLight = Color(0xFF144272);
  static const Color accent = Color(0xFF2C74B3); // Bright Blue
  static const Color tealAccent = Color(0xFF205295); // Teal-ish

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50: clean, gentle on eyes, prevents fatigue
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900

  // Surface (Glass effect bases)
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800

  // Text
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900 - maximum readability
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600 - crisp, non-fading secondary
  static const Color textTertiaryLight = Color(0xFF64748B); // Slate 500 - meta & timestamp
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Status (Universal)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Status tokens specifically tuned for Light Mode (WCAG AAA contrast)
  static const Color successLight = Color(0xFF059669); // Emerald 600
  static const Color successBgLight = Color(0xFFECFDF5); // Emerald 50
  static const Color successBorderLight = Color(0xFFA7F3D0); // Emerald 200
  static const Color successTextLight = Color(0xFF047857); // Emerald 700

  static const Color warningLight = Color(0xFFD97706); // Amber 600
  static const Color warningBgLight = Color(0xFFFFFBEB); // Amber 50
  static const Color warningBorderLight = Color(0xFFFDE68A); // Amber 200
  static const Color warningTextLight = Color(0xFFB45309); // Amber 700

  static const Color errorLight = Color(0xFFDC2626); // Red 600
  static const Color errorBgLight = Color(0xFFFEF2F2); // Red 50
  static const Color errorBorderLight = Color(0xFFFECACA); // Red 200
  static const Color errorTextLight = Color(0xFFB91C1C); // Red 700

  static const Color infoLight = Color(0xFF0284C7); // Sky 600
  static const Color infoBgLight = Color(0xFFF0F9FF); // Sky 50
  static const Color infoBorderLight = Color(0xFFBAE6FD); // Sky 200
  static const Color infoTextLight = Color(0xFF0369A1); // Sky 700
}
