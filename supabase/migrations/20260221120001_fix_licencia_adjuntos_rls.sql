-- Fix licencia_adjuntos RLS: empleado solo ve adjuntos de sus licencias
-- Audit S-002: policy anterior permitia a cualquier org member ver todos los adjuntos

DROP POLICY IF EXISTS licencia_adjuntos_select_via_licencia ON public.licencia_adjuntos;

-- Empleado: solo adjuntos de sus propias licencias
CREATE POLICY licencia_adjuntos_select_own ON public.licencia_adjuntos
  FOR SELECT
  USING (
    licencia_id IN (
      SELECT id FROM public.solicitudes_licencia sl
      WHERE sl.employee_id IN (
        SELECT id FROM public.employees e
        WHERE e.auth_user_id = auth.uid()
      )
    )
  );

-- Admin, Supervisor, legal_auditor: ven adjuntos de la org
CREATE POLICY licencia_adjuntos_select_org_leaders ON public.licencia_adjuntos
  FOR SELECT
  USING (
    licencia_id IN (
      SELECT id FROM public.solicitudes_licencia sl
      WHERE sl.org_id IN (
        SELECT org_id FROM public.employees e
        WHERE e.auth_user_id = auth.uid()
        AND e.role IN ('admin', 'supervisor', 'legal_auditor')
      )
    )
  );
