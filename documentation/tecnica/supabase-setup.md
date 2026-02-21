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

---

## 2. Aplicar migraciones

### Opcion A: Supabase CLI (Linux Debian 12)

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

### Opcion B: Dashboard (SQL Editor)

1. Ir a https://supabase.com/dashboard
2. Proyecto > SQL Editor
3. Copiar y ejecutar cada archivo de `supabase/migrations/` en orden (000001, 000002, etc.)

**Nota:** Las migraciones ya estan aplicadas via MCP `apply_migration`. Las tablas organizations, employees, org_configs y audit_logs existen.

---

## 3. MCP de Supabase (Cursor)

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
