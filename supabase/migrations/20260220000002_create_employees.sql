-- fichAR Migration 2: employees (auth link)
-- Referencia: plans/phase-1-2-mobile-web-implementation.md, definiciones/ESQUEMA-BD.txt

CREATE TABLE IF NOT EXISTS public.employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email varchar(255) NOT NULL,
  role varchar(20) NOT NULL DEFAULT 'empleado'
    CHECK (role IN ('empleado', 'supervisor', 'admin', 'auditor', 'legal_auditor')),
  status varchar(20) NOT NULL DEFAULT 'activo'
    CHECK (status IN ('activo', 'despedido')),
  dni varchar(20) NOT NULL,
  cuil varchar(15) NOT NULL,
  name varchar(200) NOT NULL,
  fecha_ingreso date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, email),
  UNIQUE (org_id, cuil)
);

CREATE INDEX idx_employees_org_id ON public.employees(org_id);
CREATE INDEX idx_employees_auth_user_id ON public.employees(auth_user_id);
CREATE INDEX idx_employees_status ON public.employees(org_id, status);

ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY employees_select_own_org ON public.employees
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );

-- INSERT: only via service_role (API). No client policy.

CREATE POLICY employees_update_own_org ON public.employees
  FOR UPDATE
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );

CREATE POLICY organizations_select_member ON public.organizations
  FOR SELECT
  USING (
    id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );
