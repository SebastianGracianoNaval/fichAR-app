const API_TIMEOUT_MS = 15_000;

function getApiUrl(): string {
  const url = process.env.NEXT_PUBLIC_FICHAR_API_URL;
  if (!url) {
    throw new Error("Missing NEXT_PUBLIC_FICHAR_API_URL");
  }
  return url.replace(/\/$/, "");
}

export type ManagementLoginResult = {
  access_token: string;
  refresh_token: string;
  expires_in: number;
};

export type ManagementLoginError = {
  error: string;
  retryAfter?: number;
};

export async function managementLogin(
  email: string,
  password: string
): Promise<ManagementLoginResult> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  try {
    const res = await fetch(`${getApiUrl()}/api/v1/management/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: email.trim().toLowerCase(),
        password,
      }),
      signal: controller.signal,
    });

    const data = (await res.json().catch(() => ({}))) as
      | ManagementLoginResult
      | ManagementLoginError;

    clearTimeout(timeoutId);

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
    if (!res.ok) {
      const message =
        typeof (data as ManagementLoginError).error === "string"
          ? (data as ManagementLoginError).error
          : `HTTP ${res.status}`;
      throw new ManagementApiException(message, mapStatusToCode(res.status), res.status);
    }

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
  } catch (err) {
    clearTimeout(timeoutId);
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
  }
}

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

export async function createOrganization(
  orgName: string,
  adminEmail: string,
  apiKey: string,
  adminFullName?: string
): Promise<CreateOrganizationResult> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  const body: { orgName: string; adminEmail: string; adminFullName?: string } = {
    orgName,
    adminEmail,
  };
  if (adminFullName != null && adminFullName.trim().length > 0) {
    body.adminFullName = adminFullName.trim().slice(0, 255);
  }

  try {
    const res = await fetch(`${getApiUrl()}/api/v1/management/organizations`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    const data = (await res.json().catch(() => ({}))) as { error?: string; code?: string };

    clearTimeout(timeoutId);

    if (!res.ok) {
      const code = data?.code === "email_exists" ? "email_exists" : mapStatusToCode(res.status);
      const message = (typeof data?.error === "string" ? data.error : null) ?? `HTTP ${res.status}`;
      throw new ManagementApiException(message, code, res.status);
    }

    return data as CreateOrganizationResult;
  } catch (err) {
    clearTimeout(timeoutId);

    if (err instanceof ManagementApiException) {
      throw err;
    }
    if (err instanceof Error) {
      if (err.name === "AbortError") {
        throw new ManagementApiException(
          "Servicio no disponible. Reintente mas tarde.",
          "service_unavailable"
        );
      }
      throw new ManagementApiException(
        err.message,
        "network_error"
      );
    }
    throw new ManagementApiException("Error desconocido", "network_error");
  }
}

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

async function fetchWithRetry(
  url: string,
  opts: RequestInit,
  retries = 1
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
    }
  }
  throw lastErr;
}

export type ManagementStats = {
  organization_count: number;
  employee_count: number;
};

export async function getStats(apiKey: string): Promise<ManagementStats> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  try {
    const res = await fetchWithRetry(
      `${getApiUrl()}/api/v1/management/stats`,
      {
        method: "GET",
        headers: { Authorization: `Bearer ${apiKey}` },
        signal: controller.signal,
      }
    );

    const data = (await res.json().catch(() => ({}))) as
      | ManagementStats
      | { error?: string };

    clearTimeout(timeoutId);

    if (!res.ok) {
      const code = mapStatusToCode(res.status);
      const message =
        (typeof (data as { error?: string }).error === "string"
          ? (data as { error: string }).error
          : null) ?? `HTTP ${res.status}`;
      throw new ManagementApiException(message, code, res.status);
    }

    return data as ManagementStats;
  } catch (err) {
    clearTimeout(timeoutId);
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
  }
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

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  try {
    const res = await fetchWithRetry(
      `${getApiUrl()}/api/v1/management/organizations?${params}`,
      {
        method: "GET",
        headers: { Authorization: `Bearer ${apiKey}` },
        signal: controller.signal,
      }
    );

    const data = (await res.json().catch(() => ({}))) as
      | ListOrganizationsResult
      | { error?: string };

    clearTimeout(timeoutId);

    if (!res.ok) {
      const code = mapStatusToCode(res.status);
      const message =
        (typeof (data as { error?: string }).error === "string"
          ? (data as { error: string }).error
          : null) ?? `HTTP ${res.status}`;
      throw new ManagementApiException(message, code, res.status);
    }

    return data as ListOrganizationsResult;
  } catch (err) {
    clearTimeout(timeoutId);
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
  }
}

export async function getOrganizationById(
  apiKey: string,
  id: string
): Promise<OrganizationDetail | null> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  try {
    const res = await fetchWithRetry(
      `${getApiUrl()}/api/v1/management/organizations/${encodeURIComponent(id)}`,
      {
        method: "GET",
        headers: { Authorization: `Bearer ${apiKey}` },
        signal: controller.signal,
      }
    );

    const data = (await res.json().catch(() => ({}))) as
      | OrganizationDetail
      | { error?: string };

    clearTimeout(timeoutId);

    if (res.status === 404) return null;
    if (!res.ok) {
      const code = mapStatusToCode(res.status);
      const message =
        (typeof (data as { error?: string }).error === "string"
          ? (data as { error: string }).error
          : null) ?? `HTTP ${res.status}`;
      throw new ManagementApiException(message, code, res.status);
    }

    return data as OrganizationDetail;
  } catch (err) {
    clearTimeout(timeoutId);
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
  }
}
