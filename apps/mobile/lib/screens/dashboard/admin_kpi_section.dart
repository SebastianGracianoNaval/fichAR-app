// Admin KPI section (plan Step 11).

import 'package:flutter/material.dart';

import '../../core/device_capabilities.dart';
import '../../theme.dart';
import '../../theme/decorations.dart';
import '../../theme/layout_tokens.dart';
import '../../widgets/inline_error.dart';
import '../../widgets/kpi_card.dart';
import '../../services/dashboard_api_service.dart';

const double _kpiAspectRatio = 0.92;

class AdminKpiSection extends StatelessWidget {
  const AdminKpiSection({
    super.key,
    required this.theme,
    required this.screenWidth,
    required this.loading,
    this.error,
    this.kpis,
    required this.onRetry,
  });

  final ThemeData theme;
  final double screenWidth;
  final bool loading;
  final String? error;
  final DashboardKpis? kpis;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return _buildSkeleton(context);
    if (error != null) return _buildError(context);
    if (kpis == null) return const SizedBox.shrink();
    return _buildCards(context, kpis!);
  }

  Widget _buildSkeleton(BuildContext context) {
    final crossAxisCount = screenWidth >= kBreakpointDesktop ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: _kpiAspectRatio,
      padding: EdgeInsets.zero,
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.all(kSpacingXs),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(kRadiusLg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: cardShadow(isLowEnd: DeviceCapabilities.isLowEnd),
      ),
      child: InlineError(
        message: error!,
        onRetry: onRetry,
        isLoading: false,
      ),
    );
  }

  Widget _buildCards(BuildContext context, DashboardKpis kpis) {
    final crossAxisCount = screenWidth >= kBreakpointDesktop ? 4 : 2;
    final cards = [
      KpiCard(
        icon: Icons.people,
        label: 'Empleados',
        value: kpis.totalEmpleados.toString(),
        color: theme.colorScheme.primary,
      ),
      KpiCard(
        icon: Icons.login,
        label: 'Fichados hoy',
        value: kpis.fichadosHoy.toString(),
        color: theme.colorScheme.primary,
      ),
      KpiCard(
        icon: Icons.warning,
        label: 'Alertas pendientes',
        value: kpis.alertasPendientes.toString(),
        color: theme.colorScheme.error,
      ),
      KpiCard(
        icon: Icons.medical_services,
        label: 'Licencias pendientes',
        value: kpis.licenciasPendientes.toString(),
        color: theme.colorScheme.tertiary,
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: _kpiAspectRatio,
      padding: EdgeInsets.zero,
      children: cards
          .map(
            (c) => Padding(
              padding: const EdgeInsets.all(kSpacingXs),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  boxShadow: cardShadow(isLowEnd: DeviceCapabilities.isLowEnd),
                ),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }
}
