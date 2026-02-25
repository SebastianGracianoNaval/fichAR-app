-- Solicitudes jornada: fecha_limite_aceptacion para vencimiento
-- Si estado=pendiente y now() > fecha_limite_aceptacion, se considera vencida.

ALTER TABLE public.solicitudes_jornada
  ADD COLUMN IF NOT EXISTS fecha_limite_aceptacion timestamptz;

COMMENT ON COLUMN public.solicitudes_jornada.fecha_limite_aceptacion IS
  'Hasta cuándo puede aprobarse/rechazarse. Pasado este momento, pendiente se trata como vencida.';

-- Backfill: end of fecha_objetivo or fecha_solicitud (23:59:59)
UPDATE public.solicitudes_jornada
SET fecha_limite_aceptacion = COALESCE(fecha_objetivo, fecha_solicitud)::timestamp + interval '23 hours 59 minutes 59 seconds'
WHERE fecha_limite_aceptacion IS NULL AND estado = 'pendiente';
