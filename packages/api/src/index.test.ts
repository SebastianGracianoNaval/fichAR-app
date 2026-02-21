import { describe, expect, it } from 'bun:test';
import { handleHealth, handleRequest } from './index';

describe('Health endpoint', () => {
  it('returns 200 with status ok and timestamp', async () => {
    const res = handleHealth();
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string; timestamp: string };
    expect(body.status).toBe('ok');
    expect(body.timestamp).toBeDefined();
  });
});

describe('Auth validation', () => {
  it('POST /auth/register-org rejects missing fields with 400', async () => {
    const req = new Request('http://localhost/api/v1/auth/register-org', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error?: string };
    expect(body.error).toContain('Faltan campos');
  });

  it('POST /auth/register-org rejects invalid password', async () => {
    const req = new Request('http://localhost/api/v1/auth/register-org', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        orgName: 'Test',
        adminEmail: 'a@b.com',
        adminPassword: 'short',
        adminName: 'Admin',
        adminDni: '123',
        adminCuil: '20-12345678-9',
      }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error?: string };
    expect(body.error).toContain('Contraseña');
  });

  it('POST /auth/forgot-password rejects invalid email', async () => {
    const req = new Request('http://localhost/api/v1/auth/forgot-password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'invalid' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
  });

  it('POST /auth/login returns 401 with invalid credentials (no Supabase)', async () => {
    const req = new Request('http://localhost/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'invalid-email', password: 'x' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('POST /fichajes without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/fichajes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tipo: 'entrada' }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('GET /fichajes without auth returns 401', async () => {
    const req = new Request('http://localhost/api/v1/fichajes');
    const res = await handleRequest(req);
    expect(res.status).toBe(401);
  });

  it('POST /auth/register rejects missing inviteToken', async () => {
    const req = new Request('http://localhost/api/v1/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'a@b.com',
        password: 'Pass123',
        name: 'X',
        dni: '1',
        cuil: '20-12345678-9',
      }),
    });
    const res = await handleRequest(req);
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error?: string };
    expect(body.error).toContain('inviteToken');
  });
});
