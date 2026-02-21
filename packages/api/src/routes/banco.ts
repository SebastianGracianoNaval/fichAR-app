import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];

export async function handleGetBanco(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const admin = getSupabaseAdmin();

  const { data: fichajes } = await admin
    .from('fichajes')
    .select('id, tipo, timestamp_servidor')
    .eq('user_id', ctx.employeeId)
    .is('reemplazado_por_id', null)
    .order('timestamp_servidor', { ascending: true });

  const horas = computeBancoFromFichajes(fichajes ?? []);
  return Response.json({ saldo_horas: horas, employee_id: ctx.employeeId });
}

export async function handleGetBancoEquipo(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!ADMIN_OR_SUPERVISOR.includes(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  let employeeIds: string[] = [];

  if (ctx.role === 'supervisor') {
    const { data: team } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).or(`supervisor_id.eq.${ctx.employeeId},id.eq.${ctx.employeeId}`);
    employeeIds = (team ?? []).map((e) => e.id);
  } else {
    const { data: all } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).eq('status', 'activo');
    employeeIds = (all ?? []).map((e) => e.id);
  }

  if (employeeIds.length === 0) {
    return Response.json({ data: [] });
  }

  const { data: fichajes } = await admin
    .from('fichajes')
    .select('user_id, tipo, timestamp_servidor')
    .in('user_id', employeeIds)
    .is('reemplazado_por_id', null)
    .order('timestamp_servidor', { ascending: true });

  const byEmployee = new Map<string, { tipo: string; timestamp_servidor: string }[]>();
  for (const f of fichajes ?? []) {
    const list = byEmployee.get(f.user_id) ?? [];
    list.push({ tipo: f.tipo, timestamp_servidor: f.timestamp_servidor });
    byEmployee.set(f.user_id, list);
  }

  const saldos: { employee_id: string; saldo_horas: number }[] = employeeIds.map((empId) => ({
    employee_id: empId,
    saldo_horas: computeBancoFromFichajes(byEmployee.get(empId) ?? []),
  }));

  return Response.json({ data: saldos });
}

function computeBancoFromFichajes(fichajes: { tipo: string; timestamp_servidor: string }[]): number {
  let total = 0;
  let lastEntrada: Date | null = null;
  const jornadaStandard = 8;

  for (const f of fichajes) {
    const ts = new Date(f.timestamp_servidor);
    if (f.tipo === 'entrada') {
      lastEntrada = ts;
    } else if (f.tipo === 'salida' && lastEntrada) {
      const horas = (ts.getTime() - lastEntrada.getTime()) / (1000 * 60 * 60);
      total += horas - jornadaStandard;
      lastEntrada = null;
    }
  }
  return Math.round(total * 10) / 10;
}
