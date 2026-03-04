const API_TIMEOUT_MS = 15_000;

function getApiUrl(): string {
  const url = process.env.NEXT_PUBLIC_FICHAR_API_URL;
  if (!url) {
    throw new Error("Missing NEXT_PUBLIC_FICHAR_API_URL");
  }
  return url.replace(/\/$/, "");
}

// --- Types ---

export type ManagementLoginResult = {
  access_token: string;
  refresh_token: string;
  expires_in: number;
};

export type ManagementLoginError = {
  error: string;
  retryAfter?: number;
};

export type CreateOrganizationResult = {
  orgId: string;
  userId: string;
  email_sent: boolean;
};

export type ManagementApiError = {
  message: string;
  code?:
    | "validation_error"
    | "email_exists"
    | "forbidden"
    | "not_found"
    | "service_unavailable"
    | "network_error";
  status?: number;
};

export type OrganizationListItem = {
  id: string;
  name: string;
  created_at: string;
  employee_count: number;
};

export type OrganizationDetail = OrganizationListItem & {
  admin_email: string | null;
};

export type ListOrganizationsResult = {
  items: OrganizationListItem[];
  total: number;
  page: number;
  limit: number;
};

export type ManagementStats = {
  organization_count: number;
  employee_count: number;
};

// --- Infrastructure ---

function mapStatusToCode(status: number): ManagementApiError["code"] {
  if (status === 400) return "validation_error";
  if (status === 403) return "forbidden";
  if (status === 404) return "not_found";
  if (status === 409) return "email_exists";
  if (status >= 500) return "service_unavailable";
  return undefined;
}

export class ManagementApiException extends Error {
  readonly code?: ManagementApiError["code"];
  readonly status?: number;

  constructor(message: string, code?: ManagementApiError["code"], status?: number) {
    super(message);
    this.name = "ManagementApiException";
    this.code = code;
    this.status = status;
  }
}

function throwApiError(status: number, data: unknown): never {
  const obj = data as Record<string, unknown> | null;
  const message = typeof obj?.error === "string"
    ? (obj.error as string)
    : `HTTP ${status}`;
  throw new ManagementApiException(message, mapStatusToCode(status), status);
}

async function withTimeout<T>(fn: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  try {
    return await fn(controller.signal);
  } catch (err) {
    if (err instanceof ManagementApiException) throw err;
    if (err instanceof Error && err.name === "AbortError") {
      throw new ManagementApiException(
        "Servicio no disponible. Reintente mas tarde.",
        "service_unavailable"
      );
    }
    throw new ManagementApiException(
      err instanceof Error ? err.message : "Error desconocido",
      "network_error"
    );
  } finally {
    clearTimeout(timeoutId);
  }
}

const RETRY_DELAY_MS = 300;

/**
 * Retries on 5xx and on network errors (with delay). Does not retry on 4xx.
 */
async function fetchWithRetry(
  url: string,
  opts: RequestInit,
  retries = 2
): Promise<Response> {
  let lastErr: unknown;
  for (let i = 0; i <= retries; i++) {
    try {
      const res = await fetch(url, opts);
      if (res.status < 500 || i === retries) return res;
      lastErr = new Error(`HTTP ${res.status}`);
    } catch (e) {
      lastErr = e;
      if (i === retries) throw e;
      await new Promise((r) => setTimeout(r, RETRY_DELAY_MS));
    }
  }
  throw lastErr;
}

type ApiRequestConfig<T> = {
  method: "GET" | "POST";
  path: string;
  body?: object;
  apiKey?: string;
  allow404?: boolean;
  parse?: (data: unknown) => T;
};

async function apiRequest<T>(
  config: ApiRequestConfig<T>
): Promise<T | null> {
  const { method, path, body, apiKey, allow404, parse } = config;
  return withTimeout(async (signal) => {
    const base = getApiUrl();
    const url = path.startsWith("/") ? `${base}${path}` : `${base}/${path}`;
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
    const res = await fetchWithRetry(url, {
      method,
      headers,
      ...(body != null && { body: JSON.stringify(body) }),
      signal,
    });
    const data = await res.json().catch(() => ({}));
    if (res.status === 404 && allow404) return null as T;
    if (!res.ok) throwApiError(res.status, data);
    return (parse ? parse(data) : data) as T;
  });
}

// --- API Functions ---

export async function managementLogin(
  email: string,
  password: string
): Promise<ManagementLoginResult> {
  return withTimeout(async (signal) => {
    const res = await fetchWithRetry(
      `${getApiUrl()}/api/v1/management/auth/login`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim().toLowerCase(), password }),
        signal,
      }
    );

    const data = (await res.json().catch(() => ({}))) as
      | ManagementLoginResult
      | ManagementLoginError;

    if (res.status === 429) {
      const msg =
        typeof (data as ManagementLoginError).error === "string"
          ? (data as ManagementLoginError).error
          : "Demasiados intentos. Espere unos minutos.";
      throw new ManagementApiException(msg, "service_unavailable", 429);
    }
    if (res.status === 401) {
      throw new ManagementApiException(
        typeof (data as ManagementLoginError).error === "string"
          ? (data as ManagementLoginError).error
          : "Credenciales incorrectas",
        "validation_error",
        401
      );
    }
    if (!res.ok) throwApiError(res.status, data);

    const result = data as ManagementLoginResult;
    if (
      !result.access_token ||
      !result.refresh_token ||
      typeof result.expires_in !== "number"
    ) {
      throw new ManagementApiException(
        "Respuesta invalida del servidor",
        "service_unavailable"
      );
    }
    return result;
  });
}

export async function createOrganization(
  orgName: string,
  adminEmail: string,
  apiKey: string,
  adminFullName?: string
): Promise<CreateOrganizationResult> {
  const body: { orgName: string; adminEmail: string; adminFullName?: string } = {
    orgName,
    adminEmail,
  };
  if (adminFullName != null && adminFullName.trim().length > 0) {
    body.adminFullName = adminFullName.trim().slice(0, 255);
  }
  const result = await apiRequest<CreateOrganizationResult>({
    method: "POST",
    path: "/api/v1/management/organizations",
    body,
    apiKey,
  });
  if (result == null) throw new ManagementApiException("Not found", "not_found", 404);
  return result;
}

export async function getStats(apiKey: string): Promise<ManagementStats> {
  const result = await apiRequest<ManagementStats>({
    method: "GET",
    path: "/api/v1/management/stats",
    apiKey,
  });
  if (result == null) throw new ManagementApiException("Not found", "not_found", 404);
  return result;
}

export async function getOrganizations(
  apiKey: string,
  opts?: { page?: number; limit?: number; search?: string }
): Promise<ListOrganizationsResult> {
  const page = opts?.page ?? 1;
  const limit = opts?.limit ?? 20;
  const search = opts?.search?.trim() ?? "";
  const params = new URLSearchParams({ page: String(page), limit: String(limit) });
  if (search) params.set("search", search);
  const result = await apiRequest<ListOrganizationsResult>({
    method: "GET",
    path: `/api/v1/management/organizations?${params}`,
    apiKey,
  });
  if (result == null) throw new ManagementApiException("Not found", "not_found", 404);
  return result;
}

export async function getOrganizationById(
  apiKey: string,
  id: string
): Promise<OrganizationDetail | null> {
  return apiRequest<OrganizationDetail>({
    method: "GET",
    path: `/api/v1/management/organizations/${encodeURIComponent(id)}`,
    apiKey,
    allow404: true,
  });
}
