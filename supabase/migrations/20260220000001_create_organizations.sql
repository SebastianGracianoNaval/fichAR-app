-- fichAR Migration 1: organizations
-- Referencia: plans/phase-1-2-mobile-web-implementation.md, definiciones/ESQUEMA-BD.txt

CREATE TABLE IF NOT EXISTS public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(255) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_organizations_created_at ON public.organizations(created_at);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- Policy added in migration 2 (depends on employees table).
