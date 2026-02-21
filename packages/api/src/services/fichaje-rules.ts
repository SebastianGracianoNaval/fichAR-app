/**
 * Reglas de negocio para fichajes (CL-006, CL-007).
 * Referencia: definiciones/CASOS-LIMITE.txt
 */

const DESCANSO_HORAS = 12;

export interface LastFichaje {
  id: string;
  tipo: 'entrada' | 'salida';
  timestamp_servidor: string;
}

export type EntradaValidation =
  | { allowed: true }
  | { allowed: false; code: 'duplicado_entrada'; message: string }
  | { allowed: false; code: 'descanso_insuficiente'; message: string; esperarHoras: number };

/**
 * CL-006: Si último evento es entrada, rechazar otra entrada.
 * CL-007: Si pasaron <12h desde última salida, rechazar entrada.
 */
export function validateEntrada(
  lastFichaje: LastFichaje | null,
  now: Date = new Date(),
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
    const lastSalida = new Date(lastFichaje.timestamp_servidor);
    const horasDesdeSalida = (now.getTime() - lastSalida.getTime()) / (1000 * 60 * 60);
    if (horasDesdeSalida < DESCANSO_HORAS) {
      const esperar = Math.ceil((DESCANSO_HORAS - horasDesdeSalida) * 10) / 10;
      return {
        allowed: false,
        code: 'descanso_insuficiente',
        message: `Debés esperar ${esperar} horas más para cumplir el descanso mínimo de 12 horas (Art. 198 LCT). Tu última salida fue a las ${lastSalida.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })}.`,
        esperarHoras: esperar,
      };
    }
  }

  return { allowed: true };
}
