import './load-env.ts';
import { API_VERSION, printBanner } from '@fichar/shared';
import {
  handleForgotPassword,
  handleLogin,
  handleRegister,
  handleRegisterOrg,
  handleCreateInvite,
  handleGetMe,
  handleMfaVerify,
  handleMfaEnroll,
  handleMfaEnrollVerify,
} from './routes/auth.ts';
import { handleGetFichajes, handlePostFichajes } from './routes/fichajes.ts';
import {
  handleGetLegalFichajes,
  handleGetLegalAuditLogs,
  handleGetLegalHashChain,
  handlePostLegalExport,
} from './routes/legal.ts';

export function handleHealth(): Response {
  return Response.json({ status: 'ok', timestamp: new Date().toISOString() }, { status: 200 });
}

function getAllowedOrigins(): string[] {
  const raw = process.env.CORS_ORIGINS ?? '';
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
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
  return null;
}

function applySecurityHeaders(res: Response, req: Request): Response {
  const headers = new Headers(res.headers);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('X-Frame-Options', 'DENY');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  headers.set('Cache-Control', 'no-store');

  const corsOrigin = resolveCorsOrigin(req);
  if (corsOrigin) {
    headers.set('Access-Control-Allow-Origin', corsOrigin);
    headers.set('Vary', 'Origin');
    headers.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
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
    const buf = await res.arrayBuffer();
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

  let res: Response;
  if (req.method === 'POST' && path === `${base}/auth/register-org`) {
    res = await handleRegisterOrg(req);
  } else if (req.method === 'POST' && path === `${base}/auth/register`) {
    res = await handleRegister(req);
  } else if (req.method === 'POST' && path === `${base}/auth/login`) {
    res = await handleLogin(req);
  } else if (req.method === 'POST' && path === `${base}/auth/forgot-password`) {
    res = await handleForgotPassword(req);
  } else if (req.method === 'POST' && path === `${base}/auth/invite`) {
    res = await handleCreateInvite(req);
  } else if (req.method === 'GET' && path === `${base}/me`) {
    res = await handleGetMe(req);
  } else if (req.method === 'POST' && path === `${base}/auth/mfa/verify`) {
    res = await handleMfaVerify(req);
  } else if (req.method === 'POST' && path === `${base}/auth/mfa/enroll`) {
    res = await handleMfaEnroll(req);
  } else if (req.method === 'POST' && path === `${base}/auth/mfa/enroll-verify`) {
    res = await handleMfaEnrollVerify(req);
  } else if (req.method === 'POST' && path === `${base}/fichajes`) {
    res = await handlePostFichajes(req);
  } else if (req.method === 'GET' && path === `${base}/fichajes`) {
    res = await handleGetFichajes(req);
  } else if (req.method === 'GET' && path === `${base}/legal/fichajes`) {
    res = await handleGetLegalFichajes(req);
  } else if (req.method === 'GET' && path === `${base}/legal/audit-logs`) {
    res = await handleGetLegalAuditLogs(req);
  } else if (req.method === 'GET' && path === `${base}/legal/hash-chain`) {
    res = await handleGetLegalHashChain(req);
  } else if (req.method === 'POST' && path === `${base}/legal/export`) {
    res = await handlePostLegalExport(req);
  } else {
    return applySecurityHeaders(new Response('Not Found', { status: 404 }), req);
  }

  const compressed = await maybeCompress(res, req);
  return applySecurityHeaders(compressed, req);
}

export async function handleRequest(req: Request): Promise<Response> {
  return fetchHandler(req);
}

if (import.meta.main) {
  printBanner();
  const PORT = process.env.PORT ?? 3000;
  const server = Bun.serve({ port: PORT, fetch: fetchHandler });
  console.log(`API: http://localhost:${server.port}\n`);
}
