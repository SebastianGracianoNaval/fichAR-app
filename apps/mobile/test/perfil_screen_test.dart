import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/perfil_screen.dart';
import 'package:fichar_mobile/theme.dart';
import 'package:fichar_mobile/theme/layout_tokens.dart';
import 'package:fichar_mobile/widgets/responsive_content_wrapper.dart';
import 'test_app_setup.dart';

void main() {
  setUpAll(() async {
    await initTestAppEnv();
  });

  testWidgets(
    'PerfilScreen renders loading skeleton and ResponsiveContentWrapper',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ficharTheme, home: const PerfilScreen()),
      );
      expect(find.byType(PerfilScreen), findsOneWidget);
      expect(find.byType(ResponsiveContentWrapper), findsOneWidget);
    },
  );

  testWidgets('PerfilScreen ResponsiveContentWrapper uses formWide 560', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const PerfilScreen()),
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
}
