/**
 * Reglas de negocio para fichajes (CL-006, CL-007).
 * Referencia: definiciones/CASOS-LIMITE.md, CONFIGURACIONES.md CFG-010
 */

const DEFAULT_DESCANSO_HORAS = 12;
const MIN_DESCANSO = 10;
const MAX_DESCANSO = 12;

export interface LastFichaje {
  id: string;
  tipo: 'entrada' | 'salida';
  timestamp_servidor: string;
}

export type EntradaValidation =
  | { allowed: true }
  | { allowed: false; code: 'duplicado_entrada'; message: string }
  | { allowed: false; code: 'descanso_insuficiente'; message: string; esperarHoras: number; descansoHoras: number };

function clampDescansoHoras(value: number): number {
  if (!Number.isFinite(value) || value < MIN_DESCANSO) return DEFAULT_DESCANSO_HORAS;
  if (value > MAX_DESCANSO) return MAX_DESCANSO;
  return Math.round(value);
}

/**
 * CL-006: Si último evento es entrada, rechazar otra entrada.
 * CL-007: Si pasaron <descansoHoras desde última salida, rechazar entrada.
 * CFG-010: descanso_minimo_horas (default 12, legal Argentina).
 */
export function validateEntrada(
  lastFichaje: LastFichaje | null,
  now: Date = new Date(),
  descansoHoras: number = DEFAULT_DESCANSO_HORAS,
): EntradaValidation {
  if (!lastFichaje) return { allowed: true };

  if (lastFichaje.tipo === 'entrada') {
    return {
      allowed: false,
      code: 'duplicado_entrada',
      message: 'Ya registraste entrada. Registrar salida primero.',
    };
  }

  if (lastFichaje.tipo === 'salida') {
    const horas = clampDescansoHoras(descansoHoras);
    const lastSalida = new Date(lastFichaje.timestamp_servidor);
    const horasDesdeSalida = (now.getTime() - lastSalida.getTime()) / (1000 * 60 * 60);
    if (horasDesdeSalida < horas) {
      const esperar = Math.ceil((horas - horasDesdeSalida) * 10) / 10;
      return {
        allowed: false,
        code: 'descanso_insuficiente',
        message: `Debés esperar ${esperar} horas más para cumplir el descanso mínimo de ${horas} horas (Art. 198 LCT). Tu última salida fue a las ${lastSalida.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })}.`,
        esperarHoras: esperar,
        descansoHoras: horas,
      };
    }
  }

  return { allowed: true };
}
