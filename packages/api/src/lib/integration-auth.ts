/**
 * Integration API key auth. Resolve org and scopes from X-Api-Key or Bearer.
 * Reference: plans/integration_improve/02-integration-auth-and-rate-limit.md
 */

import { createHash } from 'node:crypto';
import { getSupabaseAdmin } from './supabase.ts';
import { logError } from './logger.ts';

export interface IntegrationContext {
  orgId: string;
  keyId: string;
  scopes: string[];
}

function hashKey(raw: string): string {
  return createHash('sha256').update(raw, 'utf8').digest('hex').toLowerCase();
}

function getRawKeyFromRequest(req: Request): string | null {
  const apiKey = req.headers.get('x-api-key')?.trim();
  if (apiKey && apiKey.length > 0) return apiKey;
  const auth = req.headers.get('authorization');
  if (!auth || !/^Bearer\s+/i.test(auth)) return null;
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  return token.length > 0 ? token : null;
}

export async function requireIntegrationKey(
  req: Request,
): Promise<{ ok: true; ctx: IntegrationContext } | { ok: false; res: Response }> {
  const rawKey = getRawKeyFromRequest(req);
  if (!rawKey) {
    return {
      ok: false,
      res: Response.json(
        {
          error:
            'API key required. Send it in X-Api-Key header or Authorization: Bearer <key>. Create one in Configuration.',
          code: 'unauthorized',
        },
        { status: 401 },
      ),
    };
  }

  const keyHash = hashKey(rawKey);
  const admin = getSupabaseAdmin();
  const { data: row, error } = await admin
    .from('integration_api_keys')
    .select('id, org_id, scopes')
    .eq('key_hash', keyHash)
    .eq('active', true)
    .maybeSingle();

  if (error) {
    await logError('critical', 'integration_auth_lookup_failed', undefined, {}, error);
    return {
      ok: false,
      res: Response.json(
        { error: 'Invalid or revoked API key. Check the key or create a new one in Configuration.', code: 'unauthorized' },
        { status: 401 },
      ),
    };
  }

  if (!row) {
    void logError('warning', 'integration_auth_failed', undefined, { reason: 'invalid_or_revoked' }, undefined);
    return {
      ok: false,
      res: Response.json(
        { error: 'Invalid or revoked API key. Check the key or create a new one in Configuration.', code: 'unauthorized' },
        { status: 401 },
      ),
    };
  }

  const r = row as { id: string; org_id: string; scopes: string[] };
  void updateLastUsedAt(r.id).catch(() => {});

  return {
    ok: true,
    ctx: {
      orgId: r.org_id,
      keyId: r.id,
      scopes: Array.isArray(r.scopes) ? r.scopes : [],
    },
  };
}

async function updateLastUsedAt(keyId: string): Promise<void> {
  const admin = getSupabaseAdmin();
  await admin.from('integration_api_keys').update({ last_used_at: new Date().toISOString() }).eq('id', keyId);
}

export function requireIntegrationScope(ctx: IntegrationContext, scope: string): Response | null {
  if (ctx.scopes.includes(scope)) return null;
  return Response.json(
    {
      error: `This API key does not have permission for this endpoint. Required scope: ${scope}. Add the scope in Configuration.`,
      code: 'sin_permiso',
    },
    { status: 403 },
  );
}
