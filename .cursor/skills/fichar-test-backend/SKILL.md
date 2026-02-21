---
name: fichar-test-backend
description: Backend/API tests, mocks, fixtures. Use when adding or modifying backend tests.
---

# fichAR Test Backend

## When to Use

- Adding or modifying API tests
- Integration tests (Supabase, RLS)
- Domain logic tests

## Source of Truth

- `definiciones/TESTING-DOCUMENTACION.txt`

## Commands

```
bun test
bun test --coverage
bun run test:integration
```

## Patterns

- **Mocks** for Supabase client
- **Fixtures** for test data
- **Fake timers** for date-dependent logic
- Reference **CASOS-LIMITE** for edge cases

## Coverage Target

> 80% in critical domain (fichaje, banco horas, descansos)
