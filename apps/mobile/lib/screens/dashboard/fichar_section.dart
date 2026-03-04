// Fichar hero section (plan Step 11).

import 'package:flutter/material.dart';

import '../../core/device_capabilities.dart';
import '../../theme.dart';
import '../../theme/decorations.dart';
import '../../widgets/fichar_button.dart';
import '../../widgets/inline_error.dart';

class FicharSection extends StatelessWidget {
  const FicharSection({
    super.key,
    required this.theme,
    required this.lastLabel,
    required this.buttonLabel,
    required this.isEntrada,
    required this.loading,
    required this.dayLoading,
    required this.canFicharByGeo,
    this.geoMessage,
    this.geoOpenSettings = false,
    this.fichajeError,
    required this.onFichar,
    required this.onOpenLocationSettings,
  });

  final ThemeData theme;
  final String lastLabel;
  final String buttonLabel;
  final bool isEntrada;
  final bool loading;
  final bool dayLoading;
  final bool canFicharByGeo;
  final String? geoMessage;
  final bool geoOpenSettings;
  final String? fichajeError;
  final VoidCallback onFichar;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: kSpacingXl,
        horizontal: kSpacingLg,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: primaryShadow(
          isLowEnd: DeviceCapabilities.isLowEnd,
          color: theme.colorScheme.primary,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ultimo fichaje: $lastLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          FicharButton(
            onPressed: (loading || dayLoading || !canFicharByGeo) ? null : onFichar,
            loading: loading,
            backgroundColor: Colors.white,
            foregroundColor: theme.colorScheme.primary,
            semanticLabel: buttonLabel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!loading)
                  Icon(
                    isEntrada ? Icons.login : Icons.logout,
                    color: theme.colorScheme.primary,
                  ),
                if (!loading) const SizedBox(width: kSpacingSm),
                Text(buttonLabel),
              ],
            ),
          ),
          if (geoMessage != null) ...[
            const SizedBox(height: kSpacingMd),
            Text(
              geoMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            if (geoOpenSettings) ...[
              const SizedBox(height: kSpacingSm),
              TextButton.icon(
                onPressed: onOpenLocationSettings,
                icon: const Icon(Icons.settings, size: 18, color: Colors.white70),
                label: const Text('Configurar', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ],
          if (fichajeError != null) ...[
            const SizedBox(height: kSpacingMd),
            InlineError(message: fichajeError!),
          ],
        ],
      ),
    );
  }
}
