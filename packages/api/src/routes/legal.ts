import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireLegalAuditor } from '../lib/legal-auth-middleware.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import {
  buildCsv,
  buildXlsx,
  computeFileSha256,
  truncateWithLimit,
} from '../lib/legal-export.ts';

const MAX_EXPORT_ROWS = 100_000;

export async function handleGetLegalFichajes(req: Request): Promise<Response> {
  const authResult = await requireLegalAuditor(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const empleadoId = url.searchParams.get('empleado_id');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200);

  if (!desde || !hasta) {
    return Response.json(
      { error: 'desde y hasta (ISO 8601) requeridos' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  let query = admin
    .from('fichajes')
    .select('id, user_id, tipo, timestamp_servidor, timestamp_dispositivo, hash_registro, hash_anterior_id', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .is('reemplazado_por_id', null)
    .gte('timestamp_servidor', desde)
    .lte('timestamp_servidor', hasta)
    .order('timestamp_servidor', { ascending: true })
    .limit(limit);

  if (empleadoId) query = query.eq('user_id', empleadoId);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'legal_fichajes_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar fichajes' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}

export async function handleGetLegalAuditLogs(req: Request): Promise<Response> {
  const authResult = await requireLegalAuditor(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const action = url.searchParams.get('action');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200);

  if (!desde || !hasta) {
    return Response.json(
      { error: 'desde y hasta (ISO 8601) requeridos' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  let query = admin
    .from('audit_logs')
    .select('id, org_id, user_id, timestamp, action, resource_type, resource_id, details, ip, severity', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .gte('timestamp', desde)
    .lte('timestamp', hasta)
    .order('timestamp', { ascending: true })
    .limit(limit);

  if (action) query = query.eq('action', action);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'legal_audit_logs_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar logs' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}

export async function handleGetLegalHashChain(req: Request): Promise<Response> {
  const authResult = await requireLegalAuditor(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const empleadoId = url.searchParams.get('empleado_id');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200);

  if (!desde || !hasta) {
    return Response.json(
      { error: 'desde y hasta (ISO 8601) requeridos' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  let query = admin
    .from('fichajes')
    .select('id, user_id, tipo, timestamp_servidor, hash_registro, hash_anterior_id', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .is('reemplazado_por_id', null)
    .gte('timestamp_servidor', desde)
    .lte('timestamp_servidor', hasta)
    .order('timestamp_servidor', { ascending: true })
    .limit(limit);

  if (empleadoId) query = query.eq('user_id', empleadoId);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'legal_hash_chain_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar cadena de hashes' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}

export async function handleGetLegalLicencias(req: Request): Promise<Response> {
  const authResult = await requireLegalAuditor(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const empleadoId = url.searchParams.get('empleado_id');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200);

  if (!desde || !hasta) {
    return Response.json(
      { error: 'desde y hasta (ISO 8601) requeridos' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  let query = admin
    .from('solicitudes_licencia')
    .select('id, employee_id, tipo, fecha_inicio, fecha_fin, motivo, estado, aprobado_por, rechazo_motivo, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .gte('fecha_fin', desde)
    .lte('fecha_inicio', hasta)
    .order('created_at', { ascending: true })
    .limit(limit);

  if (empleadoId) query = query.eq('employee_id', empleadoId);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'legal_licencias_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar licencias' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}

export async function handlePostLegalExport(req: Request): Promise<Response> {
  const authResult = await requireLegalAuditor(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const meta = getRequestMeta(req);
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as Record<string, unknown>;
  const tipo = data?.tipo as string;
  const desde = data?.desde as string;
  const hasta = data?.hasta as string;
  const empleadoIds = (data?.empleado_ids as string[] | undefined) ?? [];
  const formato = (data?.formato as string) ?? 'csv';

  if (!tipo || !desde || !hasta) {
    return Response.json(
      { error: 'tipo, desde y hasta requeridos' },
      { status: 400 },
    );
  }
  if (!['csv', 'xlsx'].includes(formato)) {
    return Response.json({ error: 'formato debe ser csv o xlsx' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const exportedAt = new Date().toISOString();

  const { data: exporter } = await admin
    .from('employees')
    .select('name, email')
    .eq('id', ctx.employeeId)
    .single();

  const exportedBy = exporter
    ? `${(exporter as { name: string }).name} (${(exporter as { email: string }).email})`
    : ctx.employeeId;

  const sheetFichajes: { headers: string[]; rows: Record<string, unknown>[] } = {
    headers: ['id', 'user_id', 'tipo', 'timestamp_servidor', 'timestamp_dispositivo', 'hash_registro', 'hash_anterior_id'],
    rows: [],
  };
  const sheetLogs: { headers: string[]; rows: Record<string, unknown>[] } = {
    headers: ['id', 'user_id', 'timestamp', 'action', 'resource_type', 'resource_id', 'details', 'ip', 'severity'],
    rows: [],
  };
  const sheetHashChain: { headers: string[]; rows: Record<string, unknown>[] } = {
    headers: ['id', 'user_id', 'tipo', 'timestamp_servidor', 'hash_registro', 'hash_anterior_id'],
    rows: [],
  };
  const sheetLicencias: { headers: string[]; rows: Record<string, unknown>[] } = {
    headers: ['id', 'employee_id', 'tipo', 'fecha_inicio', 'fecha_fin', 'estado', 'aprobado_por', 'rechazo_motivo', 'created_at'],
    rows: [],
  };

  const includeFichajes = ['fichajes', 'todo'].includes(tipo);
  const includeLogs = ['logs', 'todo'].includes(tipo);
  const includeHashChain = ['hash_chain', 'todo'].includes(tipo);
  const includeLicencias = ['licencias', 'todo'].includes(tipo);

  if (includeFichajes) {
    let q = admin
      .from('fichajes')
      .select('id, user_id, tipo, timestamp_servidor, timestamp_dispositivo, hash_registro, hash_anterior_id')
      .eq('org_id', ctx.orgId)
      .is('reemplazado_por_id', null)
      .gte('timestamp_servidor', desde)
      .lte('timestamp_servidor', hasta)
      .order('timestamp_servidor', { ascending: true })
      .limit(MAX_EXPORT_ROWS);

    if (empleadoIds.length > 0) q = q.in('user_id', empleadoIds);

    const { data: fichajes, error: err } = await q;
    if (err) {
      await logError('critical', 'legal_export_fichajes_failed', { orgId: ctx.orgId }, {}, err);
      return Response.json({ error: 'Error al exportar fichajes' }, { status: 500 });
    }
    const { data: truncated } = truncateWithLimit((fichajes ?? []) as Record<string, unknown>[], MAX_EXPORT_ROWS);
    sheetFichajes.rows = truncated.map((r) => ({ ...r }));
  }

  if (includeLogs) {
    const q = admin
      .from('audit_logs')
      .select('id, user_id, timestamp, action, resource_type, resource_id, details, ip, severity')
      .eq('org_id', ctx.orgId)
      .gte('timestamp', desde)
      .lte('timestamp', hasta)
      .order('timestamp', { ascending: true })
      .limit(MAX_EXPORT_ROWS);

    const { data: logs, error: err } = await q;
    if (err) {
      await logError('critical', 'legal_export_logs_failed', { orgId: ctx.orgId }, {}, err);
      return Response.json({ error: 'Error al exportar logs' }, { status: 500 });
    }
    const { data: truncated } = truncateWithLimit((logs ?? []) as Record<string, unknown>[], MAX_EXPORT_ROWS);
    sheetLogs.rows = truncated.map((r) => ({ ...r }));
  }

  if (includeHashChain) {
    let q = admin
      .from('fichajes')
      .select('id, user_id, tipo, timestamp_servidor, hash_registro, hash_anterior_id')
      .eq('org_id', ctx.orgId)
      .is('reemplazado_por_id', null)
      .gte('timestamp_servidor', desde)
      .lte('timestamp_servidor', hasta)
      .order('timestamp_servidor', { ascending: true })
      .limit(MAX_EXPORT_ROWS);

    if (empleadoIds.length > 0) q = q.in('user_id', empleadoIds);

    const { data: chain, error: err } = await q;
    if (err) {
      await logError('critical', 'legal_export_hash_chain_failed', { orgId: ctx.orgId }, {}, err);
      return Response.json({ error: 'Error al exportar cadena' }, { status: 500 });
    }
    const { data: truncated } = truncateWithLimit((chain ?? []) as Record<string, unknown>[], MAX_EXPORT_ROWS);
    sheetHashChain.rows = truncated.map((r) => ({ ...r }));
  }

  if (includeLicencias) {
    let q = admin
      .from('solicitudes_licencia')
      .select('id, employee_id, tipo, fecha_inicio, fecha_fin, estado, aprobado_por, rechazo_motivo, created_at')
      .eq('org_id', ctx.orgId)
      .gte('fecha_fin', desde)
      .lte('fecha_inicio', hasta)
      .order('created_at', { ascending: true })
      .limit(MAX_EXPORT_ROWS);

    if (empleadoIds.length > 0) q = q.in('employee_id', empleadoIds);

    const { data: licencias, error: err } = await q;
    if (err) {
      await logError('critical', 'legal_export_licencias_failed', { orgId: ctx.orgId }, {}, err);
      return Response.json({ error: 'Error al exportar licencias' }, { status: 500 });
    }
    const { data: truncated } = truncateWithLimit((licencias ?? []) as Record<string, unknown>[], MAX_EXPORT_ROWS);
    sheetLicencias.rows = truncated.map((r) => ({ ...r }));
  }

  const totalRows = sheetFichajes.rows.length + sheetLogs.rows.length + sheetHashChain.rows.length + sheetLicencias.rows.length;
  await logAudit(
    'legal_export',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip, userAgent: meta.userAgent },
    { tipo, formato, desde, hasta, empleado_ids: empleadoIds, total_rows: totalRows },
    'info',
  );

  if (formato === 'csv') {
    const metaLine = `# Exportado por fichAR. Fecha exportación: ${exportedAt}. Por: ${exportedBy}. Uso exclusivo fines legales.`;
    const rows =
      sheetFichajes.rows.length > 0
        ? sheetFichajes.rows
        : sheetLogs.rows.length > 0
          ? sheetLogs.rows
          : sheetHashChain.rows.length > 0
            ? sheetHashChain.rows
            : sheetLicencias.rows;
    const headers =
      sheetFichajes.rows.length > 0
        ? sheetFichajes.headers
        : sheetLogs.rows.length > 0
          ? sheetLogs.headers
          : sheetHashChain.rows.length > 0
            ? sheetHashChain.headers
            : sheetLicencias.headers;
    const csvForHash = buildCsv(rows, headers, metaLine);
    const bufForHash = Buffer.from(csvForHash, 'utf-8');
    const sha256 = computeFileSha256(bufForHash);
    const fullCsv = buildCsv(rows, headers, metaLine, sha256);
    const finalBuf = Buffer.from(fullCsv, 'utf-8');

    return new Response(finalBuf, {
      status: 200,
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="fichar-legal-${Date.now()}.csv"`,
      },
    });
  }

  const sheets: { name: string; headers: string[]; rows: Record<string, unknown>[] }[] = [];
  if (sheetFichajes.rows.length > 0) sheets.push({ name: 'Fichajes', ...sheetFichajes });
  if (sheetLogs.rows.length > 0) sheets.push({ name: 'Logs', ...sheetLogs });
  if (sheetHashChain.rows.length > 0) sheets.push({ name: 'CadenaHashes', ...sheetHashChain });
  if (sheetLicencias.rows.length > 0) sheets.push({ name: 'Licencias', ...sheetLicencias });

  const xlsxBuf = buildXlsx(sheets, { exportedAt, exportedBy, totalRows });
  const sha256 = computeFileSha256(xlsxBuf);

  return new Response(xlsxBuf, {
    status: 200,
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="fichar-legal-${Date.now()}.xlsx"`,
      'X-Export-Sha256': sha256,
    },
  });
}
