import { type NextRequest, NextResponse } from "next/server";

// BYPASS TOTAL: auth movido a layout/paginas.
// El middleware con Supabase colgaba en Edge/localhost.
// TODO: restaurar auth via proxy.ts (Node.js) o layout.
export function middleware(request: NextRequest) {
  return NextResponse.next({ request });
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|api).*)"],
};
