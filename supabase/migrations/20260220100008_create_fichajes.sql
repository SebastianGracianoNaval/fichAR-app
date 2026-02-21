-- fichAR Migration 8: fichajes (inalterables, solo INSERT)
-- Referencia: definiciones/ESQUEMA-BD.txt, SEGURIDAD.txt, CASOS-LIMITE

CREATE TABLE IF NOT EXISTS public.fichajes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  tipo varchar(10) NOT NULL CHECK (tipo IN ('entrada', 'salida')),
  timestamp_servidor timestamptz NOT NULL DEFAULT now(),
  timestamp_dispositivo timestamptz,
  lugar_id uuid REFERENCES public.places(id) ON DELETE SET NULL,
  lat decimal(10, 7),
  long decimal(10, 7),
  hash_registro varchar(64) NOT NULL,
  hash_anterior_id uuid REFERENCES public.fichajes(id) ON DELETE SET NULL,
  reemplazado_por_id uuid REFERENCES public.fichajes(id) ON DELETE SET NULL,
  idempotency_key varchar(64),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_fichajes_user_fecha ON public.fichajes(user_id, timestamp_servidor);
CREATE INDEX idx_fichajes_org_fecha ON public.fichajes(org_id, timestamp_servidor);
CREATE UNIQUE INDEX idx_fichajes_idempotency ON public.fichajes(idempotency_key) WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.fichajes ENABLE ROW LEVEL SECURITY;

CREATE POLICY fichajes_select_own ON public.fichajes
  FOR SELECT
  USING (
    user_id IN (SELECT id FROM public.employees WHERE auth_user_id = auth.uid())
  );

CREATE POLICY fichajes_select_org_admin ON public.fichajes
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid() AND e.role IN ('admin', 'supervisor', 'auditor', 'legal_auditor')
    )
  );
