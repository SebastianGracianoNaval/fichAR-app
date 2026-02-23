import { getSupabaseAdmin } from './supabase.ts';

export interface LegalAuthContext {
  userId: string;
  employeeId: string;
  orgId: string;
  role: string;
}

const LEGAL_ROLES = ['admin', 'integrity_viewer'] as const;

export async function requireLegalAuditor(
  req: Request,
): Promise<{ ok: true; ctx: LegalAuthContext } | { ok: false; res: Response }> {
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return { ok: false, res: Response.json({ error: 'Authorization required' }, { status: 401 }) };
  }

  const { data: { user }, error } = await getSupabaseAdmin().auth.getUser(token);
  if (error || !user) {
    return { ok: false, res: Response.json({ error: 'Token inválido' }, { status: 401 }) };
  }

  const { data: emp, error: empErr } = await getSupabaseAdmin()
    .from('employees')
    .select('id, org_id, role, status')
    .eq('auth_user_id', user.id)
    .single();

  if (empErr || !emp) {
    return { ok: false, res: Response.json({ error: 'Token inválido' }, { status: 401 }) };
  }

  if (emp.status !== 'activo') {
    return { ok: false, res: Response.json({ error: 'Cuenta no activa' }, { status: 403 }) };
  }

  if (!LEGAL_ROLES.includes(emp.role as (typeof LEGAL_ROLES)[number])) {
    return { ok: false, res: Response.json({ error: 'Sin permisos para acceso de integridad' }, { status: 403 }) };
  }

  return {
    ok: true,
    ctx: {
      userId: user.id,
      employeeId: emp.id,
      orgId: emp.org_id,
      role: emp.role,
    },
  };
}
