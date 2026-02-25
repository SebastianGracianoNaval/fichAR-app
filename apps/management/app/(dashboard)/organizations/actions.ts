"use server";

import {
  createOrganization,
  getOrganizations,
  getOrganizationById,
  type ListOrganizationsResult,
  type OrganizationDetail,
  type CreateOrganizationResult,
  ManagementApiException,
} from "@/lib/api/management";

function getApiKey(): string {
  const key = process.env.MANAGEMENT_API_KEY?.trim();
  if (!key) {
    throw new Error("MANAGEMENT_API_KEY not configured");
  }
  return key;
}

export type ActionResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: string; code?: string };

export async function getOrganizationsAction(
  page = 1,
  limit = 20,
  search = ""
): Promise<ActionResult<ListOrganizationsResult>> {
  try {
    const key = getApiKey();
    const data = await getOrganizations(key, { page, limit, search });
    return { ok: true, data };
  } catch (e) {
    if (e instanceof ManagementApiException) {
      const msg = mapApiErrorToMessage(e);
      return { ok: false, error: msg, code: e.code };
    }
    return { ok: false, error: "Error de conexion. Reintente." };
  }
}

export async function getOrganizationByIdAction(
  id: string
): Promise<ActionResult<OrganizationDetail | null>> {
  try {
    const key = getApiKey();
    const data = await getOrganizationById(key, id);
    return { ok: true, data };
  } catch (e) {
    if (e instanceof ManagementApiException) {
      const msg = mapApiErrorToMessage(e);
      return { ok: false, error: msg, code: e.code };
    }
    return { ok: false, error: "Error de conexion. Reintente." };
  }
}

export type CreateOrgResult =
  | { ok: true; data: CreateOrganizationResult }
  | { ok: false; error: string; code?: string };

export async function createOrgAction(
  orgName: string,
  adminEmail: string,
  adminFullName?: string
): Promise<CreateOrgResult> {
  try {
    const key = getApiKey();
    const data = await createOrganization(orgName, adminEmail, key, adminFullName);
    return { ok: true, data };
  } catch (e) {
    if (e instanceof ManagementApiException) {
      const msg = mapApiErrorToMessage(e);
      return { ok: false, error: msg, code: e.code };
    }
    return { ok: false, error: "Error de conexion. Reintente." };
  }
}

function mapApiErrorToMessage(e: ManagementApiException): string {
  if (e.code === "email_exists") return "Ese correo ya esta registrado";
  if (e.code === "forbidden") return "No autorizado";
  if (e.code === "not_found") return "Organizacion no encontrada";
  if (e.code === "service_unavailable")
    return "Servicio no disponible. Reintente mas tarde.";
  if (e.code === "validation_error") return e.message || "Datos invalidos";
  return e.message || "Error inesperado";
}
