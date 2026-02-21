---
name: fichar-plan-review
description: Reviews plans against fichAR pillars: security, optimization, speed. Use before approving or implementing any plan to ensure alignment with project standards.
---

# fichAR Plan Review

## When to Use

- Before approving a plan in `plans/`
- Before merging feature branches
- When creating or updating implementation plans

## Pillars Checklist

Every plan MUST address these pillars:

### 1. Integration

- [ ] Old software: CSV, Excel, encoding (Latin1), adapters
- [ ] New software: Webhooks, REST API, n8n/Zapier
- [ ] Minimal development: Abstract external formats; core does not depend on Jira, SAP, etc.
- [ ] Versioned APIs (/v1/), no breaking contracts

### 2. Security

- [ ] Auth: 2FA for Admin, rate limit on login, secure session handling
- [ ] Data: RLS on all org-scoped tables, org_id in queries
- [ ] Fichaje: Hash chain (SHA-256), no direct UPDATE, corrections = new record
- [ ] Audit: Critical actions logged (who, when, what)
- [ ] Input: Validation on backend, never trust client

### 3. Optimization

- [ ] Performance: 60 FPS target, no heavy work on main thread
- [ ] Battery: Geofencing frequency, background sync batching
- [ ] Network: Prefer WiFi for sync (CFG-NET-001), batch requests
- [ ] Memory: ListView.builder, const, keys, avoid leaks

### 4. Speed

- [ ] Response: Critical paths under 100ms feedback
- [ ] Build: Lazy loading, code splitting where applicable
- [ ] Database: Indexes on org_id, user_id, fecha
- [ ] Offline: Local storage for critical flows, sync when connected

### 5. UX (solicitudes, dashboard, alerts)

- [ ] Supervisor: panel with notifications, solicitudes cards, alertas
- [ ] Employee: banco widget, horas por dia, "Proponer compensacion"
- [ ] Alerts: "Ayer no trackeaste", proximo fichaje, solicitud pendiente
- [ ] Rejection modal: motivo obligatorio, both directions
- [ ] Duolingo-style: haptics, sounds, feedback under 100ms

## Review Output

Produce: PASS / REVISE with specific gaps. If REVISE, list missing checklist items.

## Reference

- `definiciones/SEGURIDAD.txt`
- `definiciones/INTEGRACIONES.txt`
- `definiciones/OPTIMIZACION.txt`
- `documentation/tecnica/request-flows-specification.md`
- `documentation/tecnica/solicitudes-ux-specification.md`
