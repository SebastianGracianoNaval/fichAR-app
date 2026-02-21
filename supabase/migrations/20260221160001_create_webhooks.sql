-- fichAR Migration: webhooks table for event dispatch
-- Reference: definiciones/INTEGRACIONES.txt 5.1-5.4

CREATE TABLE IF NOT EXISTS public.webhooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  url text NOT NULL CHECK (length(url) <= 2048),
  secret text,
  events text[] NOT NULL CHECK (array_length(events, 1) >= 1),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(org_id, url)
);

CREATE INDEX idx_webhooks_org_active ON public.webhooks(org_id) WHERE active = true;

ALTER TABLE public.webhooks ENABLE ROW LEVEL SECURITY;

CREATE POLICY webhooks_admin_all ON public.webhooks
  FOR ALL
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid() AND e.role = 'admin'
    )
  )
  WITH CHECK (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid() AND e.role = 'admin'
    )
  );
