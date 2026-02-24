/**
 * Integration API keys CRUD. Admin only. Key shown once on create.
 * Reference: plans/integration_improve/01-integration-api-keys.md
 */

import { createHash } from 'node:crypto';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { validateUUID } from '../lib/validators.ts';
import { parseBody } from '../lib/validators.ts';

const ALLOWED_SCOPES = new Set(['read_fichajes', 'read_empleados', 'read_reportes']);
const NAME_MIN = 1;
const NAME_MAX = 100;

function hashKey(raw: string): string {
  return createHash('sha256').update(raw, 'utf8').digest('hex').toLowerCase();
}

function generateRawKey(): string {
  const bytes = new Uint8Array(32);
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    crypto.getRandomValues(bytes);
  } else {
    for (let i = 0; i < 32; i++) bytes[i] = Math.floor(Math.random() * 256);
  }
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function parseScopes(events: unknown): string[] | null {
  if (!Array.isArray(events) || events.length === 0) return null;
  const valid = events.filter((e) => typeof e === 'string' && ALLOWED_SCOPES.has(e));
  return valid.length > 0 ? valid : null;
}

export async function handlePostIntegrationKeys(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) {
    return Response.json(
      { error: 'Only org admins can manage integration keys.', code: 'sin_permiso' },
      { status: 403 },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json(
      { error: 'Invalid JSON body', code: 'validacion' },
      { status: 400 },
    );
  }

  const b = parseBody<{ name?: unknown; scopes?: unknown }>(body);
  const name = typeof b?.name === 'string' ? b.name.trim() : '';
  if (name.length < NAME_MIN || name.length > NAME_MAX) {
    return Response.json(
      {
        error: name.length === 0 ? 'name is required (1-100 characters).' : 'name must be at most 100 characters.',
        code: 'validacion',
      },
      { status: 400 },
    );
  }

  const scopes = parseScopes(b?.scopes);
  if (!scopes) {
    return Response.json(
      {
        error: 'scopes is required and must contain at least one of: read_fichajes, read_empleados, read_reportes.',
        code: 'validacion',
      },
      { status: 400 },
    );
  }

  const rawKey = generateRawKey();
  const keyHash = hashKey(rawKey);

  const admin = getSupabaseAdmin();
  const { data: inserted, error } = await admin
    .from('integration_api_keys')
    .insert({
      org_id: ctx.orgId,
      name,
      key_hash: keyHash,
      scopes,
      active: true,
      created_by_employee_id: ctx.employeeId,
    })
    .select('id, name, scopes, active, created_at')
    .single();

  if (error) {
    await logError('critical', 'integration_key_create_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json(
      { error: 'Error creating integration key', code: 'internal' },
      { status: 500 },
    );
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'integration_key_created',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { key_id: (inserted as { id: string }).id, name: (inserted as { name: string }).name },
    'info',
  );

  return Response.json(
    {
      ...(inserted as Record<string, unknown>),
      key: rawKey,
    },
    { status: 201 },
  );
}

export async function handleGetIntegrationKeys(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) {
    return Response.json(
      { error: 'Only org admins can manage integration keys.', code: 'sin_permiso' },
      { status: 403 },
    );
  }

  const admin = getSupabaseAdmin();
  const { data, error } = await admin
    .from('integration_api_keys')
    .select('id, name, scopes, active, last_used_at, created_at')
    .eq('org_id', ctx.orgId)
    .order('created_at', { ascending: false });

  if (error) {
    await logError('critical', 'integration_keys_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json(
      { error: 'Error listing integration keys', code: 'internal' },
      { status: 500 },
    );
  }

  return Response.json({ data: data ?? [], meta: {} });
}

export async function handlePatchIntegrationKey(req: Request, keyId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) {
    return Response.json(
      { error: 'Only org admins can manage integration keys.', code: 'sin_permiso' },
      { status: 403 },
    );
  }

  if (!validateUUID(keyId)) {
    return Response.json(
      { error: 'Invalid key id', code: 'validacion' },
      { status: 400 },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json(
      { error: 'Invalid JSON body', code: 'validacion' },
      { status: 400 },
    );
  }

  const b = parseBody<{ name?: unknown; scopes?: unknown; active?: unknown }>(body);
  const updates: Record<string, unknown> = {};

  if (b?.name !== undefined) {
    const name = typeof b.name === 'string' ? b.name.trim() : '';
    if (name.length < NAME_MIN || name.length > NAME_MAX) {
      return Response.json(
        {
          error: name.length === 0 ? 'name is required (1-100 characters).' : 'name must be at most 100 characters.',
          code: 'validacion',
        },
        { status: 400 },
      );
    }
    updates.name = name;
  }

  if (b?.scopes !== undefined) {
    const scopes = parseScopes(b.scopes);
    if (!scopes) {
      return Response.json(
        {
          error: 'scopes must contain at least one of: read_fichajes, read_empleados, read_reportes.',
          code: 'validacion',
        },
        { status: 400 },
      );
    }
    updates.scopes = scopes;
  }

  if (typeof b?.active === 'boolean') {
    updates.active = b.active;
  }

  if (Object.keys(updates).length === 0) {
    return Response.json(
      { error: 'No valid fields to update (name, scopes, active)', code: 'validacion' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  const { data: existing, error: fetchErr } = await admin
    .from('integration_api_keys')
    .select('id, org_id')
    .eq('id', keyId)
    .eq('org_id', ctx.orgId)
    .single();

  if (fetchErr || !existing) {
    return Response.json(
      { error: 'Integration key not found or does not belong to your organization.', code: 'not_found' },
      { status: 404 },
    );
  }

  const { data: updated, error: updateErr } = await admin
    .from('integration_api_keys')
    .update(updates)
    .eq('id', keyId)
    .eq('org_id', ctx.orgId)
    .select('id, name, scopes, active, last_used_at, created_at')
    .single();

  if (updateErr) {
    await logError('critical', 'integration_key_patch_failed', { orgId: ctx.orgId }, { key_id: keyId }, updateErr);
    return Response.json(
      { error: 'Error updating integration key', code: 'internal' },
      { status: 500 },
    );
  }

  if (updates.active === false) {
    const meta = getRequestMeta(req);
    await logAudit(
      'integration_key_revoked',
      { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
      { key_id: keyId },
      'info',
    );
  }

  return Response.json(updated);
}

export async function handleDeleteIntegrationKey(req: Request, keyId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminCheck = requireAdmin(ctx);
  if (adminCheck) {
    return Response.json(
      { error: 'Only org admins can manage integration keys.', code: 'sin_permiso' },
      { status: 403 },
    );
  }

  if (!validateUUID(keyId)) {
    return Response.json(
      { error: 'Invalid key id', code: 'validacion' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  const { data: existing, error: fetchErr } = await admin
    .from('integration_api_keys')
    .select('id')
    .eq('id', keyId)
    .eq('org_id', ctx.orgId)
    .single();

  if (fetchErr || !existing) {
    return Response.json(
      { error: 'Integration key not found or does not belong to your organization.', code: 'not_found' },
      { status: 404 },
    );
  }

  const { error: deleteErr } = await admin.from('integration_api_keys').delete().eq('id', keyId).eq('org_id', ctx.orgId);

  if (deleteErr) {
    await logError('critical', 'integration_key_delete_failed', { orgId: ctx.orgId }, { key_id: keyId }, deleteErr);
    return Response.json(
      { error: 'Error deleting integration key', code: 'internal' },
      { status: 500 },
    );
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'integration_key_revoked',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { key_id: keyId },
    'info',
  );

  return new Response(null, { status: 204 });
}
