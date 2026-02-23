import { describe, expect, it, beforeAll, afterAll } from 'bun:test';
import { handleRequest } from '../index.ts';

const VALID_KEY = 'a'.repeat(64);
const base = '/api/v1';

describe('Management organizations', () => {
  const originalKey = process.env.MANAGEMENT_API_KEY;

  beforeAll(() => {
    process.env.MANAGEMENT_API_KEY = VALID_KEY;
  });

  afterAll(() => {
    process.env.MANAGEMENT_API_KEY = originalKey;
  });

  it('POST /management/organizations without auth returns 403', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ orgName: 'Test', adminEmail: 'a@b.com' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(403);
  });

  it('POST /management/organizations with invalid key returns 403', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer wrong-key',
      },
      body: JSON.stringify({ orgName: 'Test', adminEmail: 'a@b.com' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(403);
  });

  it('POST /management/organizations without MANAGEMENT_API_KEY returns 503', async () => {
    const saved = process.env.MANAGEMENT_API_KEY;
    delete process.env.MANAGEMENT_API_KEY;
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${VALID_KEY}`,
      },
      body: JSON.stringify({ orgName: 'Test', adminEmail: 'a@b.com' }),
    });
    const res = await handleRequest(req);
    process.env.MANAGEMENT_API_KEY = saved;
    expect(res.status).toBe(503);
  });

  it('POST /management/organizations with valid key, missing body returns 400', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${VALID_KEY}`,
      },
      body: JSON.stringify({}),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
  });

  it('POST /management/organizations with valid key, empty orgName returns 400', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${VALID_KEY}`,
      },
      body: JSON.stringify({ orgName: '', adminEmail: 'a@b.com' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
  });

  it('POST /management/organizations with valid key, invalid email returns 400', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${VALID_KEY}`,
      },
      body: JSON.stringify({ orgName: 'Test', adminEmail: 'invalid' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
  });
});
