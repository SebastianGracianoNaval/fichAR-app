---
name: fichar-performance
description: Low battery usage, threading, efficient geofencing, low-end mode. Use for performance and background tasks.
---

# fichAR Performance

## When to Use

- Battery optimization
- Background sync
- Geofencing efficiency
- Threading / isolates

## Source of Truth

- `definiciones/OPTIMIZACION.txt`
- `definiciones/OPTIMIZACION-RECURSOS-RED.txt`

## Principles

- Minimal battery consumption
- 60 FPS target
- Light background processes
- Avoid heavy work on low-end devices

## Geofencing

- Polling 30–60s (low-end), 15s (high-end)
- Disable when app closed if not needed
- Reduce when battery &lt; 15%

## Network

- Prefer WiFi for sync (CFG-NET-001)
- Batch requests; avoid frequent small calls
- gzip responses
