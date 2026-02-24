import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index.ts';

const base = '/api/v1';

describe('alertas API', () => {
  it('GET /alertas without auth returns 401', async () => {
    const req = new Request(`http://localhost${base}/alertas`, { method: 'GET' });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });
});
