-- fichAR Phase 4: solicitudes_licencia, licencia_adjuntos, alertas
-- Referencia: definiciones/ESQUEMA-BD.txt, plans/Plan-Detallado-Fases-3-4-VOIS.md

-- solicitudes_licencia
CREATE TABLE IF NOT EXISTS public.solicitudes_licencia (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  tipo varchar(50) NOT NULL,
  fecha_inicio date NOT NULL,
  fecha_fin date NOT NULL,
  motivo text,
  estado varchar(20) NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobada', 'rechazada')),
  aprobado_por uuid REFERENCES public.employees(id),
  rechazo_motivo text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_solicitudes_employee ON public.solicitudes_licencia(employee_id);
CREATE INDEX idx_solicitudes_org_estado ON public.solicitudes_licencia(org_id, estado);
CREATE INDEX idx_solicitudes_org_fechas ON public.solicitudes_licencia(org_id, fecha_inicio, fecha_fin);

-- licencia_adjuntos
CREATE TABLE IF NOT EXISTS public.licencia_adjuntos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  licencia_id uuid NOT NULL REFERENCES public.solicitudes_licencia(id) ON DELETE CASCADE,
  storage_path varchar(500) NOT NULL,
  filename varchar(255),
  mime_type varchar(50),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_licencia_adjuntos_licencia ON public.licencia_adjuntos(licencia_id);

-- alertas
CREATE TABLE IF NOT EXISTS public.alertas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  tipo varchar(50) NOT NULL,
  descripcion text,
  leida bool NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_alertas_org_employee ON public.alertas(org_id, employee_id);
CREATE INDEX idx_alertas_org_tipo ON public.alertas(org_id, tipo);

-- RLS solicitudes_licencia
ALTER TABLE public.solicitudes_licencia ENABLE ROW LEVEL SECURITY;

-- Empleado: ve propias solicitudes
CREATE POLICY solicitudes_select_own ON public.solicitudes_licencia
  FOR SELECT
  USING (
    employee_id IN (
      SELECT id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );

-- Admin, Supervisor, legal_auditor: ven org (API filtra por equipo si supervisor)
CREATE POLICY solicitudes_select_team_org ON public.solicitudes_licencia
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'supervisor', 'legal_auditor')
    )
  );

CREATE POLICY solicitudes_insert_own ON public.solicitudes_licencia
  FOR INSERT
  WITH CHECK (
    employee_id IN (
      SELECT id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );

-- Admin, Supervisor: aprobar/rechazar (UPDATE)
CREATE POLICY solicitudes_update_approve ON public.solicitudes_licencia
  FOR UPDATE
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'supervisor')
    )
  );

-- RLS licencia_adjuntos (via licencia)
ALTER TABLE public.licencia_adjuntos ENABLE ROW LEVEL SECURITY;

CREATE POLICY licencia_adjuntos_select_via_licencia ON public.licencia_adjuntos
  FOR SELECT
  USING (
    licencia_id IN (
      SELECT id FROM public.solicitudes_licencia sl
      WHERE sl.org_id IN (
        SELECT org_id FROM public.employees e
        WHERE e.auth_user_id = auth.uid()
      )
    )
  );

CREATE POLICY licencia_adjuntos_insert_via_licencia ON public.licencia_adjuntos
  FOR INSERT
  WITH CHECK (
    licencia_id IN (
      SELECT id FROM public.solicitudes_licencia sl
      WHERE sl.employee_id IN (
        SELECT id FROM public.employees e
        WHERE e.auth_user_id = auth.uid()
      )
    )
  );

-- RLS alertas
ALTER TABLE public.alertas ENABLE ROW LEVEL SECURITY;

CREATE POLICY alertas_select_org_member ON public.alertas
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'supervisor', 'auditor', 'legal_auditor')
    )
  );

-- INSERT alertas: solo via service_role (API/sistema). Sin policy = solo bypass RLS.

-- Trigger updated_at para solicitudes_licencia
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS solicitudes_licencia_updated_at ON public.solicitudes_licencia;
CREATE TRIGGER solicitudes_licencia_updated_at
  BEFORE UPDATE ON public.solicitudes_licencia
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
