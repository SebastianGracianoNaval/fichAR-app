import { describe, expect, it, mock } from 'bun:test';
import { delay, geocodeAddress, RATE_LIMIT_MS } from './geocoding.ts';

describe('geocoding', () => {
  it('returns null for empty address', async () => {
    const result = await geocodeAddress('');
    expect(result).toBeNull();
  });

  it('returns null for whitespace-only address', async () => {
    const result = await geocodeAddress('   ');
    expect(result).toBeNull();
  });

  it('returns coords when Nominatim returns valid result', async () => {
    const originalFetch = globalThis.fetch;
    (globalThis as unknown as { fetch: typeof fetch }).fetch = mock(async () =>
      new Response(JSON.stringify([{ lat: '-34.6037', lon: '-58.3816' }])),
    ) as unknown as typeof fetch;
    try {
      const result = await geocodeAddress('Av. Corrientes 100, Buenos Aires');
      expect(result).toEqual({ lat: -34.6037, long: -58.3816 });
    } finally {
      (globalThis as unknown as { fetch: typeof fetch }).fetch = originalFetch;
    }
  });

  it('returns null when Nominatim returns empty array', async () => {
    const originalFetch = globalThis.fetch;
    (globalThis as unknown as { fetch: typeof fetch }).fetch = mock(async () => new Response(JSON.stringify([])));
    try {
      const result = await geocodeAddress('xyz123nonexistent');
      expect(result).toBeNull();
    } finally {
      (globalThis as unknown as { fetch: typeof fetch }).fetch = originalFetch;
    }
  });

  it('delay resolves after ms', async () => {
    const start = Date.now();
    await delay(50);
    expect(Date.now() - start).toBeGreaterThanOrEqual(45);
  });

  it('RATE_LIMIT_MS is 1100', () => {
    expect(RATE_LIMIT_MS).toBe(1100);
  });
});
