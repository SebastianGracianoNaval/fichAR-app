/**
 * Integration API: read-only endpoints for fichajes and empleados.
 * Auth via API key (gateway). Reference: plans/integration_improve/02, 03, 04.
 */

import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireIntegrationKey, requireIntegrationScope, type IntegrationContext } from '../lib/integration-auth.ts';
import { checkIntegrationRateLimit } from '../lib/integration-rate-limit.ts';
import { validatePagination, validateUUID } from '../lib/validators.ts';
import { logError } from '../lib/logger.ts';

type IntegrationHandler = (req: Request, ctx: IntegrationContext) => Promise<Response>;

export function integrationGateway(requiredScope: string, handler: IntegrationHandler): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const authResult = await requireIntegrationKey(req);
    if (!authResult.ok) return authResult.res;
    const { ctx } = authResult;

    const limitResult = await checkIntegrationRateLimit(ctx.keyId);
    if (!limitResult.allowed) {
      void logError('warning', 'integration_rate_limit', { keyId: ctx.keyId }, {}, undefined);
      const headers: Record<string, string> = {};
      if (limitResult.retryAfter != null) headers['Retry-After'] = String(limitResult.retryAfter);
      return Response.json(
        {
          error: `Rate limit exceeded (100 requests per minute). Retry after ${limitResult.retryAfter ?? 60} seconds.`,
          code: 'rate_limit',
        },
        { status: 429, headers },
      );
    }

    const scopeRes = requireIntegrationScope(ctx, requiredScope);
    if (scopeRes) return scopeRes;

    return handler(req, ctx);
  };
}

function parseIsoDate(s: string | null): Date | null {
  if (!s || typeof s !== 'string') return null;
  const trimmed = s.trim();
  if (trimmed.length === 0) return null;
  const d = new Date(trimmed);
  return Number.isNaN(d.getTime()) ? null : d;
}

export async function handleGetIntegrationsFichajes(req: Request, ctx: IntegrationContext): Promise<Response> {
  const url = new URL(req.url);
  const desdeParam = url.searchParams.get('desde');
  const hastaParam = url.searchParams.get('hasta');
  const empleadoId = url.searchParams.get('empleado_id');
  const { limit, offset } = validatePagination(
    url.searchParams.get('limit'),
    url.searchParams.get('offset'),
    { defaultLimit: 50, maxLimit: 200 },
  );

  if (!desdeParam || !hastaParam) {
    return Response.json(
      {
        error: 'desde and hasta are required (ISO 8601, e.g. 2026-02-01 or 2026-02-01T00:00:00Z).',
        code: 'validacion',
      },
      { status: 400 },
    );
  }

  const desdeDate = parseIsoDate(desdeParam);
  const hastaDate = parseIsoDate(hastaParam);
  if (!desdeDate || !hastaDate) {
    return Response.json(
      { error: 'desde and hasta must be valid ISO 8601 dates.', code: 'validacion' },
      { status: 400 },
    );
  }

  const desde = desdeDate.toISOString();
  const hasta = hastaDate.toISOString();
  if (desde > hasta) {
    return Response.json(
      { error: 'desde must be before or equal to hasta.', code: 'validacion' },
      { status: 400 },
    );
  }

  const diffDays = (hastaDate.getTime() - desdeDate.getTime()) / (1000 * 60 * 60 * 24);
  if (diffDays > 365) {
    return Response.json(
      { error: 'Date range cannot exceed 365 days.', code: 'validacion' },
      { status: 400 },
    );
  }

  if (empleadoId) {
    if (!validateUUID(empleadoId)) {
      return Response.json(
        { error: 'empleado_id must be a valid UUID.', code: 'validacion' },
        { status: 400 },
      );
    }
    const admin = getSupabaseAdmin();
    const { data: emp } = await admin
      .from('employees')
      .select('id')
      .eq('id', empleadoId)
      .eq('org_id', ctx.orgId)
      .maybeSingle();
    if (!emp) {
      return Response.json(
        { error: 'empleado_id not found or does not belong to this organization.', code: 'validacion' },
        { status: 400 },
      );
    }
  }

  const admin = getSupabaseAdmin();
  let query = admin
    .from('fichajes')
    .select('id, user_id, org_id, tipo, timestamp_servidor, timestamp_dispositivo, lugar_id, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .gte('timestamp_servidor', desde)
    .lte('timestamp_servidor', hasta)
    .order('timestamp_servidor', { ascending: false })
    .range(offset, offset + limit - 1);

  if (empleadoId) query = query.eq('user_id', empleadoId);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'integrations_fichajes_failed', { orgId: ctx.orgId, keyId: ctx.keyId }, { endpoint: 'integrations/fichajes' }, error);
    return Response.json(
      { error: 'Error listing fichajes. Try again later.', code: 'internal' },
      { status: 500 },
    );
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0, limit, offset } });
}

export async function handleGetIntegrationsEmpleados(req: Request, ctx: IntegrationContext): Promise<Response> {
  const url = new URL(req.url);
  const statusParam = url.searchParams.get('status') ?? 'activo';
  if (statusParam !== 'activo' && statusParam !== 'despedido') {
    return Response.json(
      { error: 'status must be activo or despedido.', code: 'validacion' },
      { status: 400 },
    );
  }

  const { limit, offset } = validatePagination(
    url.searchParams.get('limit'),
    url.searchParams.get('offset'),
    { defaultLimit: 50, maxLimit: 200 },
  );

  const admin = getSupabaseAdmin();
  const { data, error, count } = await admin
    .from('employees')
    .select('id, org_id, email, name, role, status, modalidad, fecha_ingreso, fecha_egreso, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .eq('status', statusParam)
    .order('name', { ascending: true })
    .range(offset, offset + limit - 1);

  if (error) {
    await logError('critical', 'integrations_empleados_failed', { orgId: ctx.orgId, keyId: ctx.keyId }, { endpoint: 'integrations/empleados' }, error);
    return Response.json(
      { error: 'Error listing employees. Try again later.', code: 'internal' },
      { status: 500 },
    );
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0, limit, offset } });
}
