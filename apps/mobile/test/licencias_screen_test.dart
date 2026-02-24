import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/licencias_screen.dart';
import 'package:fichar_mobile/theme.dart';
import 'test_app_setup.dart';

void main() {
  setUpAll(() async {
    await initTestAppEnv();
  });

  testWidgets('LicenciasScreen renders loading state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const LicenciasScreen()),
    );
    expect(find.byType(LicenciasScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
