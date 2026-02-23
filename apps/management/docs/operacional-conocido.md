# fichar-management: conocimientos operativos

Documento de referencia para incidencias conocidas y decisiones de diseno sin cambios de codigo.

Referencia: `apps/management/plans/mvp_path/03-paso-mejoras-existentes.md`.

---

## 1. Invalid Refresh Token

### Sintoma

Error "Invalid Refresh Token: Refresh Token Not Found" al intentar acceder al panel.

### Causa

No es un bug de codigo. El estado de sesion es invalido: token expirado, sesion revocada en Supabase, o cookies corruptas.

### Accion recomendada

1. Borrar cookies del dominio (localhost:3001 o dominio de produccion).
2. Volver a hacer login.

Opcionalmente, si el cliente recibe este error en `getSession`/`getUser`, el SDK de Supabase puede llamar a `signOut()` para limpiar cookies. No priorizado.

---

## 2. Dashboard metricas

### Estado actual

El dashboard obtiene metricas reales via `GET /api/v1/management/stats`:
- organization_count: total de organizaciones
- employee_count: total de empleados

Muestra "—" mientras carga.

---

## 3. Organizations

### Estado actual

La pagina `/organizations` usa datos reales via `GET /api/v1/management/organizations`.
Crear organizacion: `POST /api/v1/management/organizations`.

Referencia: `apps/management/plans/mvp_path/04-paso-organizaciones-crud.md`.
