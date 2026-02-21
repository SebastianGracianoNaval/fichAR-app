import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/login_screen.dart';
import 'package:fichar_mobile/theme.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ficharTheme,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('fichAR'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
  });
}
