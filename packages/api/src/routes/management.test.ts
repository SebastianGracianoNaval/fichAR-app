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

  it('GET /management/organizations without auth returns 403', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, { method: 'GET' });
    const res = await handleRequest(req);
    expect(res.status).toBe(403);
  });

  it('GET /management/organizations with invalid key returns 403', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'GET',
      headers: { Authorization: 'Bearer wrong-key' },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(403);
  });

  it('GET /management/organizations without MANAGEMENT_API_KEY returns 503', async () => {
    const saved = process.env.MANAGEMENT_API_KEY;
    delete process.env.MANAGEMENT_API_KEY;
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${VALID_KEY}` },
    });
    const res = await handleRequest(req);
    process.env.MANAGEMENT_API_KEY = saved;
    expect(res.status).toBe(503);
  });

  it('GET /management/organizations with valid auth returns 200 and body shape', async () => {
    const req = new Request(`http://localhost${base}/management/organizations`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${VALID_KEY}` },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(200);
    const data = (await res.json()) as { items: unknown[]; total: number; page: number; limit: number };
    expect(Array.isArray(data.items)).toBe(true);
    expect(typeof data.total).toBe('number');
    expect(typeof data.page).toBe('number');
    expect(typeof data.limit).toBe('number');
  });

  it('GET /management/organizations/:id without auth returns 403', async () => {
    const req = new Request(
      `http://localhost${base}/management/organizations/550e8400-e29b-41d4-a716-446655440000`,
      { method: 'GET' },
    );
    const res = await handleRequest(req);
    expect(res.status).toBe(403);
  });

  it('GET /management/organizations/:id with invalid id returns 400', async () => {
    const req = new Request(`http://localhost${base}/management/organizations/not-a-uuid`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${VALID_KEY}` },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
  });

  it('GET /management/stats without auth returns 403', async () => {
    const req = new Request(`http://localhost${base}/management/stats`, { method: 'GET' });
    const res = await handleRequest(req);
    expect(res.status).toBe(403);
  });

  it('GET /management/stats with valid auth returns 200 and body shape', async () => {
    const req = new Request(`http://localhost${base}/management/stats`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${VALID_KEY}` },
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(200);
    const data = (await res.json()) as { organization_count?: number; employee_count?: number };
    expect(typeof data.organization_count).toBe('number');
    expect(typeof data.employee_count).toBe('number');
  });

  it('GET /management/organizations/:id with nonexistent id returns 404', async () => {
    const req = new Request(
      `http://localhost${base}/management/organizations/550e8400-e29b-41d4-a716-446655440000`,
      {
        method: 'GET',
        headers: { Authorization: `Bearer ${VALID_KEY}` },
      },
    );
    const res = await handleRequest(req);
    expect(res.status).toBe(404);
  });
});
