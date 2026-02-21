---
name: fichar-low-end
description: Old devices: fewer animations, tolerant geofencing. Use for optimization targeting Android 5, iOS 12.
---

# fichAR Low-end

## When to Use

- Supporting Android 5 (API 21), iOS 12
- Devices with &lt; 2GB RAM
- Reducing animations, effects

## Detection

- API level &lt; 24 (Android) OR iOS &lt; 14 OR memory &lt; 2GB

## Characteristics

- No complex animations (basic fade only)
- No confetti/celebrations
- No or minimal sounds
- Geofencing: polling 30–60s
- No heavy image preload
- Solid colors, no heavy gradients
- Slightly larger font for small screens
