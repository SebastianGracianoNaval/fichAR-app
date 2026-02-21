---
name: fichar-go
description: Go backend: endpoints, goroutines, validation. Use for Go API code.
---

# fichAR Go

## When to Use

- API endpoints (REST)
- Business logic
- Validation
- Goroutines for I/O

## Source of Truth

- `definiciones/ARQUITECTURA-TECNICA.txt`
- `definiciones/API-CONTRACTS.txt` (if exists)

## Structure

```
packages/api/
├── src/
│   ├── routes/
│   ├── services/
│   ├── middleware/
│   └── lib/
└── package.json
```

## Patterns

- **Versioned routes:** /api/v1/
- **Goroutines:** Use for parallel I/O; avoid unlimited; worker pools for heavy work
- **Validation:** Backend always; never trust frontend
- **Idempotency:** Fichaje with idempotency key
