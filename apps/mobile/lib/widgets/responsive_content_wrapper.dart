// Responsive content wrapper (plan-phase-1, 00-deep-analysis)
// Constrains width, applies padding by breakpoint. Parent handles safe area.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../theme/layout_tokens.dart';

enum ContentWidth { form, formWide, list, dashboard }

class ResponsiveContentWrapper extends StatelessWidget {
  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.width = ContentWidth.form,
  });

  final Widget child;
  final ContentWidth width;

  @override
  Widget build(BuildContext context) {
    final maxW = switch (width) {
      ContentWidth.form => kContentMaxWidthForm,
      ContentWidth.formWide => kContentMaxWidthFormWide,
      ContentWidth.list => kContentMaxWidthList,
      ContentWidth.dashboard => kContentMaxWidthDashboard,
    };
    final padding = MediaQuery.sizeOf(context).width >= kBreakpointTablet
        ? kSpacingLg
        : kSpacingMd;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: child,
        ),
      ),
    );
  }
}
