-- fichAR: employees.password_changed_at para flujo primer-login y email de bienvenida
-- Referencia: plans/import-welcome-email-and-first-login-password-change.md

ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS password_changed_at timestamptz;

COMMENT ON COLUMN public.employees.password_changed_at IS 'Set when user first sets/changes password. Null = must change on next login.';
