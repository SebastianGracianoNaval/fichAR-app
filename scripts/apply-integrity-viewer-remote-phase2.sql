-- Parte 2: Tablas opcionales (solicitudes_licencia, alertas, licencia_adjuntos)
-- Ejecutar SOLO si estas tablas existen en tu base remota
-- Verificar con: SELECT tablename FROM pg_tables WHERE schemaname = 'public';

BEGIN;

-- solicitudes_licencia
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

-- alertas
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

-- licencia_adjuntos
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
