# fichAR - Reset Supabase para testing

Para liberar correos y reiniciar datos de organizaciones/empleados durante el desarrollo o pruebas.

---

## Script: `scripts/wipe-organizations-and-employees.sql`

### Qué hace

1. **audit_logs** — Borra filas con `org_id` en organizations.
2. **organizations** — Borra todas las organizaciones. **CASCADE** borra:
   - employees, branches, places, org_configs, webhooks
   - fichajes, solicitudes_jornada, solicitudes_licencia, alertas
   - Cualquier tabla con `org_id REFERENCES organizations ON DELETE CASCADE`
3. **auth.identities** — Identidades de los `auth_user_id` de empleados.
4. **auth.users** — Usuarios de auth de empleados. Libera correos para re-registro.

### Qué NO borra

- **management_users** — Usuarios del dashboard management (por diseño).
- Schema, políticas RLS, índices — No se modifican.
- **Storage** — Si hay objetos referenciados, el script puede fallar. Borrarlos antes en Supabase Dashboard > Storage.

### Uso

1. Supabase Dashboard > SQL Editor.
2. Pegar el contenido de `scripts/wipe-organizations-and-employees.sql`.
3. Ejecutar (como postgres o service_role).

### Advertencia

**IRREVERSIBLE.** Solo para desarrollo o reset total. En producción no ejecutar; borraría todos los datos de tenant.

---

## Seguridad

El script solo elimina datos; no cambia políticas RLS, schema ni permisos. No debilita la seguridad de la app. El riesgo es operativo: ejecutarlo por error en producción. Mitigación: usarlo solo en entornos de test; no incluirlo en pipelines automáticos de producción.
