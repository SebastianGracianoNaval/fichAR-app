---
name: fichar-bug-fix
description: Implements minimal fix. Includes test that reproduces bug and verifies fix. Use after hypothesis confirmed or obvious fix.
---

# fichAR Bug Fix

## When to Use

- After fichar-bug-audit hypothesis is confirmed
- When fix is obvious
- Implementing correction for known bug

## Requirements

1. **Minimal change** — fix only what's broken
2. **Test** — add or update test that:
   - Reproduces the bug (fails before fix)
   - Verifies fix (passes after fix)
3. **Reference** — comment linking to CASOS-LIMITE if applicable

## Pattern

```dart
// Regla: CASOS-LIMITE CL-025 — debounce + idempotency
```
