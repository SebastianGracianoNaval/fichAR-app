---
name: fichar-test-frontend
description: Flutter widget tests, integration tests. Use when adding or modifying frontend tests.
---

# fichAR Test Frontend

## When to Use

- Flutter widget tests
- Integration tests (apps/mobile)
- UI component tests

## Source of Truth

- `definiciones/TESTING-DOCUMENTACION.md`
- `definiciones/PANTALLAS.md`

## Commands

```
cd apps/mobile && flutter test
flutter test --coverage
```

## Patterns

- Widget tests for isolated components
- Golden tests for critical UI
- integration_test for flows
- Reference PANTALLAS for states and messages
