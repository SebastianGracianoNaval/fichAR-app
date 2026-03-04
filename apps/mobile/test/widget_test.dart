import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/screens/login_screen.dart';
import 'package:fichar_mobile/theme.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const LoginScreen()),
    );

    expect(find.text('fichAR'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Login shows error for invalid email', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ficharTheme, home: const LoginScreen()),
    );

    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Email inválido'), findsOneWidget);
  });
}
