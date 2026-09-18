import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the web app's `resources/css/app.css`
/// (shadcn/Tailwind v4 custom properties). Keep this in sync with that file.
class AppColors {
  const AppColors._();

  // Light
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightForeground = Color(0xFF0F172A);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardForeground = Color(0xFF0F172A);
  static const lightPrimary = Color(0xFF2563EB);
  static const lightPrimaryForeground = Color(0xFFFFFFFF);
  static const lightSecondary = Color(0xFFF1F5F9);
  static const lightSecondaryForeground = Color(0xFF0F172A);
  static const lightMuted = Color(0xFFF8FAFC);
  static const lightMutedForeground = Color(0xFF64748B);
  static const lightAccent = Color(0xFFEFF6FF);
  static const lightAccentForeground = Color(0xFF0F172A);
  static const lightDestructive = Color(0xFFDC2626);
  static const lightDestructiveForeground = Color(0xFFFFFFFF);
  static const lightBorder = Color(0x3394A3B8); // rgba(148,163,184,.2)

  // Dark
  static const darkBackground = Color(0xFF0F172A);
  static const darkForeground = Color(0xFFF8FAFC);
  static const darkCard = Color(0xFF111827);
  static const darkCardForeground = Color(0xFFF8FAFC);
  static const darkPrimary = Color(0xFF60A5FA);
  static const darkPrimaryForeground = Color(0xFF0F172A);
  static const darkSecondary = Color(0xFF1E293B);
  static const darkSecondaryForeground = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFF111827);
  static const darkMutedForeground = Color(0xFF94A3B8);
  static const darkAccent = Color(0xFF172554);
  static const darkAccentForeground = Color(0xFFF8FAFC);
  static const darkDestructive = Color(0xFFEF4444);
  static const darkDestructiveForeground = Color(0xFFF8FAFC);
  static const darkBorder = Color(0x3D94A3B8); // rgba(148,163,184,.24)

  /// Chart / category palette (light), matches `--chart-1..5` and the
  /// seeded category colors on the backend.
  static const chartLight = [
    Color(0xFF2563EB),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF60A5FA),
  ];

  static const chartDark = [
    Color(0xFF60A5FA),
    Color(0xFF4ADE80),
    Color(0xFFFBBF24),
    Color(0xFFA78BFA),
    Color(0xFF93C5FD),
  ];

  /// Admin hero banner gradient (135deg), reused for the budget dashboard header.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
  );

  /// Semantic accent tones used for icon chips / status badges across the
  /// admin dashboard (violet, rose, blue, amber, emerald, cyan).
  static const violet = Color(0xFF8B5CF6);
  static const rose = Color(0xFFF43F5E);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF22C55E);
  static const cyan = Color(0xFF06B6D4);
}
