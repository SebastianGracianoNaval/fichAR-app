import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { logError, getRequestMeta, logAudit } from '../lib/logger.ts';
import { validatePagination } from '../lib/validators.ts';

const VALID_TIPO = ['mas_horas', 'menos_horas', 'intercambio'] as const;
const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];

function canApprove(role: string): boolean {
  return ADMIN_OR_SUPERVISOR.includes(role);
}

export async function handlePostSolicitudJornada(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as {
    tipo?: string;
    fecha_objetivo?: string;
    horas_solicitadas?: number;
    employee_id?: string;
  };
  const tipo = data?.tipo?.trim();
  if (!tipo || !VALID_TIPO.includes(tipo as (typeof VALID_TIPO)[number])) {
    return Response.json(
      { error: 'tipo debe ser mas_horas, menos_horas o intercambio' },
      { status: 400 },
    );
  }

  const fechaObjetivo = data?.fecha_objetivo;
  const fechaObjetivoDate =
    typeof fechaObjetivo === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(fechaObjetivo)
      ? fechaObjetivo
      : null;

  const horasSolicitadas =
    typeof data?.horas_solicitadas === 'number' && data.horas_solicitadas >= 0
      ? data.horas_solicitadas
      : null;

  let solicitanteEmployeeId = ctx.employeeId;
  if (canApprove(ctx.role) && typeof data?.employee_id === 'string' && data.employee_id.trim()) {
    const empId = data.employee_id.trim();
    const { data: emp } = await getSupabaseAdmin()
      .from('employees')
      .select('id')
      .eq('id', empId)
      .eq('org_id', ctx.orgId)
      .maybeSingle();
    if (emp) solicitanteEmployeeId = emp.id;
  }

  const targetDateStr = fechaObjetivoDate ?? new Date().toISOString().slice(0, 10);
  const fechaLimite = new Date(`${targetDateStr}T23:59:59.999Z`);

  const admin = getSupabaseAdmin();
  const { data: row, error } = await admin
    .from('solicitudes_jornada')
    .insert({
      org_id: ctx.orgId,
      employee_id: solicitanteEmployeeId,
      solicitante_employee_id: solicitanteEmployeeId,
      tipo,
      fecha_objetivo: fechaObjetivoDate,
      fecha_limite_aceptacion: fechaLimite.toISOString(),
      horas_solicitadas: horasSolicitadas,
    })
    .select('id, tipo, estado, fecha_solicitud, fecha_objetivo, horas_solicitadas, created_at')
    .single();

  if (error) {
    await logError('critical', 'solicitud_jornada_insert_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al crear solicitud', code: 'internal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'solicitud_jornada_creada',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { id: row.id, tipo },
    'info',
  );

  return Response.json(row, { status: 201 });
}

export async function handleGetSolicitudesJornada(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const estado = url.searchParams.get('estado');
  const { limit, offset } = validatePagination(
    url.searchParams.get('limit'),
    url.searchParams.get('offset'),
    { defaultLimit: 50 },
  );

  const admin = getSupabaseAdmin();
  let query = admin
    .from('solicitudes_jornada')
    .select(
      'id, org_id, employee_id, tipo, estado, solicitante_employee_id, aprobador_employee_id, fecha_solicitud, fecha_objetivo, fecha_limite_aceptacion, horas_solicitadas, motivo_rechazo, created_at, updated_at, solicitante:employees!solicitante_employee_id(name)',
      { count: 'exact' },
    )
    .eq('org_id', ctx.orgId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (ctx.role === 'empleado' || ctx.role === 'auditor') {
    query = query.eq('solicitante_employee_id', ctx.employeeId);
  }

  if (estado) query = query.eq('estado', estado);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'solicitudes_jornada_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar solicitudes', code: 'internal' }, { status: 500 });
  }

  const now = new Date();
  const enriched = (data ?? []).map((row: Record<string, unknown>) => {
    const solicitante = row.solicitante as { name?: string } | null | undefined;
    const solicitanteNombre = solicitante?.name ?? null;
    const fechaLimite = row.fecha_limite_aceptacion as string | null | undefined;
    const estaVencida =
      row.estado === 'pendiente' &&
      fechaLimite &&
      now > new Date(fechaLimite);
    const { solicitante: _s, ...rest } = row;
    return { ...rest, solicitante_nombre: solicitanteNombre, esta_vencida: estaVencida };
  });

  return Response.json({ data: enriched, meta: { total: count ?? 0, limit, offset } });
}

export async function handlePatchSolicitudJornada(req: Request, id: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canApprove(ctx.role)) {
    return Response.json({ error: 'No tenés permiso para aprobar o rechazar', code: 'sin_permiso' }, { status: 403 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as { estado?: string; motivo_rechazo?: string };
  const estado = data?.estado?.trim();
  if (!estado || !['aprobada', 'rechazada'].includes(estado)) {
    return Response.json({ error: 'estado debe ser aprobada o rechazada' }, { status: 400 });
  }

  if (estado === 'rechazada') {
    const motivo = data?.motivo_rechazo?.trim();
    if (!motivo || motivo.length === 0) {
      return Response.json(
        { error: 'motivo_rechazo es obligatorio al rechazar' },
        { status: 400 },
      );
    }
  }

  const admin = getSupabaseAdmin();
  const { data: existing, error: fetchErr } = await admin
    .from('solicitudes_jornada')
    .select('id, estado, org_id')
    .eq('id', id)
    .single();

  if (fetchErr || !existing) {
    return Response.json({ error: 'Solicitud no encontrada', code: 'not_found' }, { status: 404 });
  }

  if (existing.org_id !== ctx.orgId) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  if (existing.estado !== 'pendiente') {
    return Response.json({ error: 'La solicitud ya fue procesada', code: 'already_processed' }, { status: 400 });
  }

  const updates: Record<string, unknown> = {
    estado,
    aprobador_employee_id: ctx.employeeId,
    updated_at: new Date().toISOString(),
  };
  if (estado === 'rechazada' && data?.motivo_rechazo?.trim()) {
    updates.motivo_rechazo = data.motivo_rechazo.trim();
  }

  const { data: updated, error: updateErr } = await admin
    .from('solicitudes_jornada')
    .update(updates)
    .eq('id', id)
    .select('id, tipo, estado, motivo_rechazo, updated_at')
    .single();

  if (updateErr) {
    await logError('critical', 'solicitud_jornada_patch_failed', { orgId: ctx.orgId }, {}, updateErr);
    return Response.json({ error: 'Error al actualizar solicitud', code: 'internal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'solicitud_jornada_resuelta',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { id, estado },
    'info',
  );

  return Response.json(updated);
}
