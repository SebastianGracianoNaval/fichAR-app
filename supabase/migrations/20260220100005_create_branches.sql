-- fichAR Migration 5: branches
-- Referencia: definiciones/ESQUEMA-BD.txt, plans/phase-1-2-mobile-web-implementation.md

CREATE TABLE IF NOT EXISTS public.branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name varchar(255) NOT NULL,
  address text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_branches_org_id ON public.branches(org_id);

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY branches_select_own_org ON public.branches
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );
