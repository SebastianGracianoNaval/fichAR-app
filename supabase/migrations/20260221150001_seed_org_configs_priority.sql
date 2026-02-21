-- fichAR Migration: Seed priority org configs (CONFIG_WHITELIST)
-- Reference: definiciones/CONFIGURACIONES.txt, plan-org-configs-and-webhooks-phase-1.md

INSERT INTO public.org_configs (org_id, key, value)
SELECT o.id, 'geolocalizacion_obligatoria', to_jsonb(true)
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.org_configs oc WHERE oc.org_id = o.id AND oc.key = 'geolocalizacion_obligatoria');

INSERT INTO public.org_configs (org_id, key, value)
SELECT o.id, 'tolerancia_gps_metros', to_jsonb(10)
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.org_configs oc WHERE oc.org_id = o.id AND oc.key = 'tolerancia_gps_metros');

INSERT INTO public.org_configs (org_id, key, value)
SELECT o.id, 'mfa_obligatorio_admin', to_jsonb(true)
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.org_configs oc WHERE oc.org_id = o.id AND oc.key = 'mfa_obligatorio_admin');

INSERT INTO public.org_configs (org_id, key, value)
SELECT o.id, 'modo_offline_habilitado', to_jsonb(true)
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.org_configs oc WHERE oc.org_id = o.id AND oc.key = 'modo_offline_habilitado');

INSERT INTO public.org_configs (org_id, key, value)
SELECT o.id, 'import_welcome', to_jsonb(true)
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.org_configs oc WHERE oc.org_id = o.id AND oc.key = 'import_welcome');
