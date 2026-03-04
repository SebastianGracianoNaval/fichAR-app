// Day summary section (plan Step 11).

import 'package:flutter/material.dart';

import '../../core/device_capabilities.dart';
import '../../core/org_config_provider.dart';
import '../../theme.dart';
import '../../theme/decorations.dart';
import '../../widgets/summary_chip.dart';

class DaySummary extends StatelessWidget {
  const DaySummary({
    super.key,
    required this.theme,
    required this.loading,
    required this.entradaHoy,
    required this.saldoHoras,
  });

  final ThemeData theme;
  final bool loading;
  final String entradaHoy;
  final double? saldoHoras;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(kSpacingLg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(kRadiusXl),
          boxShadow: cardShadow(isLowEnd: DeviceCapabilities.isLowEnd),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(kSpacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: cardShadow(isLowEnd: DeviceCapabilities.isLowEnd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen del dia', style: theme.textTheme.titleMedium),
          const SizedBox(height: kSpacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: SummaryChip(
                  icon: Icons.access_time,
                  label: 'Ultimo fichaje',
                  value: entradaHoy,
                ),
              ),
              if (OrgConfigProvider.bancoHorasHabilitado)
                Expanded(
                  child: SummaryChip(
                    icon: Icons.account_balance_wallet,
                    label: 'Banco',
                    value: '${saldoHoras?.toStringAsFixed(1) ?? '0'} h',
                    color: (saldoHoras ?? 0) >= 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
