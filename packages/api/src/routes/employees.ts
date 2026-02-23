import * as XLSX from 'xlsx';
import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { requireAdmin } from '../lib/require-admin.ts';
import { logAudit, logError, getRequestMeta } from '../lib/logger.ts';
import { validateCuil, validateEmail, validatePagination } from '../lib/validators.ts';
import { sendWelcomeWithLink } from '../lib/email-service.ts';
import { VALID_ROLES } from '@fichar/shared';

function randomPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  let s = '';
  for (let i = 0; i < 16; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s + '1A';
}

const ADMIN_OR_SUPERVISOR = ['admin', 'supervisor'];

function canListEmployees(role: string): boolean {
  return ADMIN_OR_SUPERVISOR.includes(role);
}

export async function handleGetEmployees(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canListEmployees(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const url = new URL(req.url);
  const branchId = url.searchParams.get('branch_id');
  const status = url.searchParams.get('status') ?? 'activo';
  const { limit, offset } = validatePagination(
    url.searchParams.get('limit'),
    url.searchParams.get('offset'),
    { defaultLimit: 50 },
  );

  const admin = getSupabaseAdmin();
  let query = admin
    .from('employees')
    .select('id, org_id, branch_id, supervisor_id, email, name, dni, cuil, role, status, modalidad, fecha_ingreso, fecha_egreso, created_at', { count: 'exact' })
    .eq('org_id', ctx.orgId)
    .order('name', { ascending: true })
    .range(offset, offset + limit - 1);

  if (ctx.role === 'supervisor') {
    query = query.or(`supervisor_id.eq.${ctx.employeeId},id.eq.${ctx.employeeId}`);
  }
  if (branchId) query = query.eq('branch_id', branchId);
  if (status) query = query.eq('status', status);

  const { data, error, count } = await query;

  if (error) {
    await logError('critical', 'employees_list_failed', { orgId: ctx.orgId }, {}, error);
    return Response.json({ error: 'Error al listar empleados', code: 'internal' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0, limit, offset } });
}

export async function handleGetEmployeeById(req: Request, employeeId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  if (!canListEmployees(ctx.role)) {
    return Response.json({ error: 'No tenés permiso', code: 'sin_permiso' }, { status: 403 });
  }

  const admin = getSupabaseAdmin();
  const { data: emp, error } = await admin
    .from('employees')
    .select('id, org_id, branch_id, supervisor_id, email, name, dni, cuil, role, status, modalidad, fecha_ingreso, fecha_egreso, created_at')
    .eq('id', employeeId)
    .eq('org_id', ctx.orgId)
    .single();

  if (error || !emp) {
    return Response.json({ error: 'Empleado no encontrado', code: 'not_found' }, { status: 404 });
  }

  if (ctx.role === 'supervisor' && emp.supervisor_id !== ctx.employeeId && emp.id !== ctx.employeeId) {
    return Response.json({ error: 'No tenés permiso para ver este empleado', code: 'sin_permiso' }, { status: 403 });
  }

  const { data: empPlaces } = await admin
    .from('employee_places')
    .select('place_id')
    .eq('employee_id', employeeId);
  const placeIds = (empPlaces ?? []).map((p: { place_id: string }) => p.place_id);

  return Response.json({ ...emp, place_ids: placeIds });
}

interface PatchEmployeeBody {
  role?: string;
  branch_id?: string | null;
  supervisor_id?: string | null;
  modalidad?: string;
  place_ids?: string[];
}

export async function handlePatchEmployee(req: Request, employeeId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const data = body as PatchEmployeeBody;
  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

  const admin = getSupabaseAdmin();

  if (data.role !== undefined) {
    if (!(VALID_ROLES as readonly string[]).includes(data.role)) {
      return Response.json({ error: 'Rol inválido' }, { status: 400 });
    }
    const { count } = await admin
      .from('employees')
      .select('id', { count: 'exact', head: true })
      .eq('org_id', ctx.orgId)
      .eq('role', 'admin');
    if (employeeId === ctx.employeeId && data.role !== 'admin' && (count ?? 0) <= 1) {
      return Response.json({ error: 'Debe haber al menos un administrador', code: 'ultimo_admin' }, { status: 400 });
    }
    updates.role = data.role;
  }
  if (data.branch_id !== undefined) updates.branch_id = data.branch_id;
  if (data.supervisor_id !== undefined) updates.supervisor_id = data.supervisor_id;
  if (data.modalidad !== undefined) {
    if (!['presencial', 'remoto', 'hibrido', 'rotativo'].includes(data.modalidad)) {
      return Response.json({ error: 'Modalidad inválida' }, { status: 400 });
    }
    updates.modalidad = data.modalidad;
  }

  if (data.place_ids !== undefined) {
    if (!Array.isArray(data.place_ids)) {
      return Response.json({ error: 'place_ids debe ser un array', code: 'validation' }, { status: 400 });
    }
    const placeIds = data.place_ids as string[];
    const uniqueIds = [...new Set(placeIds)];
    for (const pid of uniqueIds) {
      if (typeof pid !== 'string' || !pid.trim()) {
        return Response.json({ error: 'place_ids inválido', code: 'validation' }, { status: 400 });
      }
    }
    const { data: validPlaces } = await admin
      .from('places')
      .select('id')
      .eq('org_id', ctx.orgId)
      .in('id', uniqueIds);
    const validIds = (validPlaces ?? []).map((p: { id: string }) => p.id);
    if (validIds.length !== uniqueIds.length) {
      const invalid = uniqueIds.filter((id) => !validIds.includes(id));
      return Response.json(
        { error: `Lugares no encontrados: ${invalid.join(', ')}`, code: 'validation' },
        { status: 400 },
      );
    }
    const { error: delErr } = await admin
      .from('employee_places')
      .delete()
      .eq('employee_id', employeeId);
    if (delErr) {
      await logError('critical', 'employee_places_delete_failed', { orgId: ctx.orgId, employeeId }, {}, delErr);
      return Response.json({ error: 'Error al actualizar lugares', code: 'internal' }, { status: 500 });
    }
    if (validIds.length > 0) {
      const rows = validIds.map((placeId) => ({ employee_id: employeeId, place_id: placeId }));
      const { error: insErr } = await admin.from('employee_places').insert(rows);
      if (insErr) {
        await logError('critical', 'employee_places_insert_failed', { orgId: ctx.orgId, employeeId }, {}, insErr);
        return Response.json({ error: 'Error al actualizar lugares', code: 'internal' }, { status: 500 });
      }
    }
  }

  const { data: emp, error } = await admin
    .from('employees')
    .update(updates)
    .eq('id', employeeId)
    .eq('org_id', ctx.orgId)
    .select('id, role, branch_id, supervisor_id, modalidad')
    .single();

  if (error) {
    await logError('critical', 'employee_patch_failed', { orgId: ctx.orgId, employeeId }, {}, error);
    return Response.json({ error: 'Error al actualizar empleado', code: 'internal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  const auditUpdates = { ...updates };
  if (data.place_ids !== undefined) auditUpdates.place_ids = data.place_ids;
  await logAudit('empleado_actualizado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { target_id: employeeId, updates: auditUpdates }, 'info');

  return Response.json(emp);
}

export async function handleOffboardEmployee(req: Request, employeeId: string): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const adminErr = requireAdmin(ctx);
  if (adminErr) return adminErr;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const data = body as { fecha_egreso?: string; motivo?: string };
  const fechaEgreso = data?.fecha_egreso;

  if (!fechaEgreso || !/^\d{4}-\d{2}-\d{2}$/.test(fechaEgreso)) {
    return Response.json({ error: 'fecha_egreso requerida (YYYY-MM-DD)' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();

  const { data: emp, error: empErr } = await admin
    .from('employees')
    .select('id, auth_user_id, role, name')
    .eq('id', employeeId)
    .eq('org_id', ctx.orgId)
    .single();

  if (empErr || !emp) {
    return Response.json({ error: 'Empleado no encontrado', code: 'not_found' }, { status: 404 });
  }

  if (emp.role === 'supervisor') {
    const { count } = await admin
      .from('employees')
      .select('id', { count: 'exact', head: true })
      .eq('supervisor_id', employeeId)
      .eq('status', 'activo');
    if ((count ?? 0) > 0) {
      return Response.json(
        { error: 'Reasigná los empleados a cargo antes de dar de baja a este supervisor.', code: 'supervisor_con_equipo' },
        { status: 400 },
      );
    }
  }

  const { error: updateErr } = await admin
    .from('employees')
    .update({
      status: 'despedido',
      fecha_egreso: fechaEgreso,
      updated_at: new Date().toISOString(),
    })
    .eq('id', employeeId)
    .eq('org_id', ctx.orgId);

  if (updateErr) {
    await logError('critical', 'offboard_failed', { orgId: ctx.orgId, employeeId }, {}, updateErr);
    return Response.json({ error: 'Error al dar de baja', code: 'internal' }, { status: 500 });
  }

  const meta = getRequestMeta(req);
  await logAudit('empleado_despedido', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { target_id: employeeId, fecha_egreso: fechaEgreso, motivo: data?.motivo }, 'info');

  return Response.json({ ok: true });
}

const IMPORT_MAX_ROWS = 1000;
const VALID_MODALIDAD = ['presencial', 'remoto', 'hibrido', 'rotativo'];

function parseImportFile(filename: string, buf: Uint8Array): unknown[][] | null {
  const ext = filename.toLowerCase().split('.').pop() ?? '';
  if (ext === 'xlsx' || ext === 'xls') {
    const wb = XLSX.read(buf, { type: 'array', raw: true });
    const sheet = wb.Sheets[wb.SheetNames[0]];
    if (!sheet) return null;
    return XLSX.utils.sheet_to_json<Record<string, unknown>>(sheet, { header: 1, defval: '' }) as unknown[][];
  }
  if (ext === 'csv') {
    const decoded = decodeCsvBuffer(buf);
    if (!decoded) return null;
    const sep = detectCsvSeparator(decoded);
    return decoded.split(/\r?\n/).map((line) => parseCsvLine(line, sep));
  }
  return null;
}

function decodeCsvBuffer(buf: Uint8Array): string | null {
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

function detectCsvSeparator(firstLines: string): string {
  const sample = firstLines.slice(0, 500);
  const semicolons = (sample.match(/;/g) ?? []).length;
  const commas = (sample.match(/,/g) ?? []).length;
  return semicolons >= commas ? ';' : ',';
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

export async function handleImportEmployees(req: Request): Promise<Response> {
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
    return Response.json({ error: 'Archivo demasiado grande. Máximo 5 MB.', code: 'file_too_large' }, { status: 400 });
  }

  const buf = await file.arrayBuffer();
  const rows = parseImportFile(file.name, new Uint8Array(buf));
  if (!rows) {
    return Response.json({ error: 'Formato no soportado. Usá XLSX o CSV (UTF-8, Latin1).', code: 'invalid_format' }, { status: 400 });
  }

  if (rows.length < 2) return Response.json({ error: 'Archivo sin datos' }, { status: 400 });

  const headers = (rows[0] as unknown[]).map((h) => String(h ?? '').toLowerCase().trim());
  const dniIdx = headers.indexOf('dni');
  const cuilIdx = headers.indexOf('cuil');
  const nombreIdx = headers.indexOf('nombre');
  const emailIdx = headers.indexOf('email');
  const rolIdx = headers.indexOf('rol');
  const modalidadIdx = headers.indexOf('modalidad');
  const lugar1Idx = headers.indexOf('lugar_1');
  const lugar2Idx = headers.indexOf('lugar_2');

  if (dniIdx < 0 || cuilIdx < 0 || nombreIdx < 0 || emailIdx < 0 || rolIdx < 0) {
    return Response.json({ error: 'Columnas requeridas: dni, cuil, nombre, email, rol' }, { status: 400 });
  }

  const dataRows = rows.slice(1, 1 + IMPORT_MAX_ROWS) as unknown[][];
  const errors: { row: number; reason: string }[] = [];
  let imported = 0;
  const admin = getSupabaseAdmin();
  const seenEmails = new Set<string>();

  // Fetch org name, welcome config, places, and existing emails once (VOIS-O: pre-fetch, avoid N+1)
  const [orgResult, cfgResult, placesResult, emailsResult] = await Promise.all([
    admin.from('organizations').select('name').eq('id', ctx.orgId).single(),
    admin.from('org_configs').select('value').eq('org_id', ctx.orgId).eq('key', 'import_welcome').maybeSingle(),
    admin.from('places').select('id, nombre').eq('org_id', ctx.orgId),
    admin.from('employees').select('email').eq('org_id', ctx.orgId),
  ]);
  const orgName = (orgResult.data?.name as string | undefined) ?? 'fichAR';
  const welcomeMethod = (cfgResult.data?.value as string | undefined) ?? 'link';
  const sendWelcomeEmails = welcomeMethod === 'link';

  const existingEmails = new Set(
    (emailsResult.data ?? [])
      .filter((r: { email?: string }) => r.email)
      .map((r: { email: string }) => r.email.toLowerCase()),
  );

  const placeNameToId = new Map<string, string>();
  for (const p of placesResult.data ?? []) {
    const name = (p as { nombre: string }).nombre?.trim();
    if (name) {
      const key = name.toLowerCase();
      if (!placeNameToId.has(key)) placeNameToId.set(key, (p as { id: string }).id);
    }
  }

  const redirectTo =
    process.env.IMPORT_WELCOME_REDIRECT_URL?.trim() ||
    process.env.RESET_PASSWORD_REDIRECT_URL?.trim() ||
    undefined;

  // Collect { email, nombre, link } for batch email sending after loop
  const emailQueue: { email: string; nombre: string; link: string }[] = [];
  const pendingEmployeePlaces: { employeeId: string; placeIds: string[] }[] = [];

  for (let i = 0; i < dataRows.length; i++) {
    const row = dataRows[i];
    const rowNum = i + 2;
    const dni = String(row[dniIdx] ?? '').trim();
    const cuilRaw = String(row[cuilIdx] ?? '').trim();
    const nombre = String(row[nombreIdx] ?? '').trim();
    const email = String(row[emailIdx] ?? '').trim().toLowerCase();
    const rol = String(row[rolIdx] ?? 'empleado').trim().toLowerCase();
    const modalidad = modalidadIdx >= 0 ? String(row[modalidadIdx] ?? 'presencial').trim().toLowerCase() : 'presencial';
    const lugar1Raw = lugar1Idx >= 0 ? String(row[lugar1Idx] ?? '').trim() : '';
    const lugar2Raw = lugar2Idx >= 0 ? String(row[lugar2Idx] ?? '').trim() : '';

    if (!dni || !nombre || !email) {
      errors.push({ row: rowNum, reason: 'Campos obligatorios vacíos' });
      continue;
    }
    if (!validateEmail(email)) {
      errors.push({ row: rowNum, reason: 'Email inválido' });
      continue;
    }
    if (!validateCuil(cuilRaw)) {
      errors.push({ row: rowNum, reason: `Fila ${rowNum}: CUIL inválido` });
      continue;
    }
    if (!(VALID_ROLES as readonly string[]).includes(rol)) {
      errors.push({ row: rowNum, reason: 'Rol inválido' });
      continue;
    }
    if (!VALID_MODALIDAD.includes(modalidad)) {
      errors.push({ row: rowNum, reason: 'Modalidad inválida' });
      continue;
    }
    if (seenEmails.has(email)) {
      errors.push({ row: rowNum, reason: `Email duplicado: ${email}` });
      continue;
    }

    if (existingEmails.has(email)) {
      errors.push({ row: rowNum, reason: `Email ya existe: ${email}` });
      continue;
    }

    const placeIds: string[] = [];
    const missingPlaces: string[] = [];
    for (const raw of [lugar1Raw, lugar2Raw]) {
      if (!raw) continue;
      const placeId = placeNameToId.get(raw.toLowerCase());
      if (!placeId) {
        missingPlaces.push(raw);
      } else if (!placeIds.includes(placeId)) {
        placeIds.push(placeId);
      }
    }
    if (missingPlaces.length > 0) {
      errors.push({ row: rowNum, reason: `Lugar no encontrado: ${missingPlaces.join(', ')}` });
      continue;
    }

    const cuilNorm = cuilRaw.replace(/-/g, '');
    const password = randomPassword();

    const { data: authUser, error: authErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authErr) {
      errors.push({ row: rowNum, reason: authErr.message?.includes('already') ? `Email ya registrado: ${email}` : 'Error al crear usuario' });
      continue;
    }

    const { data: newEmp, error: empErr } = await admin
      .from('employees')
      .insert({
        org_id: ctx.orgId,
        auth_user_id: authUser.user.id,
        email,
        role: rol,
        status: 'activo',
        dni,
        cuil: cuilNorm,
        name: nombre,
        modalidad,
      })
      .select('id')
      .single();

    if (empErr || !newEmp) {
      await admin.auth.admin.deleteUser(authUser.user.id);
      errors.push({ row: rowNum, reason: 'Error al crear empleado' });
      continue;
    }

    if (placeIds.length > 0) {
      pendingEmployeePlaces.push({
        employeeId: (newEmp as { id: string }).id,
        placeIds,
      });
    }

    seenEmails.add(email);
    imported++;

    // Generate recovery link if welcome emails enabled (CL-037: no rollback on email failure)
    if (sendWelcomeEmails) {
      const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
        type: 'recovery',
        email,
        options: { redirectTo },
      });

      if (linkErr || !linkData) {
        await logError('warning', 'import_welcome_link_failed', { orgId: ctx.orgId, employeeId: ctx.employeeId }, { email, reason: linkErr?.message ?? 'no link data' });
      } else {
        const actionLink = (linkData.properties as { action_link?: string } | undefined)?.action_link;
        if (actionLink) {
          emailQueue.push({ email, nombre, link: actionLink });
        } else {
          await logError('warning', 'import_welcome_link_empty', { orgId: ctx.orgId, employeeId: ctx.employeeId }, { email });
        }
      }
    }
  }

  const allEmployeePlacesRows = pendingEmployeePlaces.flatMap(({ employeeId, placeIds }) =>
    placeIds.map((placeId) => ({ employee_id: employeeId, place_id: placeId })),
  );
  if (allEmployeePlacesRows.length > 0) {
    const { error } = await admin.from('employee_places').insert(allEmployeePlacesRows);
    if (error) {
      await logError('warning', 'import_employee_places_batch_failed', { orgId: ctx.orgId }, { count: allEmployeePlacesRows.length }, error);
      for (const { employeeId, placeIds } of pendingEmployeePlaces) {
        const { error: epErr } = await admin
          .from('employee_places')
          .insert(placeIds.map((placeId) => ({ employee_id: employeeId, place_id: placeId })));
        if (epErr) {
          await logError('warning', 'import_employee_places_fallback_failed', { orgId: ctx.orgId, employeeId }, {}, epErr);
        }
      }
    }
  }

  const meta = getRequestMeta(req);

  // Send all welcome emails in parallel after loop (VOIS-V: does not block response)
  const emailFailed: string[] = [];
  if (emailQueue.length > 0) {
    const results = await Promise.allSettled(
      emailQueue.map(({ email, nombre, link }) =>
        sendWelcomeWithLink(email, nombre, link, orgName),
      ),
    );

    await Promise.allSettled(
      results.map((result, idx) => {
        const entry = emailQueue[idx];
        if (!entry) return Promise.resolve();
        if (result.status === 'fulfilled' && result.value.ok) {
          return logAudit('import_email_enviado', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { email: entry.email }, 'info');
        }
        const reason = result.status === 'rejected' ? String(result.reason) : (result.value.error ?? 'unknown');
        emailFailed.push(entry.email);
        return logAudit('import_email_fallido', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { email: entry.email, reason }, 'warning');
      }),
    );
  }

  await logAudit('import_empleados', { orgId: ctx.orgId, employeeId: ctx.employeeId, ip: meta.ip }, { total_filas: dataRows.length, exitosos: imported, fallidos: errors.length, emails_fallidos: emailFailed.length }, 'info');

  return Response.json({
    imported,
    errors,
    ...(emailFailed.length > 0 && { emails_fallidos: emailFailed }),
  });
}
