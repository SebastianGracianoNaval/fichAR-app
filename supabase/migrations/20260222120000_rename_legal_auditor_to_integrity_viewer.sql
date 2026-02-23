-- Rename role legal_auditor to integrity_viewer
-- Plan: plans/integrity-viewer-role-rename-and-copy-refresh.md
-- Strategy: alter CHECK, update existing rows, update RLS policies

BEGIN;

-- 1. Update existing employees
UPDATE public.employees SET role = 'integrity_viewer' WHERE role = 'legal_auditor';

-- 2. employees: replace role in CHECK
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_role_check;
ALTER TABLE public.employees ADD CONSTRAINT employees_role_check
  CHECK (role IN ('empleado', 'supervisor', 'admin', 'auditor', 'integrity_viewer'));

-- 3. RLS policies: DROP and CREATE to change role in USING clause
-- audit_logs (20260220000004)
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

-- fichajes (20260220100008)
DROP POLICY IF EXISTS fichajes_select_org_admin ON public.fichajes;
CREATE POLICY fichajes_select_org_admin ON public.fichajes
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid() AND e.role IN ('admin', 'supervisor', 'auditor', 'integrity_viewer')
    )
  );

-- solicitudes_licencia (20260221100001)
DROP POLICY IF EXISTS solicitudes_select_team_org ON public.solicitudes_licencia;
CREATE POLICY solicitudes_select_team_org ON public.solicitudes_licencia
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'supervisor', 'integrity_viewer')
    )
  );

-- alertas (20260221100001)
DROP POLICY IF EXISTS alertas_select_org_member ON public.alertas;
CREATE POLICY alertas_select_org_member ON public.alertas
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'supervisor', 'auditor', 'integrity_viewer')
    )
  );

-- licencia_adjuntos (20260221120001)
DROP POLICY IF EXISTS licencia_adjuntos_select_org_leaders ON public.licencia_adjuntos;
CREATE POLICY licencia_adjuntos_select_org_leaders ON public.licencia_adjuntos
  FOR SELECT
  USING (
    licencia_id IN (
      SELECT id FROM public.solicitudes_licencia sl
      WHERE sl.org_id IN (
        SELECT org_id FROM public.employees e
        WHERE e.auth_user_id = auth.uid()
        AND e.role IN ('admin', 'supervisor', 'integrity_viewer')
      )
    )
  );

COMMIT;
