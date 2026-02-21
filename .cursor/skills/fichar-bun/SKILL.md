---
name: fichar-bun
description: Bun as runtime and package manager. Scripts, tests, tooling. Use for scripts, package.json, Bun-specific code.
---

# fichAR Bun

## When to Use

- package.json scripts
- Bun scripts (deploy, seed, etc.)
- Tests (bun test)
- Runtime for API (if Node/Bun chosen over Go)

## Commands (from definiciones)

```json
{
  "dev": "bun run server.ts",
  "dev:mobile": "cd apps/mobile && flutter run",
  "dev:web": "cd apps/web && flutter run -d chrome",
  "test": "bun test",
  "test:e2e": "bun run test:e2e",
  "db:migrate": "supabase db push",
  "lint": "bun run lint:api && cd apps/mobile && flutter analyze"
}
```
