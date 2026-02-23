-- fichAR Migration 6: places (lugares de trabajo)
-- Referencia: definiciones/ESQUEMA-BD.md

CREATE TABLE IF NOT EXISTS public.places (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  branch_id uuid REFERENCES public.branches(id) ON DELETE SET NULL,
  nombre varchar(255) NOT NULL,
  direccion text,
  lat decimal(10, 7) NOT NULL,
  long decimal(10, 7) NOT NULL,
  radio_m int NOT NULL DEFAULT 100,
  dias varchar(20),
  custom_attributes jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_places_org_id ON public.places(org_id);

ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;

CREATE POLICY places_select_own_org ON public.places
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
    )
  );
