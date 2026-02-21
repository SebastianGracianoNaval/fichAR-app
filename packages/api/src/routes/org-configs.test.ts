import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index';

describe('org-configs API', () => {
  it('GET /org-configs without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/org-configs');
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('PATCH /org-configs without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/org-configs', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ configs: { geolocalizacion_obligatoria: true } }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

});
