-- Aplica el cambio legal_auditor -> integrity_viewer en la base remota
-- Ejecutar en Supabase Dashboard > SQL Editor
-- Parte 1: Tablas que deben existir (employees, audit_logs, fichajes)

BEGIN;

-- 1. employees
UPDATE public.employees SET role = 'integrity_viewer' WHERE role = 'legal_auditor';

ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_role_check;
ALTER TABLE public.employees ADD CONSTRAINT employees_role_check
  CHECK (role IN ('empleado', 'supervisor', 'admin', 'auditor', 'integrity_viewer'));

-- 2. audit_logs
DROP POLICY IF EXISTS audit_logs_select_admin_auditor ON public.audit_logs;
CREATE POLICY audit_logs_select_admin_auditor ON public.audit_logs
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'auditor', 'integrity_viewer')
    )
  );

-- 3. fichajes
DROP POLICY IF EXISTS fichajes_select_org_admin ON public.fichajes;
CREATE POLICY fichajes_select_org_admin ON public.fichajes
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid() AND e.role IN ('admin', 'supervisor', 'auditor', 'integrity_viewer')
    )
  );

COMMIT;
