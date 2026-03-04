// KPI card for admin dashboard (plan Step 11).

import 'package:flutter/material.dart';

import '../theme.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  static const double _iconSize = 24;
  static const double _valueFontSize = 20;
  static const double _labelFontSize = 12;
  static const double _verticalGap = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(kSpacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize, color: color),
          const SizedBox(height: _verticalGap),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: _valueFontSize,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Tooltip(
            message: label,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: _labelFontSize,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
