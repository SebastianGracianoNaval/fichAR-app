---
name: fichar-flutter
description: Flutter 3.x for mobile, web, and desktop. Widgets, state, navigation, theming. Use for Flutter code changes.
---

# fichAR Flutter

## When to Use

- Flutter UI (mobile, web, desktop)
- Widgets, screens, navigation
- State management
- Theming and palettes

## Source of Truth

- `definiciones/FRONTEND.txt`
- `definiciones/PANTALLAS.txt`
- `definiciones/COMPONENTES-FLUTTER.txt` (if exists)

## Structure

```
apps/
├── mobile/   # Flutter iOS + Android
├── web/      # Flutter Web
└── desktop/  # Tauri wrapper
packages/
└── ui-kit/   # Shared Flutter components
```

## Look & Feel (Duolingo-style)

- Large rounded buttons (border-radius 12–16px)
- **Fichar button**: min 56px touch target
- Feedback &lt; 100ms (haptic + visual)
- Sans-serif: Roboto (Android), SF Pro (iOS)

## Palettes (CFG-042)

**Profesional (default):** #1E3A5F, #4A90D9, #00C853, #F5F7FA

**Fresco:** #58CC02, #1CB0F6, #FF4B4B

**Neutro:** #424242, #757575, #009688

## Critical Patterns

1. **const** constructors where possible
2. **ListView.builder** for long lists (not ListView of direct children)
3. **Keys** stable in lists
4. **RepaintBoundary** for isolated repaints
5. **60 FPS target** — avoid heavy animations on low-end

## Low-end vs High-end

- Detect: API &lt; 24, mem &lt; 2GB → low-end mode
- Low-end: no complex animations, fewer effects, simpler geofencing
- High-end: animations, haptics, sounds, skeleton loaders

## UX Feedback (Duolingo-Style)

- Feedback under 100ms on tap
- Haptic on fichar, accept, reject
- Sound on success (configurable)
- Celebrations (confetti) on fichaje, high-end only
- See: documentation/tecnica/ux-feedback-guide.md
