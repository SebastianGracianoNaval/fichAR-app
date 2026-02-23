# Scripts

Utilidades y SQL de soporte para desarrollo y despliegue de fichAR.

## TypeScript (Bun)

| Script | Uso | Descripción |
|--------|-----|-------------|
| `seed-test-admin.ts` | `bun run scripts/seed-test-admin.ts` | Crea cuenta admin de prueba. Requiere SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en .env. Credenciales por defecto: admin@adminwise.com / Admin@wise!234 |
| `ensure_mobile_env.ts` | `bun run scripts/ensure_mobile_env.ts` | Verifica variables de entorno necesarias para la app mobile. |

## SQL (Supabase remoto)

Scripts para aplicar manualmente en Supabase Dashboard > SQL Editor cuando no se usan migraciones automáticas.

| Archivo | Propósito |
|---------|-----------|
| `add-licencias-alertas-webhooks-remote.sql` | Crea tablas solicitudes_licencia, licencia_adjuntos, alertas, webhooks y RLS asociado. |
| `apply-integrity-viewer-remote.sql` | Aplica rol integrity_viewer (Phase 1). |
| `apply-integrity-viewer-remote-phase2.sql` | Aplica cambios Phase 2 de integrity_viewer. |

**Importante:** Las migraciones formales van en `supabase/migrations/`. Estos SQL son complementos para casos donde se aplica en remoto sin CI/CD.
