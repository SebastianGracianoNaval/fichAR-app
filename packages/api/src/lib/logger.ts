import { getSupabaseAdmin } from './supabase.ts';

export type AuditSeverity = 'info' | 'warning' | 'critical';

export interface AuditContext {
  orgId?: string;
  userId?: string;
  employeeId?: string;
  ip?: string;
  userAgent?: string | null;
}

export function getRequestMeta(req: Request): { ip: string; userAgent: string | null } {
  const forwarded = req.headers.get('x-forwarded-for');
  const ip = forwarded ? forwarded.split(',')[0].trim() : req.headers.get('x-real-ip') ?? 'unknown';
  const userAgent = req.headers.get('user-agent');
  return { ip, userAgent };
}

function sanitizeDetails(details: Record<string, unknown>): Record<string, unknown> {
  const forbidden = ['password', 'token', 'refresh_token', 'secret', 'cuil'];
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(details)) {
    const keyLower = k.toLowerCase();
    if (forbidden.some((f) => keyLower.includes(f))) continue;
    if (typeof v === 'string' && k.toLowerCase().includes('cuil') && v.length > 4) {
      out[k] = `***${v.slice(-4)}`;
    } else {
      out[k] = v;
    }
  }
  return out;
}

export async function logAudit(
  action: string,
  ctx: AuditContext,
  details: Record<string, unknown> = {},
  severity: AuditSeverity = 'info',
): Promise<void> {
  const { resource_type, resource_id, ...rest } = details;
  const sanitized = sanitizeDetails(rest);

  const ipVal = ctx.ip && ctx.ip !== 'unknown' ? ctx.ip : null;

  try {
    const admin = getSupabaseAdmin();
    await admin.from('audit_logs').insert({
      org_id: ctx.orgId ?? null,
      user_id: ctx.employeeId ?? ctx.userId ?? null,
      action,
      resource_type: (resource_type as string) ?? null,
      resource_id: (resource_id as string) ?? null,
      details: sanitized,
      ip: ipVal,
      user_agent: ctx.userAgent ?? null,
      severity,
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('audit_logs insert failed', { action, error: msg });
    await logError('critical', 'audit_logs_insert_failed', ctx, { action, error: msg });
  }
}

export async function logError(
  severity: AuditSeverity,
  action: string,
  ctx?: AuditContext,
  details?: Record<string, unknown>,
  err?: Error,
): Promise<void> {
  const entry = {
    timestamp: new Date().toISOString(),
    severity,
    action,
    user_id: ctx?.employeeId ?? ctx?.userId ?? null,
    org_id: ctx?.orgId ?? null,
    details: details ?? {},
    ...(process.env.NODE_ENV !== 'production' && err?.stack ? { stack: err.stack } : {}),
  };
  console.error(JSON.stringify(entry));
  if ((severity === 'critical' || severity === 'warning') && action !== 'audit_logs_insert_failed') {
    await logAudit(action, ctx ?? {}, details ?? {}, severity);
  }
}
