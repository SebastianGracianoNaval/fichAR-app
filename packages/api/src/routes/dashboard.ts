import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logError } from '../lib/logger.ts';

const TIMEZONE = 'America/Argentina/Buenos_Aires';

function getInicioFinHoy(): { desde: string; hasta: string } {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = formatter.formatToParts(now);
  const year = parseInt(parts.find((p) => p.type === 'year')?.value ?? '2026', 10);
  const month = parseInt(parts.find((p) => p.type === 'month')?.value ?? '01', 10) - 1;
  const day = parseInt(parts.find((p) => p.type === 'day')?.value ?? '01', 10);
  const desdeDate = new Date(Date.UTC(year, month, day, 3, 0, 0, 0));
  const hastaDate = new Date(desdeDate.getTime() + 24 * 60 * 60 * 1000 - 1);
  return { desde: desdeDate.toISOString(), hasta: hastaDate.toISOString() };
}

async function getTotalEmpleadosActivos(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
): Promise<number> {
  const { count } = await admin
    .from('employees')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .eq('status', 'activo');
  return count ?? 0;
}

async function getFichadosHoy(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
): Promise<number> {
  const { desde, hasta } = getInicioFinHoy();
  const { data } = await admin
    .from('fichajes')
    .select('user_id')
    .eq('org_id', orgId)
    .is('reemplazado_por_id', null)
    .eq('tipo', 'entrada')
    .gte('timestamp_servidor', desde)
    .lte('timestamp_servidor', hasta);
  const distinctIds = new Set((data ?? []).map((r) => (r as { user_id: string }).user_id));
  return distinctIds.size;
}

async function getAlertasPendientes(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
): Promise<number> {
  const { count } = await admin
    .from('alertas')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .eq('leida', false);
  return count ?? 0;
}

async function getLicenciasPendientes(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
): Promise<number> {
  const { count } = await admin
    .from('solicitudes_licencia')
    .select('id', { count: 'exact', head: true })
    .eq('org_id', orgId)
    .eq('estado', 'pendiente');
  return count ?? 0;
}

export async function handleGetAdminDashboard(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  const admin = getSupabaseAdmin();

  try {
    const [totalEmpleados, fichadosHoy, alertasPendientes, licenciasPendientes] = await Promise.all([
      getTotalEmpleadosActivos(admin, ctx.orgId),
      getFichadosHoy(admin, ctx.orgId),
      getAlertasPendientes(admin, ctx.orgId),
      getLicenciasPendientes(admin, ctx.orgId),
    ]);

    return Response.json({
      data: {
        total_empleados: totalEmpleados,
        fichados_hoy: fichadosHoy,
        alertas_pendientes: alertasPendientes,
        licencias_pendientes: licenciasPendientes,
      },
    });
  } catch (error) {
    await logError('critical', 'admin_dashboard_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al cargar panel', code: 'internal' }, { status: 500 });
  }
}
