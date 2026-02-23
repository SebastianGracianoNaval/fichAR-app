# fichAR - UX Feedback Guide (Duolingo-Style)

**Reference:** definiciones/FRONTEND.md §2.3, plan-refactor-frontend.md

---

## 1. Principles

- **Immediate feedback:** < 100ms on tap. User must feel the app responded.
- **Multi-sensory:** Visual + Haptic (+ Sound when enabled).
- **Graceful degradation:** Low-end devices skip heavy effects; structure remains.

---

## 2. Haptics

| Action | Feedback | When |
|--------|----------|------|
| Fichar success | `HapticFeedback.mediumImpact()` | After successful fichaje |
| Primary button tap | `HapticFeedback.lightImpact()` | On FicharButton, FAB |
| Error / reject | `HapticFeedback.heavyImpact()` | When action fails |
| Tab / nav | `HapticFeedback.selectionClick()` | Bottom nav, tab bar |

**Condition:** Only when `DeviceCapabilities.hasHaptics` (false on low-end).

---

## 3. Sounds

| Event | Sound | Config |
|-------|-------|--------|
| Fichaje success | Short chime (< 0.5s) | CFG-* (org), default off on low-end |
| Error | Soft error tone | Optional |
| Button tap | None (avoid annoyance) | - |

**Condition:** `DeviceCapabilities.canPlaySounds` and org config enabled.

---

## 4. Visual Feedback

| Element | Feedback |
|---------|----------|
| Button press | Scale to 0.98 for 100ms |
| Fichar success | Bounce or check animation (high-end) |
| Loading | Skeleton or spinner; never block UI |
| Error | Red border + message below field |

**Animation duration:** 150-300ms. Curves: `Curves.easeOut` for press, `Curves.elasticOut` for success (optional).

---

## 5. Micro-copy (Success Messages)

- Fichaje entrada: "Fichaste entrada"
- Fichaje salida: "Fichaste salida"
- Licencia aprobada: "Licencia aprobada"
- Error: Specific, actionable. Never generic "Error".

---

## 6. Implementation Checklist

- [ ] HapticFeedback on all primary actions
- [ ] Scale animation on FicharButton (when hasAnimations)
- [ ] Optional success sound (configurable)
- [ ] Respect MediaQuery.disableAnimations
- [ ] Respect DeviceCapabilities.isLowEnd
