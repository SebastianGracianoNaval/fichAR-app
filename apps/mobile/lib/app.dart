import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/dashboard_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mfa_enroll_screen.dart';
import 'screens/mfa_verify_screen.dart';
import 'services/auth_api_service.dart';
import 'theme.dart';
import 'widgets/auth_home_resolver.dart';

class FicharApp extends StatelessWidget {
  const FicharApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fichAR',
      theme: ficharTheme,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = snapshot.data?.session;
          if (session != null) {
            return const AuthHomeResolver();
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/mfa-enroll': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments as MfaEnrollmentRequiredResult?;
          if (args == null) return const LoginScreen();
          return MfaEnrollScreen(refreshToken: args.refreshToken, message: args.message);
        },
        '/mfa-verify': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments as MfaVerificationRequiredResult?;
          if (args == null) return const LoginScreen();
          return MfaVerifyScreen(refreshToken: args.refreshToken, message: args.message);
        },
        '/legal-audit': (_) => const AuthHomeResolver(),
      },
    );
  }
}
