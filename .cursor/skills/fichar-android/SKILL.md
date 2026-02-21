---
name: fichar-android
description: Android API 21+, WorkManager, geofencing, low-end optimization. Use for Android-specific app changes.
---

# fichAR Android

## When to Use

- Android build, permissions
- WorkManager for background sync
- Geofencing (Fused Location Provider)
- Low-end device optimization (API 21+)

## Source of Truth

- `definiciones/OPTIMIZACION.txt`
- `definiciones/FRONTEND.txt` (low-end mode)

## Compatibility

- **minSdk:** 21 (Android 5.0)
- **targetSdk:** 34

## Geofencing

- **Fused Location Provider** — not continuous GPS
- Polling: 30–60s low-end, 15s high-end
- Reduce when battery &lt; 15% (CL-024)

## WorkManager

- Minimal frequency
- Short tasks: sync pending fichajes only
- Batch operations to reduce wakeups
- NetworkType.UNMETERED for sync (prefer WiFi per CFG-NET-001)

## Haptics

- HapticFeedbackConstants for button feedback

## Low-end (API &lt; 24, mem &lt; 2GB)

- Fewer animations
- Tolerant geofencing (30–60s polling)
- No preload of heavy images
