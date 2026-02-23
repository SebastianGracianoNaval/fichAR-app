-- fichAR Migration: Performance indexes (plan-refactor-supabase)
-- Source: supabase-postgres-best-practices, definiciones/ESQUEMA-BD.md
-- Indexes for common filters; avoids sequential scans. No schema breaking changes.

-- fichajes: dashboard and per-user queries (org_id + user_id + timestamp_servidor)
-- Used by: legal/fichajes, legal/export, reportes; GET /fichajes filters by user_id
CREATE INDEX IF NOT EXISTS idx_fichajes_org_user_ts
  ON public.fichajes(org_id, user_id, timestamp_servidor DESC);

-- fichajes: per-user history with latest first (improves idx_fichajes_user_fecha for DESC order)
CREATE INDEX IF NOT EXISTS idx_fichajes_user_ts_desc
  ON public.fichajes(user_id, timestamp_servidor DESC);

-- solicitudes_licencia: per-employee list sorted by fecha_inicio
-- Used by: licencias list (employee_id filter), orden created_at/fecha
CREATE INDEX IF NOT EXISTS idx_solicitudes_employee_fecha
  ON public.solicitudes_licencia(employee_id, fecha_inicio DESC);

-- employees: list by org and role
-- Used by: employees list (org_id, role filter), equipo, banco
CREATE INDEX IF NOT EXISTS idx_employees_org_role
  ON public.employees(org_id, role);

-- audit_logs: org queries with latest first
-- Used by: legal/audit-logs, reportes
CREATE INDEX IF NOT EXISTS idx_audit_logs_org_ts_desc
  ON public.audit_logs(org_id, timestamp DESC);
