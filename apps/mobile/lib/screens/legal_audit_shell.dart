import 'package:flutter/material.dart';

import '../core/org_config_provider.dart';
import '../services/sign_out_service.dart';
import '../theme.dart';
import 'legal_audit_dashboard_screen.dart';
import 'legal_audit_hash_chain_screen.dart';
import 'legal_audit_logs_screen.dart';

class LegalAuditShell extends StatefulWidget {
  const LegalAuditShell({super.key});

  @override
  State<LegalAuditShell> createState() => _LegalAuditShellState();
}

class _LegalAuditShellState extends State<LegalAuditShell> {
  bool _signingOut = false;

  Future<void> _signOut(BuildContext context) async {
    if (_signingOut) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _signingOut = true);
    OrgConfigProvider.clear();
    clearFicharThemeCache();
    final result = await SignOutService.signOutDetailed();
    if (!mounted) return;
    setState(() => _signingOut = false);
    if (result.wasLocal) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Sesión cerrada localmente. Si tenés problemas, volvé a iniciar sesión.',
          ),
        ),
      );
    }
    if (result.signedOut) {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Integridad de Datos'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Extracción'),
              Tab(icon: Icon(Icons.list_alt), text: 'Logs'),
              Tab(icon: Icon(Icons.link), text: 'Cadena Hashes'),
            ],
          ),
          actions: [
            IconButton(
              icon: _signingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              onPressed: _signingOut ? null : () => _signOut(context),
              tooltip: 'Cerrar sesión',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                'Modo solo lectura. Veedor de integridad.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  LegalAuditDashboardScreen(),
                  LegalAuditLogsScreen(),
                  LegalAuditHashChainScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
