-- fichAR Phase 3: employees columns (branch_id, supervisor_id, modalidad, fecha_egreso)
-- Referencia: plans/Plan-Detallado-Fases-3-4-VOIS.md, definiciones/ESQUEMA-BD.md

ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id);
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS supervisor_id uuid REFERENCES public.employees(id);
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS modalidad varchar(20) DEFAULT 'presencial'
  CHECK (modalidad IN ('presencial', 'remoto', 'hibrido', 'rotativo'));
ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS fecha_egreso date;

CREATE INDEX IF NOT EXISTS idx_employees_branch ON public.employees(branch_id);
CREATE INDEX IF NOT EXISTS idx_employees_supervisor ON public.employees(supervisor_id);
