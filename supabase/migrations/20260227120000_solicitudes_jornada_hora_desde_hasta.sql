-- Solicitudes jornada: rango horario (hora_desde, hora_hasta)
-- Para "trabajar más hoy" / "trabajar menos hoy" con franja explícita.

ALTER TABLE public.solicitudes_jornada
  ADD COLUMN IF NOT EXISTS hora_desde time,
  ADD COLUMN IF NOT EXISTS hora_hasta time;

COMMENT ON COLUMN public.solicitudes_jornada.hora_desde IS 'Hora de inicio del rango solicitado (ej. 09:00).';
COMMENT ON COLUMN public.solicitudes_jornada.hora_hasta IS 'Hora de fin del rango solicitado (ej. 18:00).';
