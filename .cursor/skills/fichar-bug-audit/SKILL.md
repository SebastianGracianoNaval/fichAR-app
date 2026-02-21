---
name: fichar-bug-audit
description: Audits a reported bug: hypothesis of cause, affected files, reproduction steps. Use when user reports a bug or test fails without obvious cause.
---

# fichAR Bug Audit

## When to Use

- User reports a bug
- Test fails and cause is unclear
- Unexpected behavior in production

## Output Format

Produce a structured audit:

1. **Hypothesis**: Most likely cause
2. **Affected files**: List with paths
3. **Reproduction steps**: Minimal steps to reproduce
4. **Related definitions**: CASOS-LIMITE, CONFIGURACIONES, etc.
5. **Suggested fix**: High-level approach

## Reference

- `clean_definitions/FICHAR-DEFINICION-COMPLETA.txt` (section 14: Bugs)
- `definiciones/CASOS-LIMITE.txt` for expected behavior

## Common Errors (from FICHAR-DEFINICION-COMPLETA)

| Error | Cause | Action |
|-------|-------|--------|
| Fichaje duplicado | Doble click | Idempotency key |
| "Fuera zona" erróneo | GPS impreciso | Aumentar tolerancia |
| Session expired | Timeout | Guardar draft, renovar |
| Export vacío | Filtros excluyen | Validar, mensaje claro |
| 403 inesperado | RLS/rol | Log, verificar org_id |
