import { describe, expect, it, beforeAll, afterAll } from 'bun:test';
import { requireManagementAuth } from './management-auth.ts';

const VALID_KEY = 'a'.repeat(64);

describe('management-auth', () => {
  const originalEnv = process.env.MANAGEMENT_API_KEY;

  beforeAll(() => {
    process.env.MANAGEMENT_API_KEY = VALID_KEY;
  });

  afterAll(() => {
    process.env.MANAGEMENT_API_KEY = originalEnv;
  });

  it('returns 403 when Authorization and X-API-Key are missing', async () => {
    const req = new Request('http://localhost/', {
      method: 'POST',
      headers: {},
    });
    const result = await requireManagementAuth(req);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.res.status).toBe(403);
    }
  });

  it('returns 403 when key is invalid', async () => {
    const req = new Request('http://localhost/', {
      method: 'POST',
      headers: { Authorization: `Bearer ${'b'.repeat(64)}` },
    });
    const result = await requireManagementAuth(req);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.res.status).toBe(403);
    }
  });

  it('returns 503 when MANAGEMENT_API_KEY is not set', async () => {
    const saved = process.env.MANAGEMENT_API_KEY;
    delete process.env.MANAGEMENT_API_KEY;
    const req = new Request('http://localhost/', {
      method: 'POST',
      headers: { Authorization: `Bearer ${VALID_KEY}` },
    });
    const result = await requireManagementAuth(req);
    process.env.MANAGEMENT_API_KEY = saved;
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.res.status).toBe(503);
    }
  });

  it('returns ok with valid Bearer key', async () => {
    const req = new Request('http://localhost/', {
      method: 'POST',
      headers: { Authorization: `Bearer ${VALID_KEY}` },
    });
    const result = await requireManagementAuth(req);
    expect(result.ok).toBe(true);
  });

  it('returns ok with valid X-API-Key', async () => {
    const req = new Request('http://localhost/', {
      method: 'POST',
      headers: { 'X-API-Key': VALID_KEY },
    });
    const result = await requireManagementAuth(req);
    expect(result.ok).toBe(true);
  });

  it('returns 403 when key length differs (timing leak prevention)', async () => {
    const req = new Request('http://localhost/', {
      method: 'POST',
      headers: { Authorization: `Bearer ${VALID_KEY.slice(0, 32)}` },
    });
    const result = await requireManagementAuth(req);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.res.status).toBe(403);
    }
  });
});
