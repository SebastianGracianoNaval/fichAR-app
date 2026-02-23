-- Corrige advisory de Supabase: function has mutable search_path
-- Referencia: CVE-2018-1058, apps/management/plans/mvp_path/03-paso-mejoras-existentes.md

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
