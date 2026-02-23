-- fichAR: Wipe organizations and employees (dev/reset)
-- Elimina todo rastro de organizaciones y empleados, incluyendo auth.users,
-- para poder re-registrar correos (ej. "email ya registrado").
--
-- Uso: Ejecutar en Supabase Dashboard > SQL Editor (como postgres/service_role).
-- Advertencia: IRREVERSIBLE. Solo para desarrollo o reset total.
--
-- Notas:
-- - management_users NO se borra (usuarios del dashboard management).
-- - Si falla por Storage: el usuario tiene objetos en Storage; borrarlos antes.
-- - Para borrar solo UNA org: sustituir "DELETE FROM public.organizations"
--   por "DELETE FROM public.organizations WHERE id = 'uuid-aqui'" y ajustar
--   el SELECT de _wipe_auth_user_ids para esa org.

BEGIN;

-- 1. Recolectar auth_user_ids de empleados (antes de borrar)
CREATE TEMP TABLE IF NOT EXISTS _wipe_auth_user_ids AS
  SELECT DISTINCT auth_user_id
  FROM public.employees;

-- 2. Borrar audit_logs (org_id/user_id tienen ON DELETE SET NULL, no borran filas)
DELETE FROM public.audit_logs
WHERE org_id IN (SELECT id FROM public.organizations);

-- 3. Borrar organizaciones (CASCADE a employees, branches, places, org_configs,
--    webhooks, fichajes, solicitudes_licencia, licencia_adjuntos, alertas, etc.)
DELETE FROM public.organizations;

-- 4. Borrar auth.identities (referencias a auth.users)
DELETE FROM auth.identities
WHERE user_id IN (SELECT auth_user_id FROM _wipe_auth_user_ids);

-- 5. Borrar auth.users (liberando emails para nuevo registro)
DELETE FROM auth.users
WHERE id IN (SELECT auth_user_id FROM _wipe_auth_user_ids);

-- 6. Limpiar tabla temporal
DROP TABLE IF EXISTS _wipe_auth_user_ids;

COMMIT;
