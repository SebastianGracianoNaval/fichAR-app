import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index.ts';

const base = '/api/v1';

describe('integration-keys API', () => {
  it('POST /integration-keys without auth returns 401', async () => {
    const req = new Request(`http://localhost${base}/integration-keys`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'test', scopes: ['read_fichajes'] }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('GET /integration-keys without auth returns 401', async () => {
    const req = new Request(`http://localhost${base}/integration-keys`, { method: 'GET' });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('PATCH /integration-keys/:id without auth returns 401', async () => {
    const req = new Request(`http://localhost${base}/integration-keys/00000000-0000-0000-0000-000000000001`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ active: false }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('DELETE /integration-keys/:id without auth returns 401', async () => {
    const req = new Request(`http://localhost${base}/integration-keys/00000000-0000-0000-0000-000000000001`, {
      method: 'DELETE',
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });
});
