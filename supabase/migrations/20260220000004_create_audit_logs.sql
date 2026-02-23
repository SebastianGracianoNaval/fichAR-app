-- fichAR Migration 4: audit_logs (INSERT only, immutable)
-- Referencia: definiciones/SEGURIDAD.md, definiciones/ESQUEMA-BD.md

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  user_id uuid REFERENCES public.employees(id) ON DELETE SET NULL,
  timestamp timestamptz NOT NULL DEFAULT now(),
  action varchar(80) NOT NULL,
  resource_type varchar(50),
  resource_id uuid,
  details jsonb NOT NULL DEFAULT '{}',
  ip inet,
  user_agent text,
  device_id varchar(100),
  severity varchar(20) DEFAULT 'info'
    CHECK (severity IN ('info', 'warning', 'critical'))
);

CREATE INDEX idx_audit_logs_org_timestamp ON public.audit_logs(org_id, timestamp);
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Audit logs: Admin and Auditor can SELECT only. No INSERT/UPDATE/DELETE from client.
-- INSERT via service_role or RPC from API.
CREATE POLICY audit_logs_select_admin_auditor ON public.audit_logs
  FOR SELECT
  USING (
    org_id IN (
      SELECT org_id FROM public.employees e
      WHERE e.auth_user_id = auth.uid()
      AND e.role IN ('admin', 'auditor', 'legal_auditor')
    )
  );
