-- fichAR Migration 3: org_configs (CFG-* defaults)
-- Referencia: definiciones/CONFIGURACIONES.txt

CREATE TABLE IF NOT EXISTS public.org_configs (
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  key varchar(80) NOT NULL,
  value jsonb NOT NULL DEFAULT '{}',
  PRIMARY KEY (org_id, key)
);

CREATE INDEX idx_org_configs_org_id ON public.org_configs(org_id);

ALTER TABLE public.org_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY org_configs_select_own_org ON public.org_configs
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );

-- INSERT: only via service_role (API). No client policy.

CREATE POLICY org_configs_update_admin ON public.org_configs
  FOR UPDATE
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid() AND e.role = 'admin'
    )
  );
