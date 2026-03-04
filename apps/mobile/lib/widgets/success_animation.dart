// Success feedback overlay: check + optional bounce (plan Step 13, ux-feedback-guide).
// High-end only animation; respects MediaQuery.disableAnimations.

import 'package:flutter/material.dart';

import '../core/device_capabilities.dart';

/// Full-screen overlay showing a checkmark with optional scale/bounce.
/// Use after successful fichar. Respects [MediaQuery.disableAnimations] and [DeviceCapabilities].
class SuccessOverlay extends StatelessWidget {
  const SuccessOverlay({
    super.key,
    required this.visible,
    this.backgroundColor,
    this.iconColor,
  });

  final bool visible;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final useAnimation =
        !disableAnimations && !DeviceCapabilities.isLowEnd && DeviceCapabilities.hasAnimations;

    final bg = backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.85);
    final color = iconColor ?? theme.colorScheme.onPrimary;

    Widget content = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, size: 44, color: color),
    );

    if (useAnimation) {
      content = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: child,
        ),
        child: content,
      );
    }

    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
