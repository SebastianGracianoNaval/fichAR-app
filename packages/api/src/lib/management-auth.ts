import { timingSafeEqual } from 'node:crypto';

export async function requireManagementAuth(
  req: Request,
): Promise<{ ok: true } | { ok: false; res: Response }> {
  const key =
    req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '').trim() ||
    req.headers.get('X-API-Key')?.trim();
  const expected = process.env.MANAGEMENT_API_KEY?.trim();

  if (!expected) {
    return {
      ok: false,
      res: Response.json(
        { error: 'Management API not configured' },
        { status: 503 },
      ),
    };
  }

  if (!key) {
    return {
      ok: false,
      res: Response.json({ error: 'Forbidden' }, { status: 403 }),
    };
  }

  if (key.length !== expected.length) {
    return {
      ok: false,
      res: Response.json({ error: 'Forbidden' }, { status: 403 }),
    };
  }

  const keyBuf = Buffer.from(key, 'utf8');
  const expectedBuf = Buffer.from(expected, 'utf8');
  if (!timingSafeEqual(keyBuf, expectedBuf)) {
    return {
      ok: false,
      res: Response.json({ error: 'Forbidden' }, { status: 403 }),
    };
  }

  return { ok: true };
}
