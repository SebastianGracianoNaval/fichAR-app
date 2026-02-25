-- Solicitudes "trabajar más hoy" / "trabajar menos hoy" (MVP)
CREATE TABLE public.solicitudes_jornada (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  tipo varchar(30) NOT NULL CHECK (tipo IN ('mas_horas', 'menos_horas', 'intercambio')),
  estado varchar(20) NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobada', 'rechazada')),
  solicitante_employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  aprobador_employee_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  fecha_solicitud date NOT NULL DEFAULT CURRENT_DATE,
  fecha_objetivo date,
  horas_solicitadas decimal(5,2),
  motivo_rechazo text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT motivo_rechazo_obligatorio CHECK (
    estado != 'rechazada' OR (motivo_rechazo IS NOT NULL AND length(trim(motivo_rechazo)) > 0)
  )
);

CREATE INDEX idx_solicitudes_jornada_org ON public.solicitudes_jornada(org_id);
CREATE INDEX idx_solicitudes_jornada_employee ON public.solicitudes_jornada(employee_id);
CREATE INDEX idx_solicitudes_jornada_estado ON public.solicitudes_jornada(org_id, estado);
CREATE INDEX idx_solicitudes_jornada_aprobador ON public.solicitudes_jornada(aprobador_employee_id) WHERE aprobador_employee_id IS NOT NULL;

ALTER TABLE public.solicitudes_jornada ENABLE ROW LEVEL SECURITY;

CREATE POLICY solicitudes_jornada_select ON public.solicitudes_jornada
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM public.employees e WHERE e.auth_user_id = auth.uid()
    )
  );
CREATE POLICY solicitudes_jornada_insert ON public.solicitudes_jornada
  FOR INSERT WITH CHECK (
    org_id IN (
      SELECT org_id FROM public.employees e WHERE e.auth_user_id = auth.uid()
    )
  );
CREATE POLICY solicitudes_jornada_update ON public.solicitudes_jornada
  FOR UPDATE USING (
    org_id IN (
      SELECT org_id FROM public.employees e WHERE e.auth_user_id = auth.uid()
    )
  );
