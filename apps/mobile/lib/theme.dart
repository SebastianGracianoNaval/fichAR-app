// fichAR Design System (definiciones/FRONTEND.md, plan-refactor-frontend)
// Paleta from mocks: primary teal, secondary blue. Tokens from design-system-patterns.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Spacing
const double kSpacingXs = 4;
const double kSpacingSm = 8;
const double kSpacingMd = 16;
const double kSpacingLg = 24;
const double kSpacingXl = 32;
const double kSpacingXxl = 48;

// Border radius
const double kRadiusSm = 8;
const double kRadiusMd = 12;
const double kRadiusLg = 16;
const double kRadiusXl = 20;

// Touch target (definiciones/FRONTEND.md: min 56px)
const double kTouchTargetMin = 56;

// Animation durations
const Duration kAnimFast = Duration(milliseconds: 150);
const Duration kAnimNormal = Duration(milliseconds: 250);
const Duration kAnimSlow = Duration(milliseconds: 350);

// Paleta from mocks (00-deep-analysis.md)
const Color _primary = Color(0xFF0F766E);
const Color _secondary = Color(0xFF1E3A5F);
const Color _surface = Color(0xFFFFFFFF);
const Color _scaffold = Color(0xFFF8FAFC);
const Color _onSurface = Color(0xFF1A1A2E);
const Color _error = Color(0xFFDC2626);

ThemeData get ficharTheme {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      error: _error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _onSurface,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: _scaffold,
    textTheme: GoogleFonts.nunitoTextTheme(
      ThemeData.light().textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: const TextStyle(fontSize: 16),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, kTouchTargetMin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpacingMd,
        vertical: kSpacingMd,
      ),
    ),
  );
}
