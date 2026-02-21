import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];

export async function handleGetAlertas(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!ADMIN_OR_SUPERVISOR.includes(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const url = new URL(req.url);
  const tipo = url.searchParams.get('tipo');
  const employeeId = url.searchParams.get('employee_id');
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 100);
  const offset = parseInt(url.searchParams.get('offset') ?? '0', 10) || 0;

  const admin = getSupabaseAdmin();
  let query = admin
    .from('alertas')
    .select('id, org_id, employee_id, tipo, descripcion, leida, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (ctx.role === 'supervisor') {
    const { data: teamIds } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).or(`supervisor_id.eq.${ctx.employeeId},id.eq.${ctx.employeeId}`);
    const ids = (teamIds ?? []).map((e) => e.id);
    query = query.in('employee_id', ids);
  }
  if (tipo) query = query.eq('tipo', tipo);
  if (employeeId) query = query.eq('employee_id', employeeId);
  if (desde) query = query.gte('created_at', desde);
  if (hasta) query = query.lte('created_at', hasta);

  const { data, error, count } = await query;

  if (error) {
    return Response.json({ error: 'Error al listar alertas' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}
