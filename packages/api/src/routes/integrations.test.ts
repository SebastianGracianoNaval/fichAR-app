import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index.ts';

const base = '/api/v1';

describe('integrations API (API key auth)', () => {
  it('GET /integrations/fichajes without API key returns 401', async () => {
    const req = new Request(`http://localhost${base}/integrations/fichajes?desde=2026-01-01&hasta=2026-01-31`, {
      method: 'GET',
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
    const data = (await res.json()) as { error?: string; code?: string };
    expect(data.code).toBe('unauthorized');
    expect(data.error).toContain('API key required');
  });

  it('GET /integrations/fichajes with invalid API key returns 401', async () => {
    const req = new Request(`http://localhost${base}/integrations/fichajes?desde=2026-01-01&hasta=2026-01-31`, {
      method: 'GET',
      headers: { 'X-Api-Key': 'invalid-key-not-in-db' },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
    const data = (await res.json()) as { error?: string; code?: string };
    expect(data.code).toBe('unauthorized');
    expect(data.error).toContain('Invalid or revoked');
  });

  it('GET /integrations/empleados without API key returns 401', async () => {
    const req = new Request(`http://localhost${base}/integrations/empleados`, { method: 'GET' });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
    const data = (await res.json()) as { error?: string; code?: string };
    expect(data.code).toBe('unauthorized');
  });

  it('GET /integrations/fichajes with unknown key returns 401', async () => {
    const req = new Request(`http://localhost${base}/integrations/fichajes`, {
      method: 'GET',
      headers: { 'X-Api-Key': 'a'.repeat(64) },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('GET /integrations/fichajes with Bearer invalid key returns 401', async () => {
    const req = new Request(`http://localhost${base}/integrations/fichajes?desde=2026-01-01&hasta=2026-01-31`, {
      method: 'GET',
      headers: { Authorization: 'Bearer invalid' },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });
});
