import { getSupabaseAdmin } from '../lib/supabase.ts';
import { requireAuth } from '../lib/auth-middleware.ts';
import { parseBody } from '../lib/validators.ts';
import { computeHash } from '../services/fichaje-hash.ts';

const DESCANSO_HORAS = 12;

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
    console.error('fichajes: HASH_PEPPER or FICHAJE_HASH_SECRET not set');
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
      console.log('request_duplicado_ignorado', { idempotency_key: data.idempotency_key });
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
    const { data: lastFichaje } = await admin
      .from('fichajes')
      .select('id, tipo, timestamp_servidor')
      .eq('user_id', ctx.employeeId)
      .is('reemplazado_por_id', null)
      .order('timestamp_servidor', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (lastFichaje?.tipo === 'entrada') {
      return Response.json(
        {
          error: 'Ya registraste entrada. Registrar salida primero.',
          code: 'duplicado_entrada',
        },
        { status: 400 },
      );
    }

    if (lastFichaje?.tipo === 'salida') {
      const lastSalida = new Date(lastFichaje.timestamp_servidor);
      const now = new Date();
      const horasDesdeSalida = (now.getTime() - lastSalida.getTime()) / (1000 * 60 * 60);
      if (horasDesdeSalida < DESCANSO_HORAS) {
        const esperar = Math.ceil((DESCANSO_HORAS - horasDesdeSalida) * 10) / 10;
        return Response.json(
          {
            error: `Debés esperar ${esperar} horas más para cumplir el descanso mínimo de 12 horas (Art. 198 LCT). Tu última salida fue a las ${lastSalida.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })}.`,
            code: 'descanso_insuficiente',
          },
          { status: 400 },
        );
      }
    }
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
    console.error('fichajes: insert failed', error);
    return Response.json({ error: 'Error al registrar fichaje' }, { status: 500 });
  }

  return Response.json(inserted, { status: 201 });
}

export async function handleGetFichajes(req: Request): Promise<Response> {
  const authResult = await requireAuth(req);
  if (!authResult.ok) return authResult.res;
  const { ctx } = authResult;

  const url = new URL(req.url);
  const desde = url.searchParams.get('desde');
  const hasta = url.searchParams.get('hasta');
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 100);
  const offset = parseInt(url.searchParams.get('offset') ?? '0', 10) || 0;

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
    console.error('fichajes: select failed', error);
    return Response.json({ error: 'Error al listar fichajes' }, { status: 500 });
  }

  return Response.json({ data: data ?? [], meta: { total: count ?? 0 } });
}
