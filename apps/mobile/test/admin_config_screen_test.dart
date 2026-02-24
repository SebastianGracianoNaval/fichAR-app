import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/admin_config_screen.dart';
import 'package:fichar_mobile/theme.dart';
import 'test_app_setup.dart';

void main() {
  setUpAll(() async {
    await initTestAppEnv();
  });

  testWidgets('AdminConfigScreen renders loading state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const AdminConfigScreen()),
    );
    expect(find.byType(AdminConfigScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
