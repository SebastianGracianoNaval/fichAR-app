---
name: fichar-test-e2e
description: E2E flows, Playwright, critical user paths. Use when adding or modifying E2E tests.
---

# fichAR Test E2E

## When to Use

- End-to-end tests
- Critical user flows (login, fichar, licencias)
- Playwright (web) or Flutter integration_test (mobile)

## Source of Truth

- `definiciones/TESTING-DOCUMENTACION.txt`

## Commands

```
bun run test:e2e
```

## Patterns

- Idempotent tests (clean data after)
- Use test data, not production
- Few but representative flows
- Critical paths: login → fichar; solicitar licencia → aprobar
