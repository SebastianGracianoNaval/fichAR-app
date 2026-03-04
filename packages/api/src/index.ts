import './load-env.ts';
import { API_VERSION, printBanner } from '@fichar/shared';
import { errJson } from './lib/errors.ts';
import { runWithOrgConfigCache } from './lib/org-config-cache.ts';
import { matchRoute } from './routes.ts';

function getAllowedOrigins(): string[] {
  const raw = process.env.CORS_ORIGINS ?? '';
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function warnCorsIfProduction(): void {
  if (process.env.NODE_ENV !== 'production') return;
  const origins = getAllowedOrigins();
  if (origins.length === 0) {
    console.warn(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        severity: 'warning',
        action: 'cors_empty_production',
        details: { reason: 'CORS_ORIGINS empty in production; no origin allowed.' },
      })
    );
  }
}

export function handleHealth(): Response {
  return Response.json({ status: 'ok', timestamp: new Date().toISOString() }, { status: 200 });
}

function resolveCorsOrigin(req: Request): string | null {
  const origin = req.headers.get('origin');
  if (!origin) return null;

  const allowed = getAllowedOrigins();
  if (process.env.NODE_ENV !== 'production' && allowed.length === 0) {
    return '*';
  }
  if (allowed.includes('*')) return '*';
  if (allowed.includes(origin)) return origin;
  if (process.env.NODE_ENV !== 'production') {
    try {
      const u = new URL(origin);
      if (u.hostname === 'localhost' || u.hostname === '127.0.0.1') return origin;
    } catch {
      /* ignore */
    }
  }
  return null;
}

function applySecurityHeaders(res: Response, req: Request): Response {
  const headers = new Headers(res.headers);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('X-Frame-Options', 'DENY');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  headers.set('Content-Security-Policy', "default-src 'self'; frame-ancestors 'none'");
  headers.set('Cache-Control', 'no-store');

  const corsOrigin = resolveCorsOrigin(req);
  if (corsOrigin) {
    headers.set('Access-Control-Allow-Origin', corsOrigin);
    headers.set('Vary', 'Origin');
    headers.set('Access-Control-Allow-Methods', 'GET,POST,PATCH,PUT,DELETE,OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Api-Key');
    headers.set('Access-Control-Max-Age', '600');
  }

  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers,
  });
}

async function maybeCompress(res: Response, req: Request): Promise<Response> {
  const accept = req.headers.get('accept-encoding') ?? '';
  if (!accept.includes('gzip')) return res;
  const ct = res.headers.get('content-type') ?? '';
  if (!ct.includes('application/json')) return res;
  if (res.status < 200 || res.status >= 300) return res;

  try {
    const buf = await res.clone().arrayBuffer();
    if (buf.byteLength < 256) return res;
    const compressed = Bun.gzipSync(new Uint8Array(buf));
    const headers = new Headers(res.headers);
    headers.set('Content-Encoding', 'gzip');
    return new Response(compressed, { status: res.status, headers });
  } catch {
    return res;
  }
}

async function fetchHandler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname;
  const base = `/api/${API_VERSION}`;

  if (req.method === 'OPTIONS') {
    const preflight = new Response(null, { status: 204 });
    return applySecurityHeaders(preflight, req);
  }

  if (path === `${base}/health` || path === '/health') {
    return applySecurityHeaders(handleHealth(), req);
  }

  if (process.env.NODE_ENV === 'production' && getAllowedOrigins().length === 0 && req.headers.get('origin')) {
    return applySecurityHeaders(
      Response.json({ error: 'CORS no configurado para producción', code: 'cors_not_configured' }, { status: 403 }),
      req,
    );
  }

  const matched = matchRoute(req.method, path);
  if (!matched) {
    return applySecurityHeaders(errJson(404, 'Ruta no encontrada', 'not_found'), req);
  }
  const res = await runWithOrgConfigCache(() => matched.handler(req));

  const compressed = await maybeCompress(res, req);
  return applySecurityHeaders(compressed, req);
}

export async function handleRequest(req: Request): Promise<Response> {
  return fetchHandler(req);
}

if (import.meta.main) {
  warnCorsIfProduction();
  printBanner();
  const PORT = process.env.PORT ?? 3000;
  const server = Bun.serve({ port: PORT, fetch: fetchHandler });
  console.log(`API: http://localhost:${server.port}\n`);
}
