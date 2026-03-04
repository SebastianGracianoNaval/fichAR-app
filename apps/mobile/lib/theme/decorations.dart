// Shared box shadows for dashboard and cards (plan Step 11).
// Reference: definiciones/FRONTEND.md, low-end mode in DeviceCapabilities.

import 'package:flutter/material.dart';

/// Card/surface shadow used in day summary, KPI cards, nav cards.
/// Returns null when [isLowEnd] to avoid overdraw on low-end devices.
List<BoxShadow>? cardShadow({required bool isLowEnd}) {
  if (isLowEnd) return null;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Primary (hero/fichar section) shadow.
/// Returns null when [isLowEnd].
List<BoxShadow>? primaryShadow({
  required bool isLowEnd,
  required Color color,
}) {
  if (isLowEnd) return null;
  return [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];
}
