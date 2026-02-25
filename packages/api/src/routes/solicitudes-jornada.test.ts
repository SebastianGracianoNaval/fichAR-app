import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index.ts';

describe('solicitudes-jornada API', () => {
  it('GET /solicitudes-jornada without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/solicitudes-jornada');
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('POST /solicitudes-jornada without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/solicitudes-jornada', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tipo: 'mas_horas' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('PATCH /solicitudes-jornada/:id without auth returns 401', async () => {
    const req = new Request(
      'http://localhost/api/v1/solicitudes-jornada/00000000-0000-0000-0000-000000000001',
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ estado: 'rechazada' }),
      },
    );
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });
});
