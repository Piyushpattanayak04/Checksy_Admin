import 'package:flutter/material.dart';

/// Premium "Midnight Luxe" Color Palette for Admin App
/// Matches the client app theme for brand consistency
class AppColors {
  // Prevent instantiation
  AppColors._();

  // ============== Background Colors ==============
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF13131A);
  static const Color card = Color(0xFF1A1A24);
  static const Color cardElevated = Color(0xFF22222E);

  // ============== Primary Colors ==============
  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondary = Color(0xFFA29BFE);
  static const Color accent = Color(0xFF00D9FF);

  // ============== Semantic Colors ==============
  static const Color success = Color(0xFF00B894);
  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFBE76);
  static const Color info = Color(0xFF74B9FF);

  // ============== Text Colors ==============
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C0);
  static const Color textMuted = Color(0xFF6C6C7E);
  static const Color textDisabled = Color(0xFF4A4A5A);

  // ============== Border & Divider Colors ==============
  static const Color border = Color(0xFF2A2A3A);
  static const Color divider = Color(0xFF1F1F2E);

  // ============== Gradient Colors ==============
  static const List<Color> primaryGradient = [
    Color(0xFF6C5CE7),
    Color(0xFFA29BFE),
  ];

  static const List<Color> accentGradient = [
    Color(0xFF00D9FF),
    Color(0xFF6C5CE7),
  ];

  // ============== Status Colors ==============
  static const Color statusActive = Color(0xFF00B894);
  static const Color statusPending = Color(0xFFFFBE76);
  static const Color statusClosed = Color(0xFFFF6B6B);

  // ============== Overlay Colors ==============
  static const Color overlay = Color(0xCC000000);
  static const Color glassOverlay = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // ============== Admin-specific Colors ==============
  static const Color adminBadge = Color(0xFFFFBE76);
  static const Color superAdminBadge = Color(0xFFFFD700);
}
