/**
 * Places (lugares de trabajo) API.
 * Reference: definiciones/PANTALLAS.md P-ADM-03, plan-mvp-next-steps.md, INTEGRACIONES §3
 * Skills: fichar-supabase, fichar-security, fichar-postgres, fichar-integrations
 */

import * as XLSX from 'xlsx';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import {
  validateUUID,
  validatePagination,
  validateCoords,
  validateRadioM,
  parseDias,
} from '../lib/validators.ts';
import { geocodeAddress, delay, RATE_LIMIT_MS } from '../lib/geocoding.ts';
import { getOrgConfigNumber } from '../lib/org-config.ts';
import { dispatchWebhooks } from '../services/webhook-dispatch.ts';

const NOMBRE_MAX_LEN = 200;
const RADIO_DEFAULT = 100;

interface PlaceBody {
  nombre?: string;
  direccion?: string;
  lat?: number;
  long?: number;
  radio_m?: number;
  dias?: string;
}

function toDiasString(arr: string[]): string {
  return arr.join(',');
}

export async function handleGetPlaces(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const admin = getSupabaseAdmin();

  if (ctx.role === 'admin') {
    const url = new URL(req.url);
    const { limit, offset } = validatePagination(
      url.searchParams.get('limit'),
      url.searchParams.get('offset'),
    );

    const { data: places, error, count } = await admin
      .from('places')
      .select('id, org_id, nombre, direccion, lat, long, radio_m, dias, created_at', { count: 'exact' })
      .eq('org_id', ctx.orgId)
      .order('nombre', { ascending: true })
      .range(offset, offset + limit - 1);

    if (error) {
      await logError('critical', 'places_list_failed', { orgId: ctx.orgId }, {}, error);
      return Response.json({ error: 'Error al listar lugares', code: 'internal' }, { status: 500 });
    }

    const meta = { total: count ?? 0, limit, offset };
    return Response.json({ data: places ?? [], meta });
  }

  const { data: empPlaces } = await admin
    .from('employee_places')
    .select('place_id')
    .eq('employee_id', ctx.employeeId);

  const placeIds = (empPlaces ?? []).map((p: { place_id: string }) => p.place_id);
  if (placeIds.length === 0) {
    return Response.json({ data: [] });
  }

  const { data: places, error } = await admin
    .from('places')
    .select('id, nombre, lat, long, radio_m, direccion, dias')
    .eq('org_id', ctx.orgId)
    .in('id', placeIds)
    .order('nombre', { ascending: true });

  if (error) {
    await logError('critical', 'places_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar lugares', code: 'internal' }, { status: 500 });
  }

  return Response.json({ data: places ?? [] });
}

export async function handlePostPlaces(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON', code: 'parse_error' }, { status: 400 });
  }

  const data = body as PlaceBody;
  const nombre = typeof data?.nombre === 'string' ? data.nombre.trim() : '';
  const direccion = typeof data?.direccion === 'string' ? data.direccion.trim() : '';

  if (!nombre || nombre.length > NOMBRE_MAX_LEN) {
    return Response.json(
      { error: 'Nombre requerido (max 200 caracteres)', code: 'validation' },
      { status: 400 },
    );
  }
  if (!direccion) {
    return Response.json({ error: 'Dirección requerida', code: 'validation' }, { status: 400 });
  }

  const lat = data?.lat;
  const long = data?.long;
  try {
    validateCoords(lat, long);
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Coordenadas inválidas. Lat[-90,90], Long[-180,180].';
    return Response.json({ error: msg, code: 'validation' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();

  let radioM = data?.radio_m;
  if (radioM === undefined || radioM === null) {
    radioM = await getOrgConfigNumber(
      admin,
      ctx.orgId,
      'geolocalizacion_radio_default',
      RADIO_DEFAULT,
    );
  }
  const radioErr = validateRadioM(radioM);
  if (radioErr) {
    return Response.json({ error: radioErr, code: 'validation' }, { status: 400 });
  }

  const diasArr = parseDias(data?.dias);
  if (!diasArr || diasArr.length === 0) {
    return Response.json(
      { error: 'Días requeridos (L,M,X,J,V,S,D al menos uno)', code: 'validation' },
      { status: 400 },
    );
  }

  const { data: existing } = await admin
    .from('places')
    .select('id')
    .eq('org_id', ctx.orgId)
    .ilike('nombre', nombre)
    .maybeSingle();

  if (existing) {
    return Response.json(
      { error: 'Nombre ya existe en la organización.', code: 'duplicate' },
      { status: 400 },
    );
  }

  const { data: place, error } = await admin
    .from('places')
    .insert({
      org_id: ctx.orgId,
      nombre,
      direccion,
      lat: Number(data?.lat),
      long: Number(data?.long),
      radio_m: Math.round(Number(radioM)),
      dias: toDiasString(diasArr),
    })
    .select('id, org_id, nombre, direccion, lat, long, radio_m, dias, created_at')
    .single();

  if (error) {
    await logError('critical', 'place_create_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al crear lugar', code: 'internal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'lugar_creado',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { resource_type: 'place', resource_id: place.id, nombre: place.nombre },
    'info',
  );

  dispatchWebhooks(ctx.orgId, 'lugar.creado', {
    id: place.id,
    nombre: place.nombre,
    direccion: place.direccion,
    lat: place.lat,
    long: place.long,
    radio_m: place.radio_m,
    dias: place.dias,
  }).catch((e) =>
    logError('warning', 'webhook_dispatch_failed', { orgId: ctx.orgId }, { event: 'lugar.creado' }, e instanceof Error ? e : new Error(String(e))),
  );

  const res = { ...place, dias: place.dias?.split(',') ?? [] };
  return Response.json(res, { status: 201 });
}

export async function handlePatchPlaces(req: Request, placeId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  if (!validateUUID(placeId)) {
    return Response.json({ error: 'ID inválido', code: 'validation' }, { status: 400 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON', code: 'parse_error' }, { status: 400 });
  }

  const data = body as PlaceBody;
  const updates: Record<string, unknown> = {};

  if (data?.nombre !== undefined) {
    const nombre = String(data.nombre).trim();
    if (!nombre || nombre.length > NOMBRE_MAX_LEN) {
      return Response.json(
        { error: 'Nombre requerido (max 200 caracteres)', code: 'validation' },
        { status: 400 },
      );
    }
    updates.nombre = nombre;
  }
  if (data?.direccion !== undefined) updates.direccion = String(data.direccion).trim();
  if (data?.lat !== undefined || data?.long !== undefined) {
    const lat = data?.lat ?? 0;
    const long = data?.long ?? 0;
    try {
      validateCoords(lat, long);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Coordenadas inválidas.';
      return Response.json({ error: msg, code: 'validation' }, { status: 400 });
    }
    if (data?.lat !== undefined) updates.lat = Number(data.lat);
    if (data?.long !== undefined) updates.long = Number(data.long);
  }
  if (data?.radio_m !== undefined) {
    const err = validateRadioM(data.radio_m);
    if (err) return Response.json({ error: err, code: 'validation' }, { status: 400 });
    updates.radio_m = Math.round(Number(data.radio_m));
  }
  if (data?.dias !== undefined) {
    const diasArr = parseDias(data.dias);
    if (!diasArr || diasArr.length === 0) {
      return Response.json(
        { error: 'Días inválidos (L,M,X,J,V,S,D al menos uno)', code: 'validation' },
        { status: 400 },
      );
    }
    updates.dias = toDiasString(diasArr);
  }

  if (Object.keys(updates).length === 0) {
    return Response.json({ error: 'Nada que actualizar', code: 'validation' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();

  if (updates.nombre !== undefined) {
    const { data: existing } = await admin
      .from('places')
      .select('id')
      .eq('org_id', ctx.orgId)
      .ilike('nombre', updates.nombre as string)
      .neq('id', placeId)
      .maybeSingle();
    if (existing) {
      return Response.json(
        { error: 'Nombre ya existe en la organización.', code: 'duplicate' },
        { status: 400 },
      );
    }
  }

  const { data: place, error } = await admin
    .from('places')
    .update(updates)
    .eq('id', placeId)
    .eq('org_id', ctx.orgId)
    .select('id, nombre, direccion, lat, long, radio_m, dias')
    .single();

  if (error || !place) {
    return Response.json({ error: 'Lugar no encontrado', code: 'not_found' }, { status: 404 });
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'lugar_actualizado',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { resource_type: 'place', resource_id: placeId, changes: Object.keys(updates) },
    'info',
  );

  const res = { ...place, dias: place.dias?.split(',') ?? [] };
  return Response.json(res);
}

export async function handleDeletePlaces(req: Request, placeId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  if (!validateUUID(placeId)) {
    return Response.json({ error: 'ID inválido', code: 'validation' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();

  const { count } = await admin
    .from('employee_places')
    .select('id', { count: 'exact', head: true })
    .eq('place_id', placeId);

  if ((count ?? 0) > 0) {
    return Response.json(
      { error: 'El lugar tiene empleados asignados. Reasignalos antes.', code: 'lugar_en_uso' },
      { status: 400 },
    );
  }

  const { error } = await admin.from('places').delete().eq('id', placeId).eq('org_id', ctx.orgId);

  if (error) {
    await logError('critical', 'place_delete_failed', { orgId: ctx.orgId, placeId }, {}, error);
    return Response.json({ error: 'Error al eliminar lugar', code: 'internal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'lugar_eliminado',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { resource_type: 'place', resource_id: placeId },
    'info',
  );

  return Response.json({ ok: true });
}

const IMPORT_PLACES_MAX_ROWS = 200;

function parsePlacesFile(filename: string, buf: Uint8Array): unknown[][] | null {
  const ext = filename.toLowerCase().split('.').pop() ?? '';
  if (ext === 'xlsx' || ext === 'xls') {
    const wb = XLSX.read(buf, { type: 'array', raw: true });
    const sheet = wb.Sheets[wb.SheetNames[0]];
    if (!sheet) return null;
    return XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet, { header: 1, defval: '' }) as unknown[][];
  }
  if (ext === 'csv') {
    const decoded = decodeCsvBuf(buf);
    if (!decoded) return null;
    const sep = decoded.slice(0, 500).match(/;/g)?.length >= (decoded.slice(0, 500).match(/,/g)?.length ?? 0) ? ';' : ',';
    return decoded.split(/\r?\n/).map((line) => parseCsvLine(line, sep));
  }
  return null;
}

function decodeCsvBuf(buf: Uint8Array): string | null {
  const withBom = buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
  const toDecode = withBom ? buf.slice(3) : buf;
  const utf8 = new TextDecoder('utf-8', { fatal: false }).decode(toDecode);
  if (!utf8.includes('\uFFFD')) return utf8;
  try {
    return new TextDecoder('iso-8859-1').decode(toDecode);
  } catch {
    return utf8;
  }
}

function parseCsvLine(line: string, sep: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if ((c === sep || c === '\n') && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else if (c !== '\r') {
      current += c;
    }
  }
  result.push(current.trim());
  return result;
}

export async function handleImportPlaces(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  let file: File;
  try {
    const formData = await req.formData();
    const f = formData.get('file');
    if (!f || !(f instanceof File)) {
      return Response.json({ error: 'Archivo requerido (campo file)' }, { status: 400 });
    }
    file = f;
  } catch {
    return Response.json({ error: 'Error al leer formulario' }, { status: 400 });
  }

  const MAX_FILE_SIZE = 5 * 1024 * 1024;
  if (file.size > MAX_FILE_SIZE) {
    return Response.json(
      { error: 'Archivo demasiado grande. Máximo 5 MB.', code: 'file_too_large' },
      { status: 400 },
    );
  }

  const buf = await file.arrayBuffer();
  const rows = parsePlacesFile(file.name, new Uint8Array(buf));
  if (!rows) {
    return Response.json(
      { error: 'Formato no soportado. Usá XLSX o CSV (UTF-8, Latin1).', code: 'invalid_format' },
      { status: 400 },
    );
  }

  if (rows.length < 2) {
    return Response.json({ error: 'Archivo sin datos' }, { status: 400 });
  }

  const headers = (rows[0] as unknown[]).map((h) => String(h ?? '').toLowerCase().trim());
  const nombreIdx = headers.indexOf('nombre');
  const direccionIdx = headers.indexOf('direccion');
  const latIdx = headers.indexOf('lat');
  const longIdx = headers.indexOf('long');
  const radioIdx = headers.indexOf('radio_m');
  const diasIdx = headers.indexOf('dias');

  if (nombreIdx < 0 || direccionIdx < 0 || radioIdx < 0 || diasIdx < 0) {
    return Response.json(
      { error: 'Columnas requeridas: nombre, direccion, radio_m, dias', code: 'missing_columns' },
      { status: 400 },
    );
  }

  const dataRows = rows.slice(1, 1 + IMPORT_PLACES_MAX_ROWS) as unknown[][];
  const errors: { row: number; reason: string; code?: string }[] = [];
  let imported = 0;
  const admin = getSupabaseAdmin();
  const seenNombres = new Set<string>();

  const { data: existingPlaces } = await admin
    .from('places')
    .select('nombre')
    .eq('org_id', ctx.orgId);
  const existingNombres = new Set(
    (existingPlaces ?? []).map((p: { nombre: string }) => p.nombre?.toLowerCase()).filter(Boolean),
  );

  const radioDefault = await getOrgConfigNumber(
    admin,
    ctx.orgId,
    'geolocalizacion_radio_default',
    RADIO_DEFAULT,
  );

  for (let i = 0; i < dataRows.length; i++) {
    const row = dataRows[i];
    const rowNum = i + 2;
    const nombre = String(row[nombreIdx] ?? '').trim();
    const direccion = String(row[direccionIdx] ?? '').trim();
    const radioRaw = row[radioIdx];
    const diasRaw = row[diasIdx];

    if (!nombre || !direccion) {
      errors.push({ row: rowNum, reason: 'Nombre y dirección requeridos', code: 'validation' });
      continue;
    }
    const nombreKey = nombre.toLowerCase();
    if (seenNombres.has(nombreKey) || existingNombres.has(nombreKey)) {
      errors.push({
        row: rowNum,
        reason: seenNombres.has(nombreKey) ? `Nombre duplicado en el archivo: ${nombre}` : `Nombre ya existe: ${nombre}`,
        code: 'duplicate',
      });
      continue;
    }

    let lat: number;
    let long: number;
    const latVal = latIdx >= 0 ? row[latIdx] : undefined;
    const longVal = longIdx >= 0 ? row[longIdx] : undefined;
    const hasCoords =
      latVal != null &&
      latVal !== '' &&
      String(latVal).trim() !== '' &&
      longVal != null &&
      longVal !== '' &&
      String(longVal).trim() !== '';

    if (hasCoords) {
      try {
        lat = Number(latVal);
        long = Number(longVal);
        validateCoords(lat, long);
      } catch {
        errors.push({ row: rowNum, reason: 'Coordenadas inválidas. Lat[-90,90], Long[-180,180].', code: 'validation' });
        continue;
      }
    } else {
      if (!direccion) {
        errors.push({ row: rowNum, reason: 'Dirección requerida para geocodificar', code: 'missing_address' });
        continue;
      }
      const coords = await geocodeAddress(direccion);
      if (!coords) {
        errors.push({
          row: rowNum,
          reason: 'No pudimos ubicar esa dirección. Ingresá coordenadas manualmente.',
          code: 'geocoding_failed',
        });
        continue;
      }
      lat = coords.lat;
      long = coords.long;
      await delay(RATE_LIMIT_MS);
    }

    let radioM = radioRaw !== undefined && radioRaw !== null && radioRaw !== ''
      ? Number(radioRaw)
      : radioDefault;
    const radioErr = validateRadioM(radioM);
    if (radioErr) {
      errors.push({ row: rowNum, reason: 'Radio debe estar entre 50 y 500 metros.' });
      continue;
    }
    radioM = Math.round(Number(radioM));

    const diasArr = parseDias(diasRaw);
    if (!diasArr || diasArr.length === 0) {
      errors.push({ row: rowNum, reason: 'Días requeridos (L,M,X,J,V,S,D al menos uno)' });
      continue;
    }

    const { error } = await admin.from('places').insert({
      org_id: ctx.orgId,
      nombre,
      direccion,
      lat,
      long,
      radio_m: radioM,
      dias: toDiasString(diasArr),
    });

    if (error) {
      errors.push({ row: rowNum, reason: error.message });
      continue;
    }

    seenNombres.add(nombreKey);
    existingNombres.add(nombreKey);
    imported++;
  }

  const meta = getRequestMeta(req);
  await logAudit(
    'lugares_importados',
    { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip },
    { imported, errors_count: errors.length },
    'info',
  );

  return Response.json({ imported, errors });
}
