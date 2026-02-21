# fichAR — Alineación con ISO/IEC 27001:2022

**Declaración:** fichAR está diseñado bajo estándares ISO 27001. Este documento describe la alineación con los controles del Anexo A de ISO/IEC 27001:2022. No constituye certificación (que requiere auditoría externa acreditada).

---

## Alcance

- **Backend API:** Bun/TypeScript, endpoints REST, autenticación, audit logs
- **Flutter:** mobile, web (futuro)
- **Infraestructura:** Supabase (PostgreSQL, Auth, RLS)

---

## Mapeo de Controles

| Control ISO | Descripción | Implementación fichAR | Evidencia |
|-------------|-------------|------------------------|-----------|
| **A.5.1** | Políticas para la seguridad de la información | definiciones/SEGURIDAD.txt, ROLES.txt, CONFIGURACIONES.txt | Documentación centralizada |
| **A.5.2** | Roles y responsabilidades | RLS, RBAC (admin, supervisor, empleado, auditor, legal_auditor) | employees.role, políticas RLS |
| **A.8.2** | Privileged access rights | Menor privilegio: cada rol solo accede a lo necesario. RLS por org_id | Migraciones, auth-middleware |
| **A.8.3** | Información en medios | No PII en logs; sanitizeDetails (password, token, secret, cuil) | logger.ts |
| **A.8.5** | Secure authentication | 2FA Admin (CFG-025), rate limit login, bcrypt (Supabase), validadores | auth.ts, rate-limit.ts |
| **A.8.9** | Configuration management | org_configs, CFG-* por organización | org_configs table |
| **A.8.10** | Information deletion | audit_logs inmutable; retención CFG-037 (10 años) | definiciones/CONFIGURACIONES.txt, migraciones |
| **A.8.15** | Logging | audit_logs: login, login_failed, rate_limit, fichaje_creado, legal_export | logger.ts, auth.ts, fichajes.ts |
| **A.8.16** | Monitoring activities | Rate limit, intentos fallidos, exportaciones legales registradas | rate-limit.ts, legal.ts |
| **A.8.24** | Use of cryptography | Hash chain SHA-256, HASH_PEPPER, JWT (Supabase) | fichaje-hash.ts, definiciones/SEGURIDAD.txt |
| **A.8.25** | Secure development lifecycle | AGENTS.md: plan → review → implement. Skills fichar-security, fichar-legal-compliance | AGENTS.md, plans/ |
| **A.8.28** | Secure coding | Validación entrada, sanitización, RLS, sin UPDATE/DELETE fichajes | validators.ts, migraciones |

---

## Exclusiones (no aplicables)

- Controles físicos de datacenter (Supabase como proveedor)
- Controles de recursos humanos (gestión interna del equipo)
- Gestión de incidentes formal (fuera de alcance MVP)

---

## Próximos pasos para certificación

1. Política de seguridad de la información formal (documento ejecutivo)
2. Procedimientos documentados (cambio, acceso, incidentes)
3. Auditoría interna antes de auditoría externa
4. Selección de organismo certificador acreditado

---

## Uso en comunicación

- **Correcto:** "fichAR está diseñado bajo estándares ISO 27001"
- **Incorrecto:** "fichAR está certificado ISO 27001" (hasta tener certificación)
