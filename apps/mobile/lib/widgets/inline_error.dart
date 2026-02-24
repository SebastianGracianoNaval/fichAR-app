// Inline error display (plan-phase-1, mocks 01-login)
// Icon + text, Semantics for screen readers.

import 'package:flutter/material.dart';

import '../theme.dart';

class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.isLoading = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpacingMd, vertical: 12),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 24, color: errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: errorColor,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: kSpacingSm),
                  TextButton(
                    onPressed: isLoading ? null : onRetry,
                    child: Text(isLoading ? 'Reintentando...' : 'Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(liveRegion: true, label: message, child: content);
  }
}
