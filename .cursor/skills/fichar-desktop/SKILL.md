---
name: fichar-desktop
description: Tauri or Electron for Windows 10+, macOS 10.14+, Linux. Use for desktop app.
---

# fichAR Desktop

## When to Use

- Desktop wrapper (Tauri/Electron)
- Cross-platform builds
- Installers (.exe, .dmg, .deb)

## Source of Truth

- `definiciones/ARQUITECTURA-TECNICA.md`
- `definiciones/OPTIMIZACION.md`

## Recommendation: Tauri

- **Size:** 2–10 MB vs 80–150 MB (Electron)
- **RAM idle:** 30–50 MB vs 150–300 MB
- **Startup:** 0.3–1 s vs 1–3 s

## Platforms

| OS | Version |
|----|---------|
| Windows | 10+ |
| macOS | 10.14+ |
| Linux | Ubuntu 18.04+ / Debian 10+ |

## UI

- Native window, not fullscreen by default
- Menu/title bar per OS
- Keyboard shortcuts for power users
