import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/theme.dart';
import 'package:fichar_mobile/theme/layout_tokens.dart';
import 'package:fichar_mobile/widgets/responsive_content_wrapper.dart';

void main() {
  testWidgets('ResponsiveContentWrapper applies 16px padding on mobile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Scaffold(
          body: ResponsiveContentWrapper(
            width: ContentWidth.form,
            child: const Text('Content'),
          ),
        ),
      ),
    );

    expect(find.text('Content'), findsOneWidget);
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(ResponsiveContentWrapper),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(constrainedBox.constraints.maxWidth, kContentMaxWidthForm);
  });

  testWidgets('ResponsiveContentWrapper form width max 440', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Scaffold(
          body: ResponsiveContentWrapper(
            width: ContentWidth.form,
            child: const Text('Content'),
          ),
        ),
      ),
    );

    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(ResponsiveContentWrapper),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(constrainedBox.constraints.maxWidth, 440);
  });

  testWidgets('ResponsiveContentWrapper dashboard width max 560', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: Scaffold(
          body: ResponsiveContentWrapper(
            width: ContentWidth.dashboard,
            child: const Text('Content'),
          ),
        ),
      ),
    );

    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(ResponsiveContentWrapper),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(constrainedBox.constraints.maxWidth, 560);
  });
}
