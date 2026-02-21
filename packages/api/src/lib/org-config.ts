import { getSupabaseAdmin } from './supabase.ts';

export async function getOrgConfigBoolean(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
  defaultValue: boolean,
): Promise<boolean> {
  const { data } = await admin
    .from('org_configs')
    .select('value')
    .eq('org_id', orgId)
    .eq('key', key)
    .maybeSingle();
  if (!data?.value) return defaultValue;
  const v = data.value as unknown;
  return typeof v === 'boolean' ? v : defaultValue;
}

export async function getOrgConfigNumber(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
  defaultValue: number,
): Promise<number> {
  const { data } = await admin
    .from('org_configs')
    .select('value')
    .eq('org_id', orgId)
    .eq('key', key)
    .maybeSingle();
  if (data?.value == null) return defaultValue;
  const n = Number(data.value);
  return Number.isFinite(n) ? n : defaultValue;
}
