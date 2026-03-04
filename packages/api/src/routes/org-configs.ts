import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';

// GET org-configs: any authenticated user (needed to gate UI by CFG-*). PATCH: admin only.
import {
  getWhitelistKeys,
  getSchema,
  validateConfigValue,
  getMaxKeysPerRequest,
} from '../lib/org-config-whitelist.ts';

function parseAndValidatePatchBody(body: unknown): { ok: true; configs: Record<string, unknown> } | { ok: false; res: Response } {
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, res: Response.json({ error: 'configs object required', code: 'validation' }, { status: 400 }) };
  }
  const configs = (body as { configs?: unknown }).configs;
  if (configs == null || typeof configs !== 'object' || Array.isArray(configs)) {
    return { ok: false, res: Response.json({ error: 'configs object required', code: 'validation' }, { status: 400 }) };
  }
  const keys = Object.keys(configs as Record<string, unknown>);
  if (keys.length === 0) {
    return { ok: false, res: Response.json({ error: 'At least one config key required', code: 'validation' }, { status: 400 }) };
  }
  if (keys.length > getMaxKeysPerRequest()) {
    return { ok: false, res: Response.json({ error: `Max ${getMaxKeysPerRequest()} configs per request`, code: 'validation' }, { status: 400 }) };
  }
  const whitelist = new Set(getWhitelistKeys());
  for (const key of keys) {
    if (!whitelist.has(key)) {
      const validKeys = getWhitelistKeys().join(', ');
      return {
        ok: false,
        res: Response.json({ error: `Config key not allowed: ${key}. Valid keys: ${validKeys}`, code: 'invalid_key' }, { status: 400 }),
      };
    }
    const val = (configs as Record<string, unknown>)[key];
    const validation = validateConfigValue(key, val);
    if (!validation.valid) {
      return { ok: false, res: Response.json({ error: validation.error, code: 'validation' }, { status: 400 }) };
    }
  }
  return { ok: true, configs: configs as Record<string, unknown> };
}

function toJsonbValue(schema: { type: string; default: boolean | number | string }, raw: unknown): unknown {
  if (schema.type === 'number') return Math.round(Number(raw));
  if (schema.type === 'select') return typeof raw === 'string' ? raw.trim().toLowerCase() : schema.default;
  if (schema.type === 'string') return typeof raw === 'string' ? raw : schema.default;
  return raw === true || raw === false ? raw : schema.default;
}

export async function handleGetOrgConfigs(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const whitelist = getWhitelistKeys();
  const admin = getSupabaseAdmin();
  const { data: rows, error } = await admin
    .from('org_configs')
    .select('key, value')
    .eq('org_id', ctx.orgId)
    .in('key', whitelist);

  if (error) {
    await logError('critical', 'org_configs_get_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al obtener configuración' }, { status: 500 });
  }

  const schemaByKey = new Map(getWhitelistKeys().map((k) => [k, getSchema(k)!]));
  const data = whitelist.map((key) => {
    const row = (rows ?? []).find((r: { key: string }) => r.key === key);
    const schema = schemaByKey.get(key)!;
    let value: unknown;
    if (row?.value != null) {
      value = schema.type === 'number' ? Number(row.value) : schema.type === 'select' ? String(row.value) : row.value;
    } else {
      value = schema.default;
    }
    return {
      key,
      value,
      type: schema.type,
      ...(schema.allowedValues && { options: schema.allowedValues }),
    };
  });

  return Response.json({ data, meta: { total: data.length } });
}

export async function handlePatchOrgConfigs(req: Request): Promise<Response> {
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

  const parsed = parseAndValidatePatchBody(body);
  if (!parsed.ok) return parsed.res;

  const admin = getSupabaseAdmin();
  const { data: existing } = await admin
    .from('org_configs')
    .select('key, value')
    .eq('org_id', ctx.orgId)
    .in('key', Object.keys(parsed.configs));

  const existingMap = new Map((existing ?? []).map((r: { key: string; value: unknown }) => [r.key, r.value]));

  const rows = Object.entries(parsed.configs).map(([key, rawVal]) => {
    const schema = getSchema(key)!;
    const newVal = toJsonbValue(schema, rawVal);
    return { org_id: ctx.orgId, key, value: newVal };
  });

  const { error: upsertErr } = await admin
    .from('org_configs')
    .upsert(rows, { onConflict: 'org_id,key' });

  if (upsertErr) {
    await logError('critical', 'org_config_update_failed', { orgId: ctx.orgId }, { keys: Object.keys(parsed.configs) }, upsertErr);
    return Response.json({ error: 'Error al actualizar configuración' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  const changes = Object.entries(parsed.configs).map(([key, rawVal]) => {
    const schema = getSchema(key)!;
    const newVal = toJsonbValue(schema, rawVal);
    const oldVal = existingMap.get(key);
    return { key, old_value: oldVal ?? null, new_value: newVal };
  });

  await logAudit(
    'org_config_updated',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip, userAgent: meta.userAgent },
    { changes },
    'info',
  );

  const updated = Object.fromEntries(
    Object.entries(parsed.configs).map(([k, v]) => {
      const schema = getSchema(k)!;
      return [k, toJsonbValue(schema, v)];
    }),
  );
  return Response.json({ data: updated });
}
