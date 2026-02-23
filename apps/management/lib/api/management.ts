const API_TIMEOUT_MS = 15_000;

function getApiUrl(): string {
  const url = process.env.NEXT_PUBLIC_FICHAR_API_URL;
  if (!url) {
    throw new Error("Missing NEXT_PUBLIC_FICHAR_API_URL");
  }
  return url.replace(/\/$/, "");
}

export type CreateOrganizationResult = {
  orgId: string;
  userId: string;
  email_sent: boolean;
};

export type ManagementApiError = {
  message: string;
  code?: "validation_error" | "email_exists" | "forbidden" | "service_unavailable" | "network_error";
  status?: number;
};

function mapStatusToCode(status: number): ManagementApiError["code"] {
  if (status === 400) return "validation_error";
  if (status === 403) return "forbidden";
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
  apiKey: string
): Promise<CreateOrganizationResult> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  try {
    const res = await fetch(`${getApiUrl()}/api/v1/management/organizations`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ orgName, adminEmail }),
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
