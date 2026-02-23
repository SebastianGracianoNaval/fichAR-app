import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { parseBody, validatePagination } from '../lib/validators.ts';
import { computeHash } from '../services/fichaje-hash.ts';
import { validateEntrada } from '../services/fichaje-rules.ts';
import { dispatchWebhooks } from '../services/webhook-dispatch.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { getOrgConfigBoolean, getOrgConfigNumber } from '../lib/org-config.ts';
import { haversineKm } from '../lib/geo.ts';

interface PostFichajeBody {
  tipo: 'entrada' | 'salida';
  lat?: number;
  long?: number;
  lugar_id?: string;
  idempotency_key?: string;
  timestamp_dispositivo?: string;
}

function isValidTipo(tipo: unknown): tipo is 'entrada' | 'salida' {
  return tipo === 'entrada' || tipo === 'salida';
}

interface GeoContext {
  orgId: string;
  employeeId: string;
}

async function validateGeolocation(
  admin: ReturnType<typeof getSupabaseAdmin>,
  ctx: GeoContext,
  data: { lat?: number; long?: number; lugar_id?: string },
  tipo: string,
  req: Request,
): Promise<Response | null> {
  if (tipo !== 'entrada') return null;
  const geolocObligatoria = await getOrgConfigBoolean(admin, ctx.orgId, 'geolocalizacion_obligatoria', true);
  if (!geolocObligatoria) return null;

  if (data.lat == null || data.long == null) {
    const meta = getRequestMeta(req);
    await logAudit('fichaje_rechazado_sin_geoloc', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, {}, 'info');
    return Response.json(
      { error: 'Geolocalización requerida. Activa la ubicación.', code: 'geoloc_requerida' },
      { status: 400 },
    );
  }
  if (!data.lugar_id) return null;

  const { data: lugar } = await admin
    .from('places')
    .select('lat, long, radio_m')
    .eq('id', data.lugar_id)
    .eq('org_id', ctx.orgId)
    .single();

  if (!lugar || (lugar as { lat: number | null }).lat == null || (lugar as { long: number | null }).long == null) {
    return null;
  }

  const radio = (lugar as { radio_m: number | null }).radio_m ?? 100;
  const tolerancia = await getOrgConfigNumber(admin, ctx.orgId, 'tolerancia_gps_metros', 10);
  const dist = haversineKm(data.lat, data.long, (lugar as { lat: number }).lat, (lugar as { long: number }).long) * 1000;

  if (dist > radio + tolerancia) {
    const meta = getRequestMeta(req);
    await logAudit('fichaje_rechazado_fuera_zona', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { lat: data.lat, long: data.long, lugar_id: data.lugar_id, distancia_m: Math.round(dist) }, 'info');
    return Response.json(
      { error: 'Estás fuera de tu zona de trabajo. Acercate a tu lugar asignado para fichar.', code: 'fuera_zona' },
      { status: 400 },
    );
  }
  return null;
}

export async function handlePostFichajes(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<PostFichajeBody>(body);
  if (!data?.tipo || !isValidTipo(data.tipo)) {
    return Response.json(
      { error: 'tipo requerido: entrada o salida', code: 'validacion' },
      { status: 400 },
    );
  }

  const pepper = process.env.HASH_PEPPER ?? process.env.FICHAJE_HASH_SECRET;
  if (!pepper) {
    await logError('critical', 'fichaje_pepper_missing', { orgId: ctx.orgId, employeeId: ctx.employeeId }, {});
    return Response.json({ error: 'Configuración incorrecta' }, { status: 500 });
  }

  const admin = getSupabaseAdmin();

  if (data.idempotency_key) {
    const { data: existing } = await admin
      .from('fichajes')
      .select('id, tipo, timestamp_servidor, hash_registro')
      .eq('idempotency_key', data.idempotency_key)
      .eq('user_id', ctx.employeeId)
      .maybeSingle();

    if (existing) {
      const meta = getRequestMeta(req);
      await logAudit('request_duplicado_ignorado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip, userAgent: meta.userAgent }, { idempotency_key: data.idempotency_key }, 'info');
      return Response.json(
        {
          id: existing.id,
          tipo: existing.tipo,
          timestamp_servidor: existing.timestamp_servidor,
          hash_registro: existing.hash_registro,
        },
        { status: 200 },
      );
    }
  }

  if (data.tipo === 'entrada') {
    const descansoMinimo = await getOrgConfigNumber(admin, ctx.orgId, 'descanso_minimo_horas', 12);
    const { data: lastFichaje } = await admin
      .from('fichajes')
      .select('id, tipo, timestamp_servidor')
      .eq('user_id', ctx.employeeId)
      .is('reemplazado_por_id', null)
      .order('timestamp_servidor', { ascending: false })
      .limit(1)
      .maybeSingle();

    const validation = validateEntrada(lastFichaje ?? null, new Date(), descansoMinimo);
    if (!validation.allowed) {
      const meta = getRequestMeta(req);
      const logAction = validation.code === 'duplicado_entrada'
        ? 'intento_fichaje_duplicado_entrada'
        : 'fichaje_rechazado_descanso_insuficiente';
      const logDetails = validation.code === 'descanso_insuficiente' && 'descansoHoras' in validation
        ? { horas_transcurridas: Math.round((validation.descansoHoras - validation.esperarHoras) * 10) / 10, horas_requeridas: validation.descansoHoras }
        : {};
      await logAudit(logAction, { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip, userAgent: meta.userAgent }, logDetails, 'info');
      return Response.json(
        { error: validation.message, code: validation.code },
        { status: 400 },
      );
    }
  }

  const geoRes = await validateGeolocation(admin, ctx, data, data.tipo, req);
  if (geoRes) return geoRes;

  const timestampServidor = new Date().toISOString();
  const { data: lastForHash } = await admin
    .from('fichajes')
    .select('id, hash_registro')
    .eq('user_id', ctx.employeeId)
    .is('reemplazado_por_id', null)
    .order('timestamp_servidor', { ascending: false })
    .limit(1)
    .maybeSingle();

  const prevHash = lastForHash?.hash_registro ?? null;
  const hashRegistro = computeHash(
    pepper,
    prevHash,
    ctx.employeeId,
    ctx.orgId,
    data.tipo,
    timestampServidor,
    data.lugar_id ?? null,
    data.lat ?? null,
    data.long ?? null,
  );

  const { data: inserted, error } = await admin
    .from('fichajes')
    .insert({
      user_id: ctx.employeeId,
      org_id: ctx.orgId,
      tipo: data.tipo,
      timestamp_servidor: timestampServidor,
      timestamp_dispositivo: data.timestamp_dispositivo ?? null,
      lugar_id: data.lugar_id ?? null,
      lat: data.lat ?? null,
      long: data.long ?? null,
      hash_registro: hashRegistro,
      hash_anterior_id: lastForHash?.id ?? null,
      idempotency_key: data.idempotency_key ?? null,
    })
    .select('id, tipo, timestamp_servidor, timestamp_dispositivo, hash_registro, hash_anterior_id')
    .single();

  if (error) {
    await logError('critical', 'fichaje_insert_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, {}, error);
    return Response.json({ error: 'Error al registrar fichaje' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('fichaje_creado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip, userAgent: meta.userAgent }, { resource_type: 'fichaje', resource_id: inserted.id, fichaje_id: inserted.id, tipo: inserted.tipo }, 'info');

  const lugarId = inserted.lugar_id as string | null;
  let lugarNombre: string | null = null;
  if (lugarId) {
    const { data: place } = await admin.from('places').select('nombre').eq('id', lugarId).single();
    lugarNombre = (place as { nombre?: string } | null)?.nombre ?? null;
  }
  const payload = {
    id: inserted.id,
    user_id: ctx.employeeId,
    org_id: ctx.orgId,
    tipo: inserted.tipo,
    timestamp_servidor: inserted.timestamp_servidor,
    timestamp_dispositivo: inserted.timestamp_dispositivo,
    lugar_id: lugarId,
    lugar_nombre: lugarNombre,
  };
  void dispatchWebhooks(ctx.orgId, 'fichaje.creado', payload).catch((e) =>
    logError('warning', 'webhook_dispatch_failed', { orgId: ctx.orgId }, { event: 'fichaje.creado' }, e instanceof Error ? e : new Error(String(e))),
  );

  return Response.json(inserted, { status: 201 });
}

export async function handleGetFichajes(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const { limit, offset } = validatePagination(
    url.searchParams.get('limit'),
    url.searchParams.get('offset'),
    { defaultLimit: 50 },
  );

  const admin = getSupabaseAdmin();
  let query = admin
    .from('fichajes')
    .select('id, tipo, timestamp_servidor, timestamp_dispositivo, lugar_id, lat, long, hash_registro', { count: 'exact' })
    .eq('user_id', ctx.employeeId)
    .order('timestamp_servidor', { ascending: false })
    .range(offset, offset + limit - 1);

  if (desde) query = query.gte('timestamp_servidor', desde);
  if (hasta) query = query.lte('timestamp_servidor', hasta);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'fichajes_select_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, {}, error);
    return Response.json({ error: 'Error al listar fichajes', code: 'internal' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0, limit, offset } });
}

const BATCH_MAX = 50;

export async function handlePostFichajesBatch(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = parseBody<{ fichajes: PostFichajeBody[] }>(body);
  if (!data?.fichajes || !Array.isArray(data.fichajes) || data.fichajes.length === 0) {
    return Response.json({ error: 'fichajes array requerido', code: 'validacion' }, { status: 400 });
  }

  if (data.fichajes.length > BATCH_MAX) {
    return Response.json(
      { error: `Máximo ${BATCH_MAX} fichajes por batch`, code: 'validacion' },
      { status: 400 },
    );
  }

  const pepper = process.env.HASH_PEPPER ?? process.env.FICHAJE_HASH_SECRET;
  if (!pepper) {
    await logError('critical', 'fichaje_pepper_missing', { orgId: ctx.orgId, employeeId: ctx.employeeId }, {});
    return Response.json({ error: 'Configuración incorrecta' }, { status: 500 });
  }

  const admin = getSupabaseAdmin();
  const inserted: { id: string; tipo: string; timestamp_servidor: string; idempotency_key?: string }[] = [];
  const toDispatch: { id: string; tipo: string; timestamp_servidor: string; timestamp_dispositivo: string | null; lugar_id: string | null }[] = [];
  const errors: { index: number; error: string; code?: string }[] = [];

  for (let i = 0; i < data.fichajes.length; i++) {
    const item = data.fichajes[i];
    if (!item?.tipo || !isValidTipo(item.tipo)) {
      errors.push({ index: i, error: 'tipo requerido: entrada o salida', code: 'validacion' });
      continue;
    }

    if (item.idempotency_key) {
      const { data: existing } = await admin
        .from('fichajes')
        .select('id, tipo, timestamp_servidor')
        .eq('idempotency_key', item.idempotency_key)
        .eq('user_id', ctx.employeeId)
        .maybeSingle();
      if (existing) {
        inserted.push({ id: existing.id, tipo: existing.tipo, timestamp_servidor: existing.timestamp_servidor, idempotency_key: item.idempotency_key });
        continue; /* no dispatch for idempotency - already sent on first create */
      }
    }

    const geoRes = await validateGeolocation(admin, ctx, item, item.tipo, req);
    if (geoRes) {
      const geoBody = await geoRes.json() as { error?: string; code?: string };
      errors.push({ index: i, error: geoBody.error ?? 'Geolocalización inválida', code: geoBody.code });
      continue;
    }

    const timestampServidor = new Date().toISOString();
    const { data: lastForHash } = await admin
      .from('fichajes')
      .select('id, hash_registro')
      .eq('user_id', ctx.employeeId)
      .is('reemplazado_por_id', null)
      .order('timestamp_servidor', { ascending: false })
      .limit(1)
      .maybeSingle();

    const prevHash = lastForHash?.hash_registro ?? null;
    const hashRegistro = computeHash(
      pepper, prevHash, ctx.employeeId, ctx.orgId,
      item.tipo, timestampServidor, item.lugar_id ?? null, item.lat ?? null, item.long ?? null,
    );

    const { data: row, error: insertErr } = await admin
      .from('fichajes')
      .insert({
        user_id: ctx.employeeId, org_id: ctx.orgId, tipo: item.tipo,
        timestamp_servidor: timestampServidor,
        timestamp_dispositivo: item.timestamp_dispositivo ?? null,
        lugar_id: item.lugar_id ?? null, lat: item.lat ?? null, long: item.long ?? null,
        hash_registro: hashRegistro, hash_anterior_id: lastForHash?.id ?? null,
        idempotency_key: item.idempotency_key ?? null,
      })
      .select('id, tipo, timestamp_servidor')
      .single();

    if (insertErr) {
      await logError('critical', 'fichaje_batch_insert_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, { index: i }, insertErr);
      errors.push({ index: i, error: 'Error al registrar fichaje' });
      continue;
    }

    inserted.push({ id: row.id, tipo: row.tipo, timestamp_servidor: row.timestamp_servidor, idempotency_key: item.idempotency_key });
    toDispatch.push({
      id: row.id,
      tipo: row.tipo,
      timestamp_servidor: row.timestamp_servidor,
      timestamp_dispositivo: item.timestamp_dispositivo ?? null,
      lugar_id: item.lugar_id ?? null,
    });
    const meta = getRequestMeta(req);
    await logAudit('fichaje_creado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip, userAgent: meta.userAgent }, { resource_type: 'fichaje', resource_id: row.id, fichaje_id: row.id, tipo: row.tipo, batch: true }, 'info');
  }

  void fireBatchFichajeWebhooks(admin, ctx, toDispatch);

  return Response.json({ inserted, errors }, { status: 201 });
}

interface BatchFichajeItem {
  id: string;
  tipo: string;
  timestamp_servidor: string;
  timestamp_dispositivo: string | null;
  lugar_id: string | null;
}

async function fireBatchFichajeWebhooks(
  admin: ReturnType<typeof getSupabaseAdmin>,
  ctx: { orgId: string; employeeId: string },
  toDispatch: BatchFichajeItem[],
): Promise<void> {
  if (toDispatch.length === 0) return;

  const lugarIds = [...new Set(toDispatch.map((d) => d.lugar_id).filter((id): id is string => Boolean(id)))];
  const lugarMap = new Map<string, string>();
  if (lugarIds.length > 0) {
    const { data: places } = await admin.from('places').select('id, nombre').in('id', lugarIds);
    for (const p of places ?? []) {
      lugarMap.set((p as { id: string }).id, (p as { nombre: string }).nombre ?? '');
    }
  }

  for (const d of toDispatch) {
    const payload = {
      id: d.id,
      user_id: ctx.employeeId,
      org_id: ctx.orgId,
      tipo: d.tipo,
      timestamp_servidor: d.timestamp_servidor,
      timestamp_dispositivo: d.timestamp_dispositivo,
      lugar_id: d.lugar_id,
      lugar_nombre: d.lugar_id ? lugarMap.get(d.lugar_id) ?? null : null,
    };
    void dispatchWebhooks(ctx.orgId, 'fichaje.creado', payload).catch((e) =>
      logError('warning', 'webhook_dispatch_failed', { orgId: ctx.orgId }, { event: 'fichaje.creado', fichaje_id: d.id }, e instanceof Error ? e : new Error(String(e))),
    );
  }
}
