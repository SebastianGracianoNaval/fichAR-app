import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { getOrgConfig, getOrgConfigString } from '../lib/org-config.ts';
import { validatePagination } from '../lib/validators.ts';
import { dispatchWebhooks } from '../services/webhook-dispatch.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];
const TIPOS_REQUIEREN_ADJUNTO = ['enfermedad', 'accidente'];
const MAX_MOTIVO_RECHAZO = 500;
const MIN_MOTIVO_RECHAZO = 10;
const MAX_DIAS_FUTURO = 365;

const LICENCIA_ADJUNTOS_BUCKET = 'licencia-adjuntos';
const MAX_ADJUNTO_BYTES = 5 * 1024 * 1024; // 5 MB per CL-017
const ADJUNTO_MIMES = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];

function canApprove(role: string): boolean {
  return ADMIN_OR_SUPERVISOR.includes(role);
}

async function requireLicenciasAprobador(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  role: string,
): Promise<{ ok: false; res: Response } | { ok: true }> {
  const aprobador = await getOrgConfigString(admin, orgId, 'licencias_aprobador', 'supervisor');
  const soloAdmin = aprobador === 'admin';
  if (soloAdmin && role !== 'admin') {
    return {
      ok: false,
      res: Response.json(
        { error: 'Solo Admin puede aprobar licencias en esta organización.', code: 'licencias_solo_admin' },
        { status: 403 },
      ),
    };
  }
  return { ok: true };
}

function parseDate(s: unknown): Date | null {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

export async function handleGetLicencias(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const employeeId = url.searchParams.get('employee_id');
  const estado = url.searchParams.get('estado');
  const { limit, offset } = validatePagination(
    url.searchParams.get('limit'),
    url.searchParams.get('offset'),
    { defaultLimit: 50 },
  );

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
    return Response.json({ error: 'Error al listar licencias', code: 'internal' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0, limit, offset } });
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
    return Response.json({ error: 'Error al listar pendientes', code: 'internal' }, { status: 500 });
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

  const payload = {
    id: inserted.id,
    employee_id: ctx.employeeId,
    org_id: ctx.orgId,
    tipo: (inserted as { tipo: string }).tipo,
    fecha_inicio: (inserted as { fecha_inicio: string }).fecha_inicio,
    fecha_fin: (inserted as { fecha_fin: string }).fecha_fin,
    estado: 'pendiente',
  };
  void dispatchWebhooks(ctx.orgId, 'licencia.creada', payload).catch((e) =>
    logError('warning', 'webhook_dispatch_failed', { orgId: ctx.orgId }, { event: 'licencia.creada' }, e instanceof Error ? e : new Error(String(e))),
  );

  return Response.json(inserted, { status: 201 });
}

function sanitizeFilename(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 100) || 'file';
}

export async function handlePostLicenciasUpload(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  let formData: FormData;
  try {
    formData = await req.formData();
  } catch {
    return Response.json({ error: 'Invalid form data' }, { status: 400 });
  }

  const file = formData.get('file');
  if (!file || typeof file === 'string') {
    return Response.json(
      { error: 'Solo se permiten archivos PDF, JPG o PNG de hasta 5 MB.', code: 'adjunto_invalido' },
      { status: 400 },
    );
  }

  const blob = file as Blob;
  const size = blob.size;
  if (size > MAX_ADJUNTO_BYTES) {
    return Response.json(
      { error: 'Solo se permiten archivos PDF, JPG o PNG de hasta 5 MB.', code: 'adjunto_invalido' },
      { status: 400 },
    );
  }

  const mime = (blob as { type?: string }).type?.toLowerCase() ?? '';
  const allowed = ADJUNTO_MIMES.some((m) => m === mime || (m === 'image/jpg' && mime === 'image/jpeg'));
  if (!allowed) {
    return Response.json(
      { error: 'Solo se permiten archivos PDF, JPG o PNG de hasta 5 MB.', code: 'adjunto_invalido' },
      { status: 400 },
    );
  }

  const name = (file as File).name ?? 'file';
  const safeName = sanitizeFilename(name);
  const path = `${ctx.orgId}/${ctx.employeeId}/${crypto.randomUUID()}_${safeName}`;

  const admin = getSupabaseAdmin();
  const { data: buckets } = await admin.storage.listBuckets();
  const bucketExists = buckets?.some((b) => b.name === LICENCIA_ADJUNTOS_BUCKET);
  if (!bucketExists) {
    const { error: createErr } = await admin.storage.createBucket(LICENCIA_ADJUNTOS_BUCKET, {
      public: false,
      fileSizeLimit: MAX_ADJUNTO_BYTES,
      allowedMimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    });
    if (createErr) {
      await logError('critical', 'licencia_upload_bucket_failed', { orgId: ctx.orgId }, {}, createErr);
      return Response.json({ error: 'Error al preparar almacenamiento' }, { status: 500 });
    }
  }

  const buffer = Buffer.from(await blob.arrayBuffer());
  const { error: uploadErr } = await admin.storage.from(LICENCIA_ADJUNTOS_BUCKET).upload(path, buffer, {
    contentType: mime || 'application/octet-stream',
    upsert: false,
  });

  if (uploadErr) {
    await logError('critical', 'licencia_upload_failed', { orgId: ctx.orgId, path }, {}, uploadErr);
    return Response.json({ error: 'Error al subir el archivo' }, { status: 500 });
  }

  return Response.json(
    { storage_path: path, filename: name, mime_type: mime || undefined },
    { status: 201 },
  );
}

export async function handlePostLicenciaAprobar(req: Request, licenciaId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canApprove(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  const cfgCheck = await requireLicenciasAprobador(admin, ctx.orgId, ctx.role);
  if (!cfgCheck.ok) return cfgCheck.res;

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

  const payload = {
    id: licenciaId,
    employee_id: (lic as { employee_id: string }).employee_id,
    org_id: (lic as { org_id: string }).org_id,
    estado: 'aprobada',
    aprobado_por: ctx.employeeId,
  };
  void dispatchWebhooks(ctx.orgId, 'licencia.aprobada', payload).catch((e) =>
    logError('warning', 'webhook_dispatch_failed', { orgId: ctx.orgId }, { event: 'licencia.aprobada' }, e instanceof Error ? e : new Error(String(e))),
  );

  return Response.json({ ok: true, estado: 'aprobada' });
}

export async function handlePostLicenciaRechazar(req: Request, licenciaId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canApprove(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  const cfgCheck = await requireLicenciasAprobador(admin, ctx.orgId, ctx.role);
  if (!cfgCheck.ok) return cfgCheck.res;

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

  const payload = {
    id: licenciaId,
    employee_id: (lic as { employee_id: string }).employee_id,
    org_id: (lic as { org_id: string }).org_id,
    estado: 'rechazada',
    rechazo_motivo: motivo.trim(),
  };
  void dispatchWebhooks(ctx.orgId, 'licencia.rechazada', payload).catch((e) =>
    logError('warning', 'webhook_dispatch_failed', { orgId: ctx.orgId }, { event: 'licencia.rechazada' }, e instanceof Error ? e : new Error(String(e))),
  );

  return Response.json({ ok: true, estado: 'rechazada' });
}
