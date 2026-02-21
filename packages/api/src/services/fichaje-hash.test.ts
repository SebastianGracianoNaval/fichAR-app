import { describe, expect, it } from 'bun:test';
import { computeHash } from './fichaje-hash.ts';

describe('computeHash', () => {
  it('is deterministic', () => {
    const a = computeHash('pepper', null, 'u1', 'o1', 'entrada', '2026-01-01T10:00:00Z', null, null, null);
    const b = computeHash('pepper', null, 'u1', 'o1', 'entrada', '2026-01-01T10:00:00Z', null, null, null);
    expect(a).toBe(b);
  });

  it('produces different hash when input changes', () => {
    const a = computeHash('pepper', null, 'u1', 'o1', 'entrada', '2026-01-01T10:00:00Z', null, null, null);
    const b = computeHash('pepper', null, 'u2', 'o1', 'entrada', '2026-01-01T10:00:00Z', null, null, null);
    expect(a).not.toBe(b);
  });

  it('produces 64-char hex string', () => {
    const h = computeHash('p', null, 'u', 'o', 'entrada', '2026-01-01T10:00:00Z', null, null, null);
    expect(h).toMatch(/^[a-f0-9]{64}$/);
  });

  it('uses prevHash when provided', () => {
    const prev = computeHash('p', null, 'u', 'o', 'entrada', '2026-01-01T10:00:00Z', null, null, null);
    const next = computeHash('p', prev, 'u', 'o', 'salida', '2026-01-01T18:00:00Z', null, null, null);
    expect(next).not.toBe(prev);
  });
});
