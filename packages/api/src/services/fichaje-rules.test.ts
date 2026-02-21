import { describe, expect, it } from 'bun:test';
import { validateEntrada } from './fichaje-rules.ts';

describe('fichaje-rules (CASOS-LIMITE CL-006, CL-007)', () => {
  it('CL-006: rechaza entrada cuando último es entrada', () => {
    const last = {
      id: 'x',
      tipo: 'entrada' as const,
      timestamp_servidor: new Date().toISOString(),
    };
    const r = validateEntrada(last);
    expect(r.allowed).toBe(false);
    expect(r.code).toBe('duplicado_entrada');
    expect(r.message).toContain('Registrar salida primero');
  });

  it('CL-006: permite entrada cuando no hay último fichaje', () => {
    const r = validateEntrada(null);
    expect(r.allowed).toBe(true);
  });

  it('CL-007: rechaza entrada cuando pasaron <12h desde última salida', () => {
    const hace9h = new Date(Date.now() - 9 * 60 * 60 * 1000);
    const last = {
      id: 'x',
      tipo: 'salida' as const,
      timestamp_servidor: hace9h.toISOString(),
    };
    const r = validateEntrada(last);
    expect(r.allowed).toBe(false);
    expect(r.code).toBe('descanso_insuficiente');
    expect(r.message).toContain('12 horas');
    expect('esperarHoras' in r && r.esperarHoras).toBeGreaterThan(0);
    expect('esperarHoras' in r && r.esperarHoras).toBeLessThanOrEqual(3);
  });

  it('CL-007: permite entrada cuando pasaron >=12h desde última salida', () => {
    const hace13h = new Date(Date.now() - 13 * 60 * 60 * 1000);
    const last = {
      id: 'x',
      tipo: 'salida' as const,
      timestamp_servidor: hace13h.toISOString(),
    };
    const r = validateEntrada(last);
    expect(r.allowed).toBe(true);
  });

  it('CL-007: rechaza exactamente en 11.9h (edge case)', () => {
    const hace119min = new Date(Date.now() - 11.9 * 60 * 60 * 1000);
    const last = {
      id: 'x',
      tipo: 'salida' as const,
      timestamp_servidor: hace119min.toISOString(),
    };
    const r = validateEntrada(last);
    expect(r.allowed).toBe(false);
  });
});
