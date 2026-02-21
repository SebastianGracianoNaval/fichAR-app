import { API_VERSION } from '@fichar/shared';

export function handleHealth(): Response {
  return Response.json({ status: 'ok', timestamp: new Date().toISOString() }, { status: 200 });
}

function fetchHandler(req: Request): Response {
  const url = new URL(req.url);
  const path = url.pathname;
  if (path === `/api/${API_VERSION}/health` || path === '/health') {
    return handleHealth();
  }
  return new Response('Not Found', { status: 404 });
}

if (import.meta.main) {
  const PORT = process.env.PORT ?? 3000;
  const server = Bun.serve({ port: PORT, fetch: fetchHandler });
  console.log(`fichAR API running at http://localhost:${server.port}`);
}
