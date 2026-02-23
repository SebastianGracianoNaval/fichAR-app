import { decodeJwt } from 'jose';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { logAudit, logError } from '../lib/logger.ts';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function handleGetMeDevices(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  let currentSessionId: string | null = null;
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (token) {
    try {
      const payload = decodeJwt(token) as { session_id?: string };
      currentSessionId = payload.session_id ?? null;
    } catch {
      await logError('info', 'me_devices_jwt_decode_failed', { orgId: ctx.orgId }, { reason: 'session_id_unavailable' });
    }
  }

  const admin = getSupabaseAdmin();
  const { data: sessions, error } = await admin
    .schema('auth')
    .from('sessions')
    .select('id, created_at, updated_at')
    .eq('user_id', ctx.userId)
    .order('updated_at', { ascending: false });

  if (error) {
    await logError('critical', 'me_devices_list_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, {}, error);
    return Response.json({ error: 'Error al listar dispositivos', code: 'internal' }, { status: 500 });
  }

  const devices = (sessions ?? []).map((s) => ({
    id: s.id,
    created_at: s.created_at,
    updated_at: s.updated_at,
    current: s.id === currentSessionId,
  }));

  return Response.json({ data: devices });
}

export async function handlePostMeDevicesRevoke(req: Request, sessionId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!UUID_REGEX.test(sessionId)) {
    return Response.json({ error: 'ID de sesión inválido', code: 'invalid_id' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const { data: existing } = await admin
    .schema('auth')
    .from('sessions')
    .select('id')
    .eq('id', sessionId)
    .eq('user_id', ctx.userId)
    .maybeSingle();

  if (!existing) {
    return Response.json({ error: 'Sesión no encontrada', code: 'not_found' }, { status: 404 });
  }

  const { error } = await admin
    .schema('auth')
    .from('sessions')
    .delete()
    .eq('id', sessionId)
    .eq('user_id', ctx.userId);

  if (error) {
    await logError('warning', 'me_devices_revoke_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, { session_id: sessionId }, error);
    return Response.json({ error: 'Error al revocar. Intentá de nuevo.', code: 'internal' }, { status: 500 });
  }

  await logAudit('dispositivo_revocado', { orgId: ctx.orgId, employeeId: ctx.employeeId }, { session_id: sessionId }, 'info');

  return Response.json({ ok: true });
}
