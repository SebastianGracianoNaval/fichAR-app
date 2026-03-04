// Nav grid card for dashboard (plan Step 11).

import 'package:flutter/material.dart';

import '../core/device_capabilities.dart';
import '../theme.dart';
import '../theme/decorations.dart';

class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  static const double _iconSize = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: cardShadow(isLowEnd: DeviceCapabilities.isLowEnd),
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: title,
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacingSm,
                  vertical: kSpacingMd,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(
                    icon,
                    size: _iconSize,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: kSpacingSm),
                  Tooltip(
                    message: title,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
