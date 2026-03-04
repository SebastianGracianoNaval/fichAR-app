// fichAR Design System (definiciones/FRONTEND.md, plan Step 8).
// Paletas: Profesional (A), Fresco/Duolingo (B), Neutro (C). CFG-042/043/044.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/org_config_provider.dart';

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

// --- Paletas (FRONTEND.md §1) ---

const Color _profesionalPrimary = Color(0xFF1E3A5F);
const Color _profesionalSecondary = Color(0xFF4A90D9);
const Color _profesionalSurface = Color(0xFFFFFFFF);
const Color _profesionalScaffold = Color(0xFFF5F7FA);
const Color _profesionalOnSurface = Color(0xFF1A1A2E);
const Color _profesionalError = Color(0xFFD32F2F);

const Color _frescoPrimary = Color(0xFF58CC02);
const Color _frescoSecondary = Color(0xFF1CB0F6);
const Color _frescoSurface = Color(0xFFFFFFFF);
const Color _frescoScaffold = Color(0xFFF7F7F7);
const Color _frescoOnSurface = Color(0xFF3C3C3C);
const Color _frescoError = Color(0xFFFF4B4B);

const Color _neutroPrimary = Color(0xFF424242);
const Color _neutroSecondary = Color(0xFF757575);
const Color _neutroSurface = Color(0xFFFFFFFF);
const Color _neutroScaffold = Color(0xFFFAFAFA);
const Color _neutroOnSurface = Color(0xFF212121);
const Color _neutroError = Color(0xFFE53935);

Color? _parseHex(String? hex) {
  if (hex == null || hex.trim().isEmpty) return null;
  String s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final n = int.tryParse(s, radix: 16);
  return n != null ? Color(n) : null;
}

ThemeData _buildTheme({
  required Color primary,
  required Color secondary,
  required Color surface,
  required Color scaffold,
  required Color onSurface,
  required Color error,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: onSurface,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: scaffold,
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
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, kTouchTargetMin),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 16),
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

/// Builds theme from palette name (profesional | fresco | neutro | custom).
/// For custom, primaryHex/secondaryHex must be valid hex (e.g. #58CC02).
ThemeData buildFicharThemeFromPalette(
  String palette, {
  String? primaryHex,
  String? secondaryHex,
}) {
  final p = palette.trim().toLowerCase();
  if (p == 'custom') {
    final primary = _parseHex(primaryHex) ?? _profesionalPrimary;
    final secondary = _parseHex(secondaryHex) ?? _profesionalSecondary;
    return _buildTheme(
      primary: primary,
      secondary: secondary,
      surface: _profesionalSurface,
      scaffold: _profesionalScaffold,
      onSurface: _profesionalOnSurface,
      error: _profesionalError,
    );
  }
  if (p == 'fresco') {
    return _buildTheme(
      primary: _frescoPrimary,
      secondary: _frescoSecondary,
      surface: _frescoSurface,
      scaffold: _frescoScaffold,
      onSurface: _frescoOnSurface,
      error: _frescoError,
    );
  }
  if (p == 'neutro') {
    return _buildTheme(
      primary: _neutroPrimary,
      secondary: _neutroSecondary,
      surface: _neutroSurface,
      scaffold: _neutroScaffold,
      onSurface: _neutroOnSurface,
      error: _neutroError,
    );
  }
  // profesional (default)
  return _buildTheme(
    primary: _profesionalPrimary,
    secondary: _profesionalSecondary,
    surface: _profesionalSurface,
    scaffold: _profesionalScaffold,
    onSurface: _profesionalOnSurface,
    error: _profesionalError,
  );
}

// Cache to avoid rebuilds (plan Step 8).
String? _cachedThemeKey;
ThemeData? _cachedTheme;

/// Theme from org config (CFG-042/043/044). Use when config is loaded (e.g. inside AuthHomeResolver).
/// When not loaded, returns default (profesional). Cached by (palette, primary, secondary).
ThemeData getFicharThemeFromConfig() {
  if (!OrgConfigProvider.isLoaded) {
    return ficharTheme;
  }
  final palette = OrgConfigProvider.orgColorPalette;
  final primary = OrgConfigProvider.orgColorPrimary;
  final secondary = OrgConfigProvider.orgColorSecondary;
  final key = '$palette|$primary|$secondary';
  if (_cachedThemeKey == key && _cachedTheme != null) {
    return _cachedTheme!;
  }
  final theme = buildFicharThemeFromPalette(
    palette,
    primaryHex: primary.isEmpty ? null : primary,
    secondaryHex: secondary.isEmpty ? null : secondary,
  );
  _cachedThemeKey = key;
  _cachedTheme = theme;
  return theme;
}

/// Clears theme cache (e.g. on sign out so next login gets fresh palette).
void clearFicharThemeCache() {
  _cachedThemeKey = null;
  _cachedTheme = null;
}

// Default theme (login/splash or when config not loaded). Paleta Profesional.
ThemeData get ficharTheme => buildFicharThemeFromPalette('profesional');
