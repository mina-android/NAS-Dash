import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background surfaces (TrueNAS Obsidian)
  static const Color background = Color(0xFF0B0F17);
  static const Color surface = Color(0xFF131B26);
  static const Color surfaceElevated = Color(0xFF1B2433);
  static const Color surfaceCard = Color(0xFF16202E);
  static const Color border = Color(0xFF263345);

  // Brand Accents
  static const Color primary = Color(0xFF0095D5); // TrueNAS Cyan
  static const Color primaryLight = Color(0xFF38BDF8);
  static const Color primaryDark = Color(0xFF0369A1);
  static const Color secondary = Color(0xFF6366F1); // Indigo accent

  // Status & Telemetry semantic colors
  static const Color healthy = Color(0xFF10B981); // Emerald green (ONLINE / OK)
  static const Color warning = Color(0xFFF59E0B); // Amber (DEGRADED / Upgrades)
  static const Color critical = Color(0xFFEF4444); // Red (FAULTED / Offline)
  static const Color info = Color(0xFF0284C7); // Sky blue
  static const Color stopped = Color(0xFF64748B); // Slate grey

  // Text
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}
