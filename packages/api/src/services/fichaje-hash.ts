import { createHash } from 'node:crypto';

export function computeHash(
  pepper: string,
  prevHash: string | null,
  userId: string,
  orgId: string,
  tipo: string,
  timestamp: string,
  lugarId: string | null,
  lat: number | null,
  long: number | null,
): string {
  const payload = [
    pepper,
    prevHash ?? '',
    userId,
    orgId,
    tipo,
    timestamp,
    lugarId ?? '',
    String(lat ?? ''),
    String(long ?? ''),
  ].join('|');

  return createHash('sha256').update(payload).digest('hex');
}
