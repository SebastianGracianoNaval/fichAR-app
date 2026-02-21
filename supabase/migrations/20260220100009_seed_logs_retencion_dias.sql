-- fichAR Migration 9: Seed CFG-037 logs_retencion_dias (default 3650 días = 10 años)
-- Referencia: definiciones/CONFIGURACIONES.txt CFG-037, LCT Art. 52

-- Seed default para organizaciones existentes que no tengan el valor
INSERT INTO public.org_configs (org_id, key, value)
SELECT id, 'logs_retencion_dias', to_jsonb(3650)
FROM public.organizations o
WHERE NOT EXISTS (
  SELECT 1 FROM public.org_configs oc
  WHERE oc.org_id = o.id AND oc.key = 'logs_retencion_dias'
);
