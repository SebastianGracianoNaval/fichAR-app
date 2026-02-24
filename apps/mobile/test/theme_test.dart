import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/theme.dart';

void main() {
  testWidgets('ficharTheme primary is teal #0F766E', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            expect(scheme.primary, const Color(0xFF0F766E));
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('ficharTheme error is #DC2626', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            expect(scheme.error, const Color(0xFFDC2626));
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('ficharTheme scaffoldBackgroundColor is #F8FAFC', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
