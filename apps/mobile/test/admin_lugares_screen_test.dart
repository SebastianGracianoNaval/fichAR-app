import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/admin_lugares_screen.dart';
import 'package:fichar_mobile/theme.dart';
import 'package:fichar_mobile/widgets/responsive_content_wrapper.dart';
import 'test_app_setup.dart';

void main() {
  setUpAll(() async {
    await initTestAppEnv();
  });

  testWidgets(
    'AdminLugaresScreen renders loading with ResponsiveContentWrapper',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ficharTheme, home: const AdminLugaresScreen()),
      );
      expect(find.byType(AdminLugaresScreen), findsOneWidget);
      expect(find.byType(ResponsiveContentWrapper), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );
}
