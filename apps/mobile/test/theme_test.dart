import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/theme.dart';

void main() {
  testWidgets('ficharTheme default palette is profesional (primary #1E3A5F)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            expect(scheme.primary, const Color(0xFF1E3A5F));
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('ficharTheme error is #D32F2F (profesional)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            expect(scheme.error, const Color(0xFFD32F2F));
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('ficharTheme scaffoldBackgroundColor is #F5F7FA (profesional)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('buildFicharThemeFromPalette(fresco) is green Duolingo-style', (
    WidgetTester tester,
  ) async {
    final theme = buildFicharThemeFromPalette('fresco');
    expect(theme.colorScheme.primary, const Color(0xFF58CC02));
    expect(theme.colorScheme.secondary, const Color(0xFF1CB0F6));
  });

  testWidgets('buildFicharThemeFromPalette(neutro) is gray', (
    WidgetTester tester,
  ) async {
    final theme = buildFicharThemeFromPalette('neutro');
    expect(theme.colorScheme.primary, const Color(0xFF424242));
    expect(theme.colorScheme.secondary, const Color(0xFF757575));
  });
}
