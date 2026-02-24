-- fichAR: Integration API keys for external systems (n8n, Zapier, ERPs).
-- Reference: plans/integration_improve/01-integration-api-keys.md, INTEGRACIONES.md 7.2-7.3

CREATE TABLE IF NOT EXISTS public.integration_api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name varchar(100) NOT NULL,
  key_hash varchar(64) NOT NULL,
  scopes text[] NOT NULL DEFAULT '{read_fichajes}',
  active boolean NOT NULL DEFAULT true,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by_employee_id uuid REFERENCES public.employees(id)
);

CREATE UNIQUE INDEX idx_integration_api_keys_key_hash ON public.integration_api_keys(key_hash);
CREATE INDEX idx_integration_api_keys_org_active ON public.integration_api_keys(org_id, active);

COMMENT ON TABLE public.integration_api_keys IS 'API keys for integration (X-Api-Key). Key stored as SHA-256 hash only.';
