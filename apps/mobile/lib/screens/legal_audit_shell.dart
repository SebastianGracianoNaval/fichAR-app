import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'legal_audit_dashboard_screen.dart';
import 'legal_audit_hash_chain_screen.dart';
import 'legal_audit_logs_screen.dart';

class LegalAuditShell extends StatelessWidget {
  const LegalAuditShell({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
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
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context),
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
