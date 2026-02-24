import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/theme.dart';
import 'package:fichar_mobile/widgets/inline_error.dart';

void main() {
  testWidgets('InlineError renders message and icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: const Scaffold(body: InlineError(message: 'Error de prueba')),
      ),
    );

    expect(find.text('Error de prueba'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('InlineError with empty message renders nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: const Scaffold(body: InlineError(message: '')),
      ),
    );

    expect(find.byType(InlineError), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('InlineError with onRetry shows Reintentar button', (
    WidgetTester tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Scaffold(
          body: InlineError(message: 'Error', onRetry: () => retried = true),
        ),
      ),
    );

    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retried, true);
  });
}
