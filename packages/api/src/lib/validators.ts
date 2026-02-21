export function validatePassword(pw: string): string | null {
  if (pw.length < 8) return 'Mínimo 8 caracteres';
  if (!/[A-Z]/.test(pw)) return 'Al menos una mayúscula';
  if (!/[0-9]/.test(pw)) return 'Al menos un número';
  return null;
}

export function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function validateCuil(cuil: string): boolean {
  return /^\d{2}-?\d{8}-?\d$/.test(cuil.replace(/-/g, '')) && cuil.replace(/-/g, '').length === 11;
}

export function parseBody<T>(body: unknown): T | null {
  if (body && typeof body === 'object' && !Array.isArray(body)) return body as T;
  return null;
}
