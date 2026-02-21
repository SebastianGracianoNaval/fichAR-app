import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];
const TIPOS_REQUIEREN_ADJUNTO = ['enfermedad', 'accidente'];
const MAX_MOTIVO_RECHAZO = 500;
const MIN_MOTIVO_RECHAZO = 10;
const MAX_DIAS_FUTURO = 365;

function canApprove(role: string): boolean {
  return ADMIN_OR_SUPERVISOR.includes(role);
}

async function getOrgConfig(admin: ReturnType<typeof getSupabaseAdmin>, orgId: string, key: string): Promise<unknown> {
  const { data } = await admin.from('org_configs').select('value').eq('org_id', orgId).eq('key', key).maybeSingle();
  return data?.value;
}

function parseDate(s: unknown): Date | null {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}

export async function handleGetLicencias(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const employeeId = url.searchParams.get('employee_id');
  const estado = url.searchParams.get('estado');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 100);
  const offset = parseInt(url.searchParams.get('offset') ?? '0', 10) || 0;

  const admin = getSupabaseAdmin();
  let query = admin
    .from('solicitudes_licencia')
    .select('id, employee_id, tipo, fecha_inicio, fecha_fin, motivo, estado, aprobado_por, rechazo_motivo, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (ctx.role === 'empleado' || ctx.role === 'auditor') {
    query = query.eq('employee_id', ctx.employeeId);
  } else if (employeeId) {
    if (ctx.role === 'supervisor') {
      const { data: emp } = await admin.from('employees').select('id, supervisor_id').eq('id', employeeId).eq('org_id', ctx.orgId).single();
      if (!emp || (emp.supervisor_id !== ctx.employeeId && emp.id !== ctx.employeeId)) {
        return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
      }
    }
    query = query.eq('employee_id', employeeId);
  } else if (ctx.role === 'supervisor') {
    const { data: teamIds } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).or(`supervisor_id.eq.${ctx.employeeId},id.eq.${ctx.employeeId}`);
    const ids = (teamIds ?? []).map((e) => e.id);
    query = query.in('employee_id', ids);
  }

  if (estado) query = query.eq('estado', estado);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'licencias_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar licencias' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}

export async function handleGetLicenciasPendientes(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canApprove(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  let query = admin
    .from('solicitudes_licencia')
    .select('id, employee_id, tipo, fecha_inicio, fecha_fin, motivo, estado, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .eq('estado', 'pendiente')
    .order('created_at', { ascending: true });

  if (ctx.role === 'supervisor') {
    const { data: teamIds } = await admin.from('employees').select('id').eq('org_id', ctx.orgId).or(`supervisor_id.eq.${ctx.employeeId},id.eq.${ctx.employeeId}`);
    const ids = (teamIds ?? []).map((e) => e.id);
    query = query.in('employee_id', ids);
  }

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'licencias_pendientes_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar pendientes' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}

interface PostLicenciaBody {
  tipo: string;
  fecha_inicio: string;
  fecha_fin: string;
  motivo?: string;
  adjuntos?: { storage_path: string; filename?: string; mime_type?: string }[];
}

export async function handlePostLicencias(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as PostLicenciaBody;
  const tipo = data?.tipo;
  const fechaInicio = data?.fecha_inicio;
  const fechaFin = data?.fecha_fin;
  const adjuntos = (data?.adjuntos as PostLicenciaBody['adjuntos']) ?? [];

  if (!tipo || typeof tipo !== 'string' || !fechaInicio || !fechaFin) {
    return Response.json({ error: 'tipo, fecha_inicio y fecha_fin requeridos' }, { status: 400 });
  }

  const dInicio = parseDate(fechaInicio);
  const dFin = parseDate(fechaFin);
  if (!dInicio || !dFin) {
    return Response.json({ error: 'fecha_inicio y fecha_fin deben ser YYYY-MM-DD válidos' }, { status: 400 });
  }
  if (dFin < dInicio) {
    return Response.json({ error: 'fecha_fin debe ser >= fecha_inicio' }, { status: 400 });
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const maxFuture = new Date(today);
  maxFuture.setDate(maxFuture.getDate() + MAX_DIAS_FUTURO);
  if (dInicio > maxFuture || dFin > maxFuture) {
    return Response.json(
      { error: 'Las fechas de licencia no pueden superar 1 año desde hoy.', code: 'fecha_futuro_excedida' },
      { status: 400 },
    );
  }

  const admin = getSupabaseAdmin();
  const cfg017 = await getOrgConfig(admin, ctx.orgId, 'CFG-017');
  const adjuntoObligatorio = cfg017 !== false;
  if (adjuntoObligatorio && TIPOS_REQUIEREN_ADJUNTO.includes(tipo) && adjuntos.length === 0) {
    return Response.json(
      { error: 'Para licencias por enfermedad o accidente debés adjuntar el certificado médico.', code: 'adjunto_obligatorio' },
      { status: 400 },
    );
  }

  const cfg018 = (await getOrgConfig(admin, ctx.orgId, 'CFG-018')) as string[] | undefined;
  const tiposPermitidos = Array.isArray(cfg018) ? cfg018 : ['enfermedad', 'accidente', 'matrimonio', 'maternidad', 'paternidad', 'duelo', 'estudio', 'otro'];
  if (!tiposPermitidos.includes(tipo)) {
    return Response.json({ error: 'Tipo de licencia no permitido', code: 'tipo_invalido' }, { status: 400 });
  }

  const { data: overlapping } = await admin
    .from('solicitudes_licencia')
    .select('id, fecha_inicio, fecha_fin')
    .eq('employee_id', ctx.employeeId)
    .in('estado', ['pendiente', 'aprobada'])
    .lte('fecha_inicio', fechaFin)
    .gte('fecha_fin', fechaInicio);

  if (overlapping && overlapping.length > 0) {
    const o = overlapping[0];
    return Response.json(
      {
        error: `Las fechas se superponen con una licencia existente (del ${o.fecha_inicio} al ${o.fecha_fin}). Ajustá el período o contactá a tu supervisor.`,
        code: 'solapamiento',
      },
      { status: 400 },
    );
  }

  const { data: inserted, error } = await admin
    .from('solicitudes_licencia')
    .insert({
      employee_id: ctx.employeeId,
      org_id: ctx.orgId,
      tipo,
      fecha_inicio: fechaInicio,
      fecha_fin: fechaFin,
      motivo: data?.motivo ?? null,
      estado: 'pendiente',
    })
    .select('id, tipo, fecha_inicio, fecha_fin, estado, created_at')
    .single();

  if (error) {
    await logError('critical', 'licencia_create_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, {}, error);
    return Response.json({ error: 'Error al crear solicitud' }, { status: 500 });
  }

  for (const a of adjuntos) {
    if (a?.storage_path) {
      await admin.from('licencia_adjuntos').insert({
        licencia_id: inserted.id,
        storage_path: a.storage_path,
        filename: a.filename ?? null,
        mime_type: a.mime_type ?? null,
      });
    }
  }

  const meta = getRequestMeta(req);
  await logAudit('licencia_creada', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { resource_type: 'licencia', resource_id: inserted.id, tipo }, 'info');

  return Response.json(inserted, { status: 201 });
}

export async function handlePostLicenciaAprobar(req: Request, licenciaId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canApprove(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  const { data: lic, error: licErr } = await admin
    .from('solicitudes_licencia')
    .select('id, employee_id, org_id, estado')
    .eq('id', licenciaId)
    .eq('org_id', ctx.orgId)
    .single();

  if (licErr || !lic) {
    return Response.json({ error: 'Licencia no encontrada' }, { status: 404 });
  }
  if (lic.estado !== 'pendiente') {
    return Response.json({ error: 'La licencia ya fue procesada', code: 'estado_invalido' }, { status: 400 });
  }

  if (ctx.role === 'supervisor') {
    const { data: emp } = await admin.from('employees').select('id, supervisor_id').eq('id', lic.employee_id).single();
    if (!emp || (emp.supervisor_id !== ctx.employeeId && emp.id !== ctx.employeeId)) {
      return Response.json({ error: 'No tenés permiso para aprobar esta licencia', code: 'sin_permiso' }, { status: 403 });
    }
  }

  const { error: updateErr } = await admin
    .from('solicitudes_licencia')
    .update({
      estado: 'aprobada',
      aprobado_por: ctx.employeeId,
      rechazo_motivo: null,
      updated_at: new Date().toISOString(),
    })
    .eq('id', licenciaId)
    .eq('org_id', ctx.orgId);

  if (updateErr) {
    await logError('critical', 'licencia_aprobar_failed', { orgId: ctx.orgId, licenciaId }, {}, updateErr);
    return Response.json({ error: 'Error al aprobar' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('licencia_aprobada', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { resource_type: 'licencia', resource_id: licenciaId, approver_id: ctx.employeeId }, 'info');

  return Response.json({ ok: true, estado: 'aprobada' });
}

export async function handlePostLicenciaRechazar(req: Request, licenciaId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canApprove(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const motivo = (body as { motivo?: string })?.motivo;
  if (typeof motivo !== 'string' || motivo.trim().length < MIN_MOTIVO_RECHAZO) {
    return Response.json(
      { error: 'El motivo del rechazo es obligatorio (mínimo 10 caracteres)', code: 'motivo_obligatorio' },
      { status: 400 },
    );
  }
  if (motivo.length > MAX_MOTIVO_RECHAZO) {
    return Response.json({ error: 'El motivo no puede superar 500 caracteres', code: 'motivo_largo' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const { data: lic, error: licErr } = await admin
    .from('solicitudes_licencia')
    .select('id, employee_id, org_id, estado')
    .eq('id', licenciaId)
    .eq('org_id', ctx.orgId)
    .single();

  if (licErr || !lic) {
    return Response.json({ error: 'Licencia no encontrada' }, { status: 404 });
  }
  if (lic.estado !== 'pendiente') {
    return Response.json({ error: 'La licencia ya fue procesada', code: 'estado_invalido' }, { status: 400 });
  }

  if (ctx.role === 'supervisor') {
    const { data: emp } = await admin.from('employees').select('id, supervisor_id').eq('id', lic.employee_id).single();
    if (!emp || (emp.supervisor_id !== ctx.employeeId && emp.id !== ctx.employeeId)) {
      return Response.json({ error: 'No tenés permiso para rechazar esta licencia', code: 'sin_permiso' }, { status: 403 });
    }
  }

  const { error: updateErr } = await admin
    .from('solicitudes_licencia')
    .update({
      estado: 'rechazada',
      aprobado_por: ctx.employeeId,
      rechazo_motivo: motivo.trim(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', licenciaId)
    .eq('org_id', ctx.orgId);

  if (updateErr) {
    await logError('critical', 'licencia_rechazar_failed', { orgId: ctx.orgId, licenciaId }, {}, updateErr);
    return Response.json({ error: 'Error al rechazar' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('licencia_rechazada', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { resource_type: 'licencia', resource_id: licenciaId, rechazo_motivo: motivo.trim() }, 'info');

  return Response.json({ ok: true, estado: 'rechazada' });
}
