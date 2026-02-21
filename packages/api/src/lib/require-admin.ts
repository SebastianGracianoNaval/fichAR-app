import type { AuthContext } from './auth-middleware.ts';

export function requireAdmin(ctx: AuthContext): Response | null {
  if (ctx.role !== 'admin') {
    return Response.json({ error: 'No tenés permiso para esta acción', code: 'sin_permiso' }, { status: 403 });
  }
  return null;
}
