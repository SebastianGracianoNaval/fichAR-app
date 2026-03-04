import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/invite_from_url.dart';
import 'core/recovery_from_url_flag.dart';
import 'screens/change_password_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mfa_enroll_screen.dart';
import 'screens/mfa_verify_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/auth_api_service.dart';
import 'theme.dart';
import 'widgets/auth_home_resolver.dart';

/// Routes that do not require an active Supabase session.
const _publicRoutes = {'/login', '/register', '/forgot-password', '/reset-password'};

Widget _guardRoute(BuildContext context, Widget child) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  return child;
}

class FicharApp extends StatelessWidget {
  const FicharApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fichAR',
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ficharTheme,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (hasInviteFromUrl) {
            return const RegisterScreen();
          }
          if (recoveryFromUrl) {
            setRecoveryFromUrl(false);
            return const ResetPasswordScreen();
          }
          final event = snapshot.data?.event;
          // P-AUTH-03: show reset-password when recovery link is processed
          if (event == AuthChangeEvent.passwordRecovery) {
            return const ResetPasswordScreen();
          }
          final session = snapshot.data?.session;
          if (session != null) {
            return const AuthHomeResolver();
          }
          return const LoginScreen();
        },
      ),
      onGenerateRoute: (settings) {
        final name = settings.name;
        if (name == null) return null;

        final builders = <String, Widget Function(BuildContext)>{
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/reset-password': (_) => const ResetPasswordScreen(),
          '/dashboard': (_) => const AuthHomeResolver(),
          '/mfa-enroll': (ctx) {
            final args = settings.arguments as MfaEnrollmentRequiredResult?;
            if (args == null) return const LoginScreen();
            return MfaEnrollScreen(
              refreshToken: args.refreshToken,
              message: args.message,
            );
          },
          '/mfa-verify': (ctx) {
            final args = settings.arguments as MfaVerificationRequiredResult?;
            if (args == null) return const LoginScreen();
            return MfaVerifyScreen(
              refreshToken: args.refreshToken,
              message: args.message,
            );
          },
          '/change-password': (ctx) {
            final args = settings.arguments as PasswordChangeRequiredResult?;
            return ChangePasswordScreen(
              refreshToken: args?.refreshToken ?? '',
            );
          },
          '/legal-audit': (_) => const AuthHomeResolver(),
        };

        final builder = builders[name];
        if (builder == null) return null;

        return MaterialPageRoute(
          settings: settings,
          builder: (ctx) {
            final child = builder(ctx);
            if (_publicRoutes.contains(name)) return child;
            return _guardRoute(ctx, child);
          },
        );
      },
    );
  }
}
