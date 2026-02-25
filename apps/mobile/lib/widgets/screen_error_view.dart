// Full-screen or section-level error: message + primary action (Plan 01 improve_points).
// Use for network/API errors so the user is never stuck without an action.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'responsive_content_wrapper.dart';

class ScreenErrorView extends StatelessWidget {
  const ScreenErrorView({
    super.key,
    required this.message,
    this.subtitle,
    required this.onAction,
    this.actionLabel = 'Reintentar',
    this.contentWidth = ContentWidth.formWide,
  });

  final String message;
  final String? subtitle;
  final VoidCallback onAction;
  final String actionLabel;
  final ContentWidth contentWidth;

  static const String genericLoadError =
      'No se pudieron cargar los datos. Revisá tu conexión e intentá de nuevo.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: errorColor),
          const SizedBox(height: kSpacingLg),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: errorColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: kSpacingSm),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: kSpacingLg),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text(actionLabel),
          ),
        ],
      ),
    );

    return ResponsiveContentWrapper(
      width: contentWidth,
      child: Center(child: content),
    );
  }
}
