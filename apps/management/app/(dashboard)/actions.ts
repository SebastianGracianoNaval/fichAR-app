"use server";

import { getStats, ManagementApiException } from "@/lib/api/management";
import type { ManagementStats } from "@/lib/api/management";

function getApiKey(): string {
  const key = process.env.MANAGEMENT_API_KEY?.trim();
  if (!key) {
    throw new Error("MANAGEMENT_API_KEY not configured");
  }
  return key;
}

export type ActionResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: string };

export async function getStatsAction(): Promise<ActionResult<ManagementStats>> {
  try {
    const key = getApiKey();
    const data = await getStats(key);
    return { ok: true, data };
  } catch (e) {
    if (e instanceof ManagementApiException) {
      return { ok: false, error: e.message };
    }
    return { ok: false, error: "Error de conexion. Reintente." };
  }
}
