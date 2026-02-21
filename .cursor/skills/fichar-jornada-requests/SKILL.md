---
name: fichar-jornada-requests
description: Bidirectional jornada requests (employee-supervisor). Intercambio, extra hours, rejection motive mandatory. Use when implementing or reviewing request flows, banco de horas, or intercambio.
---

# fichAR Jornada Requests

## When to Use

- Intercambio (employee or supervisor initiated)
- Request flows that affect banco de horas
- Approval/rejection UI with motive
- Alerts for banco limits

## Source of Truth

- `documentation/tecnica/request-flows-specification.md`
- `documentation/tecnica/solicitudes-ux-specification.md` (screens, notifications, alerts)
- `definiciones/LIMITACIONES-ALERTAS.txt`

## Golden Rules

1. **Rejection always requires motive.** Both directions. No rejection without reason.
2. **Bidirectional:** Employee can request. Supervisor can request. Approver must accept/reject.
3. **Configurable:** CFG-LIM-* for limits. Clear messages.

## Request Types

| Type | Initiator | Approver | Banco impact |
|------|-----------|----------|--------------|
| Intercambio (employee) | Employee | Supervisor | 0 |
| Intercambio (supervisor) | Supervisor | Employee | 0 |
| Extra hours (supervisor) | Supervisor | Employee | +hours |

## Banco Alerts

- banco_excedido: Over CFG-015. Notify supervisor (CFG-016).
- banco_proximo_limite: Warning at 80%.
- banco_negativo: Block if CFG-BH-003=false.
