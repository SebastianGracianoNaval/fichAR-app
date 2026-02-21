import './load-env.ts';
import { API_VERSION, printBanner } from '@fichar/shared';
import {
  handleForgotPassword,
  handleLogin,
  handleRegister,
  handleRegisterOrg,
  handleCreateInvite,
} from './routes/auth.ts';
import { handleGetFichajes, handlePostFichajes } from './routes/fichajes.ts';

export function handleHealth(): Response {
  return Response.json({ status: 'ok', timestamp: new Date().toISOString() }, { status: 200 });
}

async function fetchHandler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname;
  const base = `/api/${API_VERSION}`;

  if (path === `${base}/health` || path === '/health') {
    return handleHealth();
  }

  if (req.method === 'POST' && path === `${base}/auth/register-org`) {
    return handleRegisterOrg(req);
  }
  if (req.method === 'POST' && path === `${base}/auth/register`) {
    return handleRegister(req);
  }
  if (req.method === 'POST' && path === `${base}/auth/login`) {
    return handleLogin(req);
  }
  if (req.method === 'POST' && path === `${base}/auth/forgot-password`) {
    return handleForgotPassword(req);
  }
  if (req.method === 'POST' && path === `${base}/auth/invite`) {
    return handleCreateInvite(req);
  }
  if (req.method === 'POST' && path === `${base}/fichajes`) {
    return handlePostFichajes(req);
  }
  if (req.method === 'GET' && path === `${base}/fichajes`) {
    return handleGetFichajes(req);
  }

  return new Response('Not Found', { status: 404 });
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
