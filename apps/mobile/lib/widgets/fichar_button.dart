// Duolingo-style CTA button (plan-refactor-frontend, definiciones/FRONTEND.md).
// Border bottom 4px darker, scale on press when hasAnimations.
// Reference: .cursor/skills/flutter-animations, documentation/tecnica/ux-feedback-guide.md

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/device_capabilities.dart';
import '../theme.dart';

enum FicharButtonVariant { primary, secondary }

class FicharButton extends StatefulWidget {
  const FicharButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loading = false,
    this.variant = FicharButtonVariant.primary,
    this.backgroundColor,
    this.foregroundColor,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool loading;
  final FicharButtonVariant variant;

  /// Override color (e.g. tertiary for "Fichar salida").
  final Color? backgroundColor;

  /// Override text/icon color (e.g. for hero inverted: white bg, primary text).
  final Color? foregroundColor;

  /// Accessibility label for screen readers.
  final String? semanticLabel;

  @override
  State<FicharButton> createState() => _FicharButtonState();
}

class _FicharButtonState extends State<FicharButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(duration: kAnimFast, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (DeviceCapabilities.hasAnimations &&
        !MediaQuery.of(context).disableAnimations &&
        widget.onPressed != null &&
        !widget.loading) {
      _scaleController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  void _onTap() {
    if (DeviceCapabilities.hasHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.loading;
    final fgColor =
        widget.foregroundColor ??
        (isEnabled
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant);
    final bgColor =
        widget.backgroundColor ??
        (widget.variant == FicharButtonVariant.primary
            ? theme.colorScheme.primary
            : theme.colorScheme.tertiary);
    final borderColor = Color.lerp(bgColor, Colors.black, 0.25) ?? bgColor;

    Widget content = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        if (!DeviceCapabilities.hasAnimations ||
            MediaQuery.of(context).disableAnimations) {
          return child!;
        }
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: Container(
        width: double.infinity,
        height: kTouchTargetMin,
        decoration: BoxDecoration(
          color: isEnabled
              ? bgColor
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border(
            bottom: BorderSide(
              color: isEnabled ? borderColor : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? _onTap : null,
            onTapDown: isEnabled ? _onTapDown : null,
            onTapUp: isEnabled ? _onTapUp : null,
            onTapCancel: isEnabled ? _onTapCancel : null,
            borderRadius: BorderRadius.circular(kRadiusLg),
            child: Center(
              child: widget.loading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                  : DefaultTextStyle(
                      style: (theme.textTheme.labelLarge ??
                              const TextStyle(fontSize: 16))
                          .copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.bold,
                      ),
                      child: widget.child,
                    ),
            ),
          ),
        ),
      ),
    );

    if (widget.semanticLabel != null) {
      return Semantics(
        label: widget.semanticLabel,
        button: true,
        child: content,
      );
    }
    return content;
  }
}
