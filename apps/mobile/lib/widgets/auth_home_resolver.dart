import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/legal_audit_shell.dart';
import '../services/me_api_service.dart';

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
    setState(() {
      _me = result.result;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _me == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _fetchMe, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_me == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_me!.role == 'legal_auditor') {
      return const LegalAuditShell();
    }

    return const DashboardScreen();
  }
}
