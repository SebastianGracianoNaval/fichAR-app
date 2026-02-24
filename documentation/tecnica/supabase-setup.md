# fichAR — Setup Supabase

## 1. Seguridad: checklist

### En el codigo (ya implementado)

- [x] RLS habilitado en todas las tablas (organizations, employees, org_configs, audit_logs)
- [x] Politicas que usan `auth.uid()` para filtrar por org
- [x] INSERT en employees/org_configs solo via service_role (API)
- [x] audit_logs: solo SELECT para Admin/Auditor, INSERT via API

### En el Dashboard de Supabase (manual)

- [ ] Authentication > Providers > Email: Activar "Confirm email"
- [ ] Authentication > URL Configuration: Whitelist de redirect URLs (no usar *)
- [ ] Authentication > Rate Limits: Revisar limites por defecto
- [ ] Cuenta Supabase: Activar MFA en account settings
- [ ] Authentication > MFA: TOTP está habilitado por defecto en todos los proyectos (CFG-025)

### Para produccion

- [ ] PITR (Point-in-Time Recovery) en Database settings
- [ ] SMTP propio para emails (evitar bloqueos)
- [ ] CORS restringido a dominios conocidos

**Conclusion:** La capa de codigo/DB esta cubierta. La configuracion del Dashboard es manual y recomendada.

### Variables para la API

La API (packages/api) requiere en `.env` (raiz del repo):

- `SUPABASE_URL` — URL del proyecto
- `SUPABASE_SERVICE_ROLE_KEY` — Clave service_role (Dashboard > Settings > API). Solo servidor, nunca en cliente.
- `INVITE_SECRET` — **Requerido** para POST /auth/invite y POST /auth/register. Secreto para firmar tokens de invitacion. No usar `SUPABASE_SERVICE_ROLE_KEY`. Generar con `openssl rand -hex 32`.
- `RESET_PASSWORD_REDIRECT_URL` — (opcional) URL de redireccion tras reset de password.
- `HASH_PEPPER` — **Requerido** para POST /fichajes. Secreto para cadena de hashes (32+ bytes). Generar: `openssl rand -hex 32`.
- `MANAGEMENT_API_KEY` — **Requerido** para POST /management/organizations (fichar-management). Ver `documentation/tecnica/management-api.md`.
- `UPSTASH_REDIS_REST_URL` y `UPSTASH_REDIS_REST_TOKEN` — **Opcional**. Para rate limiting distribuido (multi-instancia). Sin estas variables se usa almacenamiento in-memory (solo una instancia). Crear base Redis gratuita en https://console.upstash.com, copiar credenciales REST.
- `CORS_ORIGINS` — **Requerido en producción**. Orígenes permitidos separados por coma. Si está vacío en producción, no se permite ningún origen. Ver sección CORS más abajo.

**Variables de entorno con valores complejos (D1):** Si usás valores que incluyen comas, comillas o JSON en `.env`, puede ser necesario entrecomillar. La API usa `dotenv`; ver documentación del paquete para casos edge.

**Redis en producción (D2):** Para despliegue multi-pod (varias instancias de la API), configurar `UPSTASH_REDIS_REST_URL` y `UPSTASH_REDIS_REST_TOKEN`. Con una sola instancia puede usarse el fallback in-memory (se registra como info en desarrollo y warning en producción).

---

## 2. Rate limiting con Redis (Upstash)

Para entornos con múltiples instancias de la API, el rate limit de login debe usar Redis:

1. Crear cuenta en https://console.upstash.com
2. Crear base de datos Redis (plan Free: 256 MB, 500K comandos/mes)
3. En el detalle de la base, copiar `UPSTASH_REDIS_REST_URL` y `UPSTASH_REDIS_REST_TOKEN`
4. Añadir a `.env`

---

## 3. Aplicar migraciones

### Opción A: Supabase CLI (Linux Debian 12)

```bash
# Instalar Supabase CLI
curl -fsSL https://supabase.com/install.sh | sh

# O con npm/bun
bun add -g supabase

# Login
supabase login

# Vincular proyecto (desde la raiz del repo)
supabase link --project-ref dfbyxjqryqrlpobudwmu

# Aplicar migraciones
supabase db push
```

### Opción B: Dashboard (SQL Editor)

1. Ir a https://supabase.com/dashboard
2. Proyecto > SQL Editor
3. Copiar y ejecutar cada archivo de `supabase/migrations/` en orden (000001, 000002, etc.)

**Nota:** Las migraciones ya estan aplicadas via MCP `apply_migration`. Las tablas organizations, employees, org_configs y audit_logs existen.

---

## 3.1. Retención audit_logs (CFG-037)

**Referencia:** definiciones/CONFIGURACIONES.md CFG-037, LCT Art. 52, ISO 27001 A.8.10.

- **Default:** 3650 días (10 años). Se persiste en `org_configs` con key `logs_retencion_dias`.
- **Política:** `audit_logs` es inmutable (INSERT only). No existe purga automática en esta versión.
- **Operativo:** Los logs se conservan indefinidamente. Para archivar o rotar, usar backup/export manual.
- **Futuro:** Si se implementa job de purga, debe respetar `logs_retencion_dias` por org (valor >= 365).

### Opciones de purga (futuro)

1. **Manual:** Ejecutar periódicamente un script que elimine registros vencidos:

```sql
DELETE FROM audit_logs
WHERE org_id = :org_id
  AND timestamp < now() - interval '1 day' * (
    SELECT value::int FROM org_configs
    WHERE org_id = :org_id AND key = 'logs_retencion_dias'
  );
```

2. **pg_cron (Supabase):** Crear job diario via `pg_cron` extension.
3. **Particionamiento:** Particionar `audit_logs` por mes permite `DROP` de particiones antiguas sin overhead de DELETE masivo.

### Advertencias

- No purgar antes de cumplir el mínimo legal (Art. 52 LCT: 10 años para documentación laboral).
- Antes de purgar, exportar backup completo del periodo.
- Un log purgado antes de tiempo invalida la cadena de evidencia en juicio laboral.

---

## 4. MCP de Supabase (Cursor)

Archivo: `.cursor/mcp.json` (o `~/.cursor/mcp.json`)

Configuracion actual (auth por navegador):

```json
{
  "mcpServers": {
    "supabase": {
      "url": "https://mcp.supabase.com/mcp?project_ref=dfbyxjqryqrlpobudwmu&read_only=true"
    }
  }
}
```

- `read_only=true` limita las queries a solo lectura (mas seguro)
- Al usar el MCP, Cursor abrira el navegador para autenticarte en Supabase
- Herramientas disponibles: execute_sql, list_tables, apply_migration, generate_typescript_types, etc.

### Alternativa con token (CI, sin navegador)

```json
{
  "mcpServers": {
    "supabase": {
      "url": "https://mcp.supabase.com/mcp?project_ref=dfbyxjqryqrlpobudwmu",
      "headers": {
        "Authorization": "Bearer TU_ACCESS_TOKEN"
      }
    }
  }
}
```

Token: https://supabase.com/dashboard/account/tokens
