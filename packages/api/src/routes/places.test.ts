import { describe, expect, it } from 'bun:test';
import { handleRequest } from '../index.ts';

describe('places API', () => {
  it('POST /places/import without auth returns 401', async () => {
    const formData = new FormData();
    formData.append('file', new Blob(['nombre,direccion,lat,long,radio_m,dias\nOficina,Av 1,-34.6,-58.4,100,L,M,X,J,V']), 'test.csv');
    const req = new Request('http://localhost/api/v1/places/import', {
      method: 'POST',
      body: formData,
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });
});
