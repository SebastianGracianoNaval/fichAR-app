export function validatePassword(pw: string): string | null {
  if (pw.length < 8) return 'Mínimo 8 caracteres';
  if (!/[A-Z]/.test(pw)) return 'Al menos una mayúscula';
  if (!/[0-9]/.test(pw)) return 'Al menos un número';
  return null;
}

export function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/** CL-027: CUIL Argentina. Validación formato + dígito verificador módulo 11. */
export function validateCuil(cuil: string): boolean {
  const normalized = cuil.replace(/-/g, '');
  if (!/^\d{11}$/.test(normalized)) return false;
  const digits = normalized.split('').map(Number);
  const base = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  let sum = 0;
  for (let i = 0; i < 10; i++) sum += digits[i]! * base[i]!;
  const rest = sum % 11;
  let verifier = 11 - rest;
  if (verifier === 11) verifier = 0;
  if (verifier === 10) verifier = 9;
  return digits[10] === verifier;
}

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateUUID(id: unknown): id is string {
  return typeof id === 'string' && UUID_REGEX.test(id);
}

/** CL-028: lat[-90,90], long[-180,180]. Throws if invalid. */
export function validateCoords(lat: unknown, long: unknown): void {
  const latN = Number(lat);
  const longN = Number(long);
  if (!Number.isFinite(latN) || latN < -90 || latN > 90) {
    throw new Error('Coordenadas inválidas. Lat[-90,90], Long[-180,180].');
  }
  if (!Number.isFinite(longN) || longN < -180 || longN > 180) {
    throw new Error('Coordenadas inválidas. Lat[-90,90], Long[-180,180].');
  }
}

const RADIO_MIN = 50;
const RADIO_MAX = 500;

/** CFG-006: radio 50-500 metros. Returns null if valid, error string otherwise. */
export function validateRadioM(radio: unknown): string | null {
  const n = Number(radio);
  if (!Number.isFinite(n) || n < RADIO_MIN || n > RADIO_MAX) {
    return 'Radio debe estar entre 50 y 500 metros.';
  }
  return null;
}

const VALID_DIAS = new Set(['L', 'M', 'X', 'J', 'V', 'S', 'D']);

/** Parse days string L,M,X,J,V,S,D. Returns array or null if invalid. */
export function parseDias(dias: unknown): string[] | null {
  if (typeof dias !== 'string' || !dias.trim()) return null;
  const parts = dias.split(/[,\s]+/).map((s) => s.trim().toUpperCase()).filter(Boolean);
  if (parts.length === 0) return null;
  const valid = parts.filter((p) => VALID_DIAS.has(p));
  if (valid.length === 0) return null;
  return [...new Set(valid)];
}

export interface PaginationResult {
  limit: number;
  offset: number;
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

export function validatePagination(
  limitParam: string | null,
  offsetParam: string | null,
  options?: { defaultLimit?: number; maxLimit?: number },
): PaginationResult {
  const defaultLimit = options?.defaultLimit ?? DEFAULT_LIMIT;
  const cap = options?.maxLimit ?? MAX_LIMIT;
  const limitRaw = parseInt(limitParam ?? '', 10);
  const offsetRaw = parseInt(offsetParam ?? '', 10);

  const limit = Number.isNaN(limitRaw) || limitRaw <= 0 ? defaultLimit : Math.min(limitRaw, cap);
  const offset = Number.isNaN(offsetRaw) || offsetRaw < 0 ? 0 : offsetRaw;

  return { limit, offset };
}

export function parseBody<T>(body: unknown): T | null {
  if (body && typeof body === 'object' && !Array.isArray(body)) return body as T;
  return null;
}
