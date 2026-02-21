import * as XLSX from 'xlsx';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];
const MAX_EXPORT_ROWS = 100_000;

interface ExportBody {
  tipo: string;
  fecha_desde: string;
  fecha_hasta: string;
  empleado_ids?: string[];
  formato?: 'xlsx' | 'csv';
}

export async function handlePostReportesExport(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!ADMIN_OR_SUPERVISOR.includes(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as ExportBody;
  const tipo = data?.tipo ?? 'completo';
  const fechaDesde = data?.fecha_desde;
  const fechaHasta = data?.fecha_hasta;
  const empleadoIds = (data?.empleado_ids as string[] | undefined) ?? [];
  const formato = (data?.formato ?? 'xlsx') === 'csv' ? 'csv' : 'xlsx';

  if (!fechaDesde || !fechaHasta) {
    return Response.json({ error: 'fecha_desde y fecha_hasta requeridos' }, { status: 400 });
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fechaDesde) || !/^\d{4}-\d{2}-\d{2}$/.test(fechaHasta)) {
    return Response.json({ error: 'fecha_desde y fecha_hasta deben ser YYYY-MM-DD' }, { status: 400 });
  }
  if (fechaDesde > fechaHasta) {
    return Response.json({ error: 'La fecha desde debe ser anterior a la fecha hasta.', code: 'fechas_invertidas' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  let employeeIds = empleadoIds;
  if (empleadoIds.length === 0) {
    const { data: all } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).eq('status', 'activo');
    employeeIds = (all ?? []).map((e) => e.id);
  } else if (ctx.role === 'supervisor') {
    const { data: teamIds } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).or(`supervisor_id.eq.${ctx.employeeId},id.eq.${ctx.employeeId}`);
    const allowed = new Set((teamIds ?? []).map((e) => e.id));
    employeeIds = empleadoIds.filter((id) => allowed.has(id));
  }

  const desdeTs = `${fechaDesde}T00:00:00.000Z`;
  const hastaTs = `${fechaHasta}T23:59:59.999Z`;

  const sheets: { name: string; headers: string[]; rows: Record<string, unknown>[] }[] = [];
  const includeFichajes = ['fichajes', 'completo', 'horas_trabajadas'].includes(tipo);
  const includeLicencias = ['licencias', 'completo'].includes(tipo);
  const includeAlertas = ['alertas', 'completo'].includes(tipo);

  const [fichajesRes, licenciasRes, alertasRes] = await Promise.all([
    includeFichajes && employeeIds.length > 0
      ? admin
          .from('fichajes')
          .select('id, user_id, tipo, timestamp_servidor, lugar_id, lat, long')
          .eq('org_id', ctx.orgId)
          .is('reemplazado_por_id', null)
          .gte('timestamp_servidor', desdeTs)
          .lte('timestamp_servidor', hastaTs)
          .in('user_id', employeeIds)
          .order('timestamp_servidor', { ascending: true })
          .limit(MAX_EXPORT_ROWS)
      : Promise.resolve({ data: null, error: null }),
    includeLicencias
      ? (employeeIds.length > 0
          ? admin
              .from('solicitudes_licencia')
              .select('id, employee_id, tipo, fecha_inicio, fecha_fin, motivo, estado, aprobado_por')
              .eq('org_id', ctx.orgId)
              .lte('fecha_inicio', fechaHasta)
              .gte('fecha_fin', fechaDesde)
              .in('employee_id', employeeIds)
              .limit(MAX_EXPORT_ROWS)
          : admin
              .from('solicitudes_licencia')
              .select('id, employee_id, tipo, fecha_inicio, fecha_fin, motivo, estado, aprobado_por')
              .eq('org_id', ctx.orgId)
              .lte('fecha_inicio', fechaHasta)
              .gte('fecha_fin', fechaDesde)
              .limit(MAX_EXPORT_ROWS)
        )
      : Promise.resolve({ data: null, error: null }),
    includeAlertas
      ? (employeeIds.length > 0
          ? admin
              .from('alertas')
              .select('id, employee_id, tipo, descripcion, created_at')
              .eq('org_id', ctx.orgId)
              .gte('created_at', desdeTs)
              .lte('created_at', hastaTs)
              .in('employee_id', employeeIds)
              .limit(MAX_EXPORT_ROWS)
          : admin
              .from('alertas')
              .select('id, employee_id, tipo, descripcion, created_at')
              .eq('org_id', ctx.orgId)
              .gte('created_at', desdeTs)
              .lte('created_at', hastaTs)
              .limit(MAX_EXPORT_ROWS)
        )
      : Promise.resolve({ data: null, error: null }),
  ]);

  if (fichajesRes.error) {
    await logError('critical', 'reportes_fichajes_failed', { orgId: ctx.orgId }, {}, fichajesRes.error);
    return Response.json({ error: 'Error al exportar fichajes' }, { status: 500 });
  }
  if (licenciasRes.error) {
    await logError('critical', 'reportes_licencias_failed', { orgId: ctx.orgId }, {}, licenciasRes.error);
    return Response.json({ error: 'Error al exportar licencias' }, { status: 500 });
  }
  if (alertasRes.error) {
    await logError('critical', 'reportes_alertas_failed', { orgId: ctx.orgId }, {}, alertasRes.error);
    return Response.json({ error: 'Error al exportar alertas' }, { status: 500 });
  }

  const allEmpIds = new Set<string>(employeeIds);
  for (const l of licenciasRes.data ?? []) allEmpIds.add(l.employee_id);
  for (const a of alertasRes.data ?? []) allEmpIds.add(a.employee_id);
  const empMap = await getEmployeeNames(admin, [...allEmpIds]);

  if (includeFichajes && fichajesRes.data && fichajesRes.data.length >= 0) {
    const fichajes = fichajesRes.data;
    const rows = fichajes.map((f) => ({
      id: f.id,
      empleado_id: f.user_id,
      empleado_nombre: empMap.get(f.user_id) ?? '',
      fecha: (f.timestamp_servidor as string).slice(0, 10),
      tipo: f.tipo,
      timestamp_servidor: f.timestamp_servidor,
      lugar_id: f.lugar_id,
      lat: f.lat,
      long: f.long,
    }));
    sheets.push({
      name: 'Fichajes',
      headers: ['id', 'empleado_id', 'empleado_nombre', 'fecha', 'tipo', 'timestamp_servidor', 'lugar_id', 'lat', 'long'],
      rows,
    });
  }

  if (includeLicencias && licenciasRes.data) {
    const licencias = licenciasRes.data;
    const rows = licencias.map((l) => {
      const dias = Math.ceil((new Date(l.fecha_fin).getTime() - new Date(l.fecha_inicio).getTime()) / (1000 * 60 * 60 * 24)) + 1;
      return {
        id: l.id,
        empleado_nombre: empMap.get(l.employee_id) ?? '',
        tipo: l.tipo,
        fecha_inicio: l.fecha_inicio,
        fecha_fin: l.fecha_fin,
        dias,
        estado: l.estado,
        aprobado_por: l.aprobado_por,
      };
    });
    sheets.push({
      name: 'Licencias',
      headers: ['id', 'empleado_nombre', 'tipo', 'fecha_inicio', 'fecha_fin', 'dias', 'estado', 'aprobado_por'],
      rows,
    });
  }

  if (includeAlertas && alertasRes.data) {
    const alertas = alertasRes.data;
    const rows = alertas.map((a) => ({
      fecha: (a.created_at as string).slice(0, 19),
      empleado_nombre: empMap.get(a.employee_id) ?? '',
      tipo_alerta: a.tipo,
      descripcion: a.descripcion,
    }));
    sheets.push({
      name: 'Alertas',
      headers: ['fecha', 'empleado_nombre', 'tipo_alerta', 'descripcion'],
      rows,
    });
  }

  sheets.push({
    name: 'Metadatos',
    headers: ['clave', 'valor'],
    rows: [
      { clave: 'periodo_desde', valor: fechaDesde },
      { clave: 'periodo_hasta', valor: fechaHasta },
      { clave: 'generado_en', valor: new Date().toISOString() },
      { clave: 'org_id', valor: ctx.orgId },
    ],
  });

  const meta = getRequestMeta(req);
  await logAudit(
    'reporte_exportado',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { tipo, fecha_desde: fechaDesde, fecha_hasta: fechaHasta, formato, empleados_count: employeeIds.length },
    'info',
  );

  if (formato === 'csv') {
    const firstSheet = sheets.find((s) => s.rows.length > 0) ?? sheets[0];
    const lines = [
      firstSheet.headers.join(';'),
      ...firstSheet.rows.map((r) => firstSheet.headers.map((h) => String(r[h] ?? '')).join(';')),
    ];
    const csv = '\uFEFF' + lines.join('\n');
    return new Response(csv, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="fichar-reporte-${Date.now()}.csv"`,
      },
    });
  }

  const wb = XLSX.utils.book_new();
  for (const sheet of sheets) {
    const data = [sheet.headers, ...sheet.rows.map((r) => sheet.headers.map((h) => r[h] ?? ''))];
    const ws = XLSX.utils.aoa_to_sheet(data);
    XLSX.utils.book_append_sheet(wb, ws, sheet.name.slice(0, 31));
  }
  const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx', bookSheets: true });

  return new Response(buf, {
    status: 200,
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="fichar-reporte-${Date.now()}.xlsx"`,
    },
  });
}

async function getEmployeeNames(admin: ReturnType<typeof getSupabaseAdmin>, ids: string[]): Promise<Map<string, string>> {
  if (ids.length === 0) return new Map();
  const { data } = await admin.from('employees').select('id, name').in('id', ids);
  const map = new Map<string, string>();
  for (const e of data ?? []) {
    map.set(e.id, e.name ?? '');
  }
  return map;
}
