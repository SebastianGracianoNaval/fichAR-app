const FAIL_THRESHOLD = 5;
const WINDOW_MS = 5 * 60 * 1000;
const BLOCK_MS = 15 * 60 * 1000;

interface Entry {
  failures: number;
  windowStart: number;
  blockedUntil?: number;
}

const store = new Map<string, Entry>();

function getClientIp(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for');
  if (forwarded) return forwarded.split(',')[0].trim();
  return req.headers.get('x-real-ip') ?? 'unknown';
}

export function checkLoginRateLimit(req: Request): { allowed: boolean; retryAfter?: number } {
  const ip = getClientIp(req);
  const now = Date.now();
  let entry = store.get(ip);

  if (entry?.blockedUntil && entry.blockedUntil > now) {
    return { allowed: false, retryAfter: Math.ceil((entry.blockedUntil - now) / 1000) };
  }

  if (!entry || now - entry.windowStart > WINDOW_MS) {
    entry = { failures: 0, windowStart: now };
    store.set(ip, entry);
  }

  if (entry.failures >= FAIL_THRESHOLD) {
    entry.blockedUntil = now + BLOCK_MS;
    return { allowed: false, retryAfter: BLOCK_MS / 1000 };
  }

  return { allowed: true };
}

export function recordLoginFailure(req: Request): void {
  const ip = getClientIp(req);
  const now = Date.now();
  let entry = store.get(ip);

  if (!entry || now - entry.windowStart > WINDOW_MS) {
    entry = { failures: 0, windowStart: now };
    store.set(ip, entry);
  }

  entry.failures += 1;
  if (entry.failures >= FAIL_THRESHOLD) {
    entry.blockedUntil = now + BLOCK_MS;
  }
}

export function clearLoginFailure(req: Request): void {
  const ip = getClientIp(req);
  store.delete(ip);
}
