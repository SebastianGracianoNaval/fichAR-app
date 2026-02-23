import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const AUTH_TIMEOUT_MS = 10_000;
const PUBLIC_PATHS = ["/login", "/forgot-password", "/set-password"] as const;

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

function isSetPasswordWithRecoveryToken(request: NextRequest): boolean {
  const path = request.nextUrl.pathname;
  if (path !== "/set-password" && !path.startsWith("/set-password/")) return false;
  const token = request.nextUrl.searchParams.get("token");
  const type = request.nextUrl.searchParams.get("type");
  return type === "recovery" || Boolean(token);
}

function redirectTo(
  url: string,
  request: NextRequest,
  copyCookiesFrom?: NextResponse
): NextResponse {
  const dest = new URL(url, request.url);
  const res = NextResponse.redirect(dest);
  if (copyCookiesFrom) {
    copyCookiesFrom.cookies.getAll().forEach((c) => res.cookies.set(c.name, c.value));
  }
  return res;
}

function createTimeoutPromise<T>(ms: number): Promise<T> {
  return new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`proxy_auth_timeout: ${ms}ms exceeded`)), ms)
  );
}

export async function updateSession(request: NextRequest): Promise<NextResponse> {
  let supabaseResponse = NextResponse.next({ request });

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    return supabaseResponse;
  }

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          supabaseResponse.cookies.set(name, value, options)
        );
      },
    },
  });

  const pathname = request.nextUrl.pathname;

  if (isSetPasswordWithRecoveryToken(request)) {
    return supabaseResponse;
  }

  if (isPublicPath(pathname)) {
    try {
      const claimsPromise = supabase.auth.getClaims();
      const claims = await Promise.race([
        claimsPromise,
        createTimeoutPromise<never>(AUTH_TIMEOUT_MS),
      ]).then((data) => data?.data?.claims);

      if (claims) {
        const mgmtPromise = supabase
          .from("management_users")
          .select("id, password_changed_at")
          .maybeSingle();
        const mgmt = await Promise.race([
          mgmtPromise,
          createTimeoutPromise<never>(AUTH_TIMEOUT_MS),
        ]).then((r) => r?.data);

        if (mgmt) {
          if (mgmt.password_changed_at === null && pathname !== "/set-password") {
            return redirectTo("/set-password", request, supabaseResponse);
          }
          return redirectTo("/", request, supabaseResponse);
        }
      }
    } catch {
    }
    return supabaseResponse;
  }

  try {
    const claimsPromise = supabase.auth.getClaims();
    const claims = await Promise.race([
      claimsPromise,
      createTimeoutPromise<never>(AUTH_TIMEOUT_MS),
    ]).then((data) => data?.data?.claims);

    if (!claims) {
      return redirectTo("/login", request, supabaseResponse);
    }

    const mgmtPromise = supabase
      .from("management_users")
      .select("id, password_changed_at")
      .maybeSingle();
    const mgmt = await Promise.race([
      mgmtPromise,
      createTimeoutPromise<never>(AUTH_TIMEOUT_MS),
    ]).then((r) => r?.data);

    if (!mgmt) {
      await supabase.auth.signOut();
      return redirectTo("/login", request, supabaseResponse);
    }

    if (mgmt.password_changed_at === null) {
      return redirectTo("/set-password", request, supabaseResponse);
    }

    return supabaseResponse;
  } catch {
    return redirectTo("/login", request, supabaseResponse);
  }
}
