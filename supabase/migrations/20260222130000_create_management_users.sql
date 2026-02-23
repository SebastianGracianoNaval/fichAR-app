-- fichAR: management_users - whitelist de usuarios del panel management
-- Referencia: apps/management/plans/mvp_path/01-paso-infraestructura-base.md

CREATE TABLE IF NOT EXISTS public.management_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email varchar(255) NOT NULL UNIQUE,
  auth_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  password_changed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_management_users_email ON public.management_users(email);
CREATE INDEX idx_management_users_auth_user_id ON public.management_users(auth_user_id);

ALTER TABLE public.management_users ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.management_users IS 'Whitelist de usuarios autorizados a acceder al panel fichar-management';
COMMENT ON COLUMN public.management_users.password_changed_at IS 'null = debe cambiar contraseña en primer login';

CREATE POLICY management_users_select_own ON public.management_users
  FOR SELECT USING (
    auth_user_id = auth.uid()
    OR (auth_user_id IS NULL AND email = (auth.jwt() ->> 'email'))
  );

CREATE POLICY management_users_update_own ON public.management_users
  FOR UPDATE USING (
    auth_user_id = auth.uid()
    OR (auth_user_id IS NULL AND email = (auth.jwt() ->> 'email'))
  )
  WITH CHECK (
    auth_user_id = auth.uid()
    OR (auth_user_id IS NULL AND email = (auth.jwt() ->> 'email'))
  );
