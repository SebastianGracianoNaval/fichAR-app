import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index.ts';

describe('legal API', () => {
  it('POST /legal/export without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/legal/export', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tipo: 'fichajes', desde: '2026-01-01', hasta: '2026-01-31' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });
});
