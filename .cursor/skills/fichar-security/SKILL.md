---
name: fichar-security
description: Security requirements for fichAR: hashing, RLS, audit logs, 2FA, sessions, encryption. Use for auth, permissions, data logging, or security-sensitive changes.
---

# fichAR Security

## When to Use

- Auth (login, 2FA, sessions, password reset)
- Permissions and RBAC
- RLS (Row Level Security)
- Audit logs
- Hash chain for fichajes
- Encryption (at rest, in transit)

## Source of Truth

- `definiciones/SEGURIDAD.md`
- `definiciones/FICHAR-DEFINICION-COMPLETA.md` (section 10)

## Inalterability (Legal Validity)

- **Hash chain**: SHA-256(concat(previous_hash, timestamp, user_id, tipo, ...)) with server pepper
- **No UPDATE** on fichaje records
- **No client-supplied hash** — server calculates
- **Corrections**: new record, referencia to original, justificación obligatoria

## Authentication

- **Passwords**: bcrypt (cost 12+) or Argon2id
- **2FA**: Obligatory for Admin (CFG-025), optional for employees (CFG-026)
- **Sessions**: JWT short exp (15min) + refresh; or session in DB (CFG-024)
- **Rate limit login**: 5 attempts / 5 min → block 15 min
- **Never reveal** if email exists (login, password reset)

## Authorization

- Check `can(role, action, resource)` per `definiciones/ROLES.md`
- RLS: `WHERE org_id = auth.jwt() ->> 'org_id'`
- 403 if unauthorized, 401 if unauthenticated

## Audit Logs

- **Table**: audit_logs, **INSERT only**, no UPDATE/DELETE
- **Fields**: timestamp, user_id, org_id, ip, user_agent, device_id, action, resource_type, resource_id, details, severity
- **Events**: login, login_failed, fichaje_creado, licencia_*, empleado_*, config_cambiada, acceso_denegado, etc.
- **Retention**: CFG-037 (default 3650 days)

## Encryption

- **Transit**: HTTPS, TLS 1.2+
- **At rest**: Supabase default
- **Offline data**: Encrypt before local storage

## Headers

- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Content-Security-Policy
- Referrer-Policy: strict-origin-when-cross-origin

## Idempotency

- Fichaje: idempotency key (user_id + date + tipo + timestamp)

## Pre-deploy Checklist

- [ ] Env vars configured (no dev defaults)
- [ ] HTTPS forced
- [ ] RLS on all multi-tenant tables
- [ ] Audit logs active
- [ ] Rate limit on login
- [ ] 2FA for Admin
- [ ] CORS restricted
