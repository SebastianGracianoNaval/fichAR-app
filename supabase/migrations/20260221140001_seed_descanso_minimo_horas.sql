-- fichAR Migration: Seed CFG-010 descanso_minimo_horas (default 12, Art. 198 LCT)
-- Referencia: definiciones/CONFIGURACIONES.txt CFG-010

INSERT INTO public.org_configs (org_id, key, value)
SELECT id, 'descanso_minimo_horas', to_jsonb(12)
FROM public.organizations o
WHERE NOT EXISTS (
  SELECT 1 FROM public.org_configs oc
  WHERE oc.org_id = o.id AND oc.key = 'descanso_minimo_horas'
);
