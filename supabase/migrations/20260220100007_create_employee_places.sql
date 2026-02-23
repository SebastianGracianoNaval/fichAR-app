-- fichAR Migration 7: employee_places (N:M empleado-lugares)
-- Referencia: definiciones/ESQUEMA-BD.md

CREATE TABLE IF NOT EXISTS public.employee_places (
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  place_id uuid NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
  PRIMARY KEY (employee_id, place_id)
);

ALTER TABLE public.employee_places ENABLE ROW LEVEL SECURITY;

CREATE POLICY employee_places_select_own ON public.employee_places
  FOR SELECT
  USING (
    employee_id IN (SELECT id FROM public.employees WHERE auth_user_id = auth.uid())
    OR place_id IN (
      SELECT p.id FROM public.places p
      WHERE p.org_id IN (SELECT org_id FROM public.employees WHERE auth_user_id = auth.uid())
    )
  );
