import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/admin_empleados_screen.dart';
import 'package:fichar_mobile/theme.dart';
import 'test_app_setup.dart';

void main() {
  setUpAll(() async {
    await initTestAppEnv();
  });

  testWidgets('AdminEmpleadosScreen renders loading state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const AdminEmpleadosScreen()),
    );
    expect(find.byType(AdminEmpleadosScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
