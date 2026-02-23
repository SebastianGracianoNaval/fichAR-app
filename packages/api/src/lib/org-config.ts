import { getSupabaseAdmin } from './supabase.ts';
import { loadOrgConfigs } from './org-config-cache.ts';

export async function getOrgConfig(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
): Promise<unknown> {
  const configMap = await loadOrgConfigs(admin, orgId);
  return configMap.get(key);
}

export async function getOrgConfigString(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
  defaultValue: string,
): Promise<string> {
  const raw = await getOrgConfig(admin, orgId, key);
  if (typeof raw !== 'string') return defaultValue;
  return raw.trim().toLowerCase();
}

export async function getOrgConfigBoolean(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
  defaultValue: boolean,
): Promise<boolean> {
  const raw = await getOrgConfig(admin, orgId, key);
  if (!raw) return defaultValue;
  const v = raw as unknown;
  return typeof v === 'boolean' ? v : defaultValue;
}

export async function getOrgConfigNumber(
  admin: ReturnType<typeof getSupabaseAdmin>,
  orgId: string,
  key: string,
  defaultValue: number,
): Promise<number> {
  const raw = await getOrgConfig(admin, orgId, key);
  if (raw == null) return defaultValue;
  const n = Number(raw);
  return Number.isFinite(n) ? n : defaultValue;
}
