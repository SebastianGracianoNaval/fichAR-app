// Dashboard scrollable body (plan Step 11).

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/responsive_content_wrapper.dart';
import 'dashboard_controller.dart';
import 'fichar_section.dart';
import 'day_summary.dart';
import 'admin_kpi_section.dart';
import 'nav_grid.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.controller,
    required this.role,
    required this.navItems,
    required this.onOpenLocationSettings,
  });

  final DashboardController controller;
  final String role;
  final List<NavGridItem> navItems;
  final Future<void> Function() onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final isEntrada = c.nextTipo == 'entrada';
    final buttonLabel = c.fichajeLoading ? 'Registrando...' : (isEntrada ? 'FICHAR ENTRADA' : 'FICHAR SALIDA');
    final lastLabel = c.lastFichaje != null
        ? '${c.lastFichaje!.tipo == 'entrada' ? 'Entrada' : 'Salida'} ${DashboardController.formatTime(c.lastFichaje!.timestampServidor)}'
        : 'Sin fichajes';
    final entradaHoy = c.lastFichaje?.tipo == 'entrada'
        ? DashboardController.formatTime(c.lastFichaje!.timestampServidor)
        : c.lastFichaje != null
            ? DashboardController.formatTime(c.lastFichaje!.timestampServidor)
            : '--:--';

    return RefreshIndicator(
      onRefresh: () async {
        if (c.isEmployee) await c.loadDayData();
        if (role == 'admin') await c.loadKpis();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ResponsiveContentWrapper(
          width: ContentWidth.dashboard,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpacingMd),
            child: LayoutBuilder(
              builder: (context, _) {
                final width = MediaQuery.sizeOf(context).width;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.orgName != null && c.orgName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: kSpacingMd),
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Bienvenido a ${c.orgName}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (c.profileIncomplete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: kSpacingMd),
                        child: Text(
                          'Faltan datos a completar',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    if (c.isEmployee) ...[
                      FicharSection(
                        theme: theme,
                        lastLabel: lastLabel,
                        buttonLabel: buttonLabel,
                        isEntrada: isEntrada,
                        loading: c.fichajeLoading,
                        dayLoading: c.dayLoading,
                        canFicharByGeo: c.canFicharByGeo,
                        geoMessage: c.geoMessage,
                        geoOpenSettings: c.geoOpenSettings,
                        fichajeError: c.fichajeError,
                        onFichar: c.fichar,
                        onOpenLocationSettings: onOpenLocationSettings,
                      ),
                      const SizedBox(height: kSpacingMd),
                      DaySummary(
                        theme: theme,
                        loading: c.dayLoading,
                        entradaHoy: entradaHoy,
                        saldoHoras: c.saldoHoras,
                      ),
                      const SizedBox(height: kSpacingLg),
                    ],
                    if (role == 'admin') ...[
                      AdminKpiSection(
                        theme: theme,
                        screenWidth: width,
                        loading: c.kpisLoading,
                        error: c.kpisError,
                        kpis: c.kpis,
                        onRetry: c.loadKpis,
                      ),
                      const SizedBox(height: kSpacingLg),
                    ],
                    NavGrid(screenWidth: width, items: navItems),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
