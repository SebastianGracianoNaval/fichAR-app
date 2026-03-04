import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/org_config_provider.dart';
import '../screens/change_password_screen.dart';
import '../theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/legal_audit_shell.dart';
import '../services/me_api_service.dart';
import '../services/sign_out_service.dart';

class AuthHomeResolver extends StatefulWidget {
  const AuthHomeResolver({super.key});

  @override
  State<AuthHomeResolver> createState() => _AuthHomeResolverState();
}

class _AuthHomeResolverState extends State<AuthHomeResolver> {
  MeResult? _me;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMe();
  }

  Future<void> _fetchMe() async {
    final result = await MeApiService.getMe();
    if (!mounted) return;
    if (result.error != null || result.result == null) {
      setState(() {
        _me = result.result;
        _error = result.error;
      });
      return;
    }
    await OrgConfigProvider.load();
    if (!mounted) return;
    setState(() {
      _me = result.result;
      _error = result.error;
    });
  }

  static bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _mobileNotPermitted =>
      _me != null &&
      _error == null &&
      _isMobilePlatform &&
      !OrgConfigProvider.appMobileHabilitada;

  Future<void> _signOut() async {
    OrgConfigProvider.clear();
    clearFicharThemeCache();
    await SignOutService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = getFicharThemeFromConfig();

    Widget content;
    if (_error == MeApiService.sessionExpiredError && _me == null) {
      content = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tu sesión expiró.',
                  style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Volvé a iniciar sesión para continuar.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_error != null && _me == null) {
      content = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _fetchMe,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_me == null) {
      content = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (_mobileNotPermitted) {
      content = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tu empleador no permite fichar desde el celular.',
                  style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Usá la app web o de escritorio en una PC de trabajo.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_me!.requiresPasswordChange) {
      final refreshToken =
          Supabase.instance.client.auth.currentSession?.refreshToken ?? '';
      content = ChangePasswordScreen(refreshToken: refreshToken);
    } else if (_me!.role == 'integrity_viewer') {
      content = const LegalAuditShell();
    } else {
      content = DashboardScreen(role: _me!.role);
    }

    return Theme(data: theme, child: content);
  }
}
