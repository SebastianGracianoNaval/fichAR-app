import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { WEBHOOK_EVENTS } from '../services/webhook-dispatch.ts';

const MAX_URL_LENGTH = 2048;

function isValidUrl(url: unknown): url is string {
  if (typeof url !== 'string') return false;
  if (url.length === 0 || url.length > MAX_URL_LENGTH) return false;
  if (!url.startsWith('https://')) return false;
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

function parseEvents(events: unknown): string[] | null {
  if (!Array.isArray(events) || events.length === 0) return null;
  const allowed = new Set(WEBHOOK_EVENTS);
  const valid = events.filter((e) => typeof e === 'string' && allowed.has(e as (typeof WEBHOOK_EVENTS)[number]));
  return valid.length > 0 ? valid : null;
}

export async function handleGetWebhooks(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) return adminCheck;

  const admin = getSupabaseAdmin();
  const { data, error } = await admin
    .from('webhooks')
    .select('id, url, events, active, created_at')
    .eq('org_id', ctx.orgId)
    .order('created_at', { ascending: false });

  if (error) {
    await logError('critical', 'webhooks_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar webhooks' }, { status: 500 });
  }

  return Response.json({ data: data ?? [] });
}

export async function handlePostWebhooks(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) return adminCheck;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON body', code: 'parse_error' }, { status: 400 });
  }

  const b = body as { url?: unknown; secret?: unknown; events?: unknown };
  if (!isValidUrl(b.url)) {
    return Response.json(
      { error: 'url requerido, HTTPS, max 2048 caracteres', code: 'validation' },
      { status: 400 },
    );
  }
  const events = parseEvents(b.events);
  if (!events) {
    return Response.json(
      { error: 'events array requerido con al menos un evento valido', code: 'validation' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  const { data: inserted, error } = await admin
    .from('webhooks')
    .insert({
      org_id: ctx.orgId,
      url: b.url,
      secret: typeof b.secret === 'string' && b.secret.length > 0 ? b.secret : null,
      events,
      active: true,
    })
    .select('id, url, events, active, created_at')
    .single();

  if (error) {
    if (error.code === '23505') {
      return Response.json({ error: 'Ya existe un webhook con esa URL', code: 'duplicate' }, { status: 400 });
    }
    await logError('critical', 'webhook_create_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al crear webhook' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('webhook_creado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { webhook_id: inserted.id, url: (inserted as { url: string }).url }, 'info');

  return Response.json(inserted, { status: 201 });
}

export async function handlePatchWebhook(req: Request, webhookId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) return adminCheck;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON body', code: 'parse_error' }, { status: 400 });
  }

  const b = body as { url?: unknown; secret?: unknown; events?: unknown; active?: unknown };
  const updates: Record<string, unknown> = {};

  if (b.url !== undefined) {
    if (!isValidUrl(b.url)) {
      return Response.json(
        { error: 'url debe ser HTTPS, max 2048 caracteres', code: 'validation' },
        { status: 400 },
      );
    }
    updates.url = b.url;
  }
  if (b.events !== undefined) {
    const events = parseEvents(b.events);
    if (!events) {
      return Response.json(
        { error: 'events array con al menos un evento valido', code: 'validation' },
        { status: 400 },
      );
    }
    updates.events = events;
  }
  if (b.secret !== undefined) {
    updates.secret = typeof b.secret === 'string' && b.secret.length > 0 ? b.secret : null;
  }
  if (typeof b.active === 'boolean') updates.active = b.active;

  if (Object.keys(updates).length === 0) {
    return Response.json({ error: 'Ningun campo para actualizar', code: 'validation' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const { data, error } = await admin
    .from('webhooks')
    .update(updates)
    .eq('id', webhookId)
    .eq('org_id', ctx.orgId)
    .select('id, url, events, active, created_at')
    .single();

  if (error || !data) {
    return Response.json({ error: 'Webhook no encontrado' }, { status: 404 });
  }

  const meta = getRequestMeta(req);
  await logAudit('webhook_actualizado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { webhook_id: webhookId }, 'info');

  return Response.json(data);
}

export async function handleDeleteWebhook(req: Request, webhookId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) return adminCheck;

  const admin = getSupabaseAdmin();
  const { error } = await admin.from('webhooks').delete().eq('id', webhookId).eq('org_id', ctx.orgId);

  if (error) {
    return Response.json({ error: 'Error al eliminar webhook' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('webhook_eliminado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { webhook_id: webhookId }, 'info');

  return new Response(null, { status: 204 });
}
