import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/reportes_screen.dart';
import 'package:fichar_mobile/theme.dart';
import 'package:fichar_mobile/theme/layout_tokens.dart';
import 'package:fichar_mobile/widgets/inline_error.dart';
import 'package:fichar_mobile/widgets/responsive_content_wrapper.dart';

void main() {
  testWidgets('ReportesScreen renders form and ResponsiveContentWrapper', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const ReportesScreen()),
    );
    expect(find.byType(ReportesScreen), findsOneWidget);
    expect(find.byType(ResponsiveContentWrapper), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
  });

  testWidgets('ReportesScreen ResponsiveContentWrapper uses formWide 560', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const ReportesScreen()),
    );
    final finder = find.descendant(
      of: find.byType(ResponsiveContentWrapper),
      matching: find.byWidgetPredicate(
        (w) {
          if (w is! ConstrainedBox) return false;
          return w.constraints.maxWidth == kContentMaxWidthFormWide;
        },
      ),
    );
    expect(finder, findsOneWidget);
    final constrainedBox = tester.widget<ConstrainedBox>(finder);
    expect(constrainedBox.constraints.maxWidth, kContentMaxWidthFormWide);
  });

  testWidgets(
    'ReportesScreen shows InlineError when Export tapped with empty dates',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ficharTheme, home: const ReportesScreen()),
      );
      await tester.tap(find.text('Exportar'));
      await tester.pump();
      expect(find.byType(InlineError), findsOneWidget);
      expect(find.text('Seleccioná fecha desde y hasta'), findsOneWidget);
    },
  );
}
