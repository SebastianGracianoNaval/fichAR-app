"use client";

import { useState, useCallback, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { LayoutDashboard, Building2, Menu, X } from "lucide-react";
import { LogoutButton } from "@/components/features/auth/logout-button";
import { AuthGuard } from "@/components/features/auth/auth-guard";

const nav = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/organizations", label: "Organizaciones", icon: Building2 },
];

function SidebarContent({
  pathname,
  onNavigate,
}: {
  pathname: string;
  onNavigate?: () => void;
}) {
  return (
    <>
      <div className="flex h-16 items-center gap-2 border-b px-6">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-primary-foreground">
          <span className="font-bold">f</span>
        </div>
        <span className="text-lg font-semibold tracking-tight">fichAR</span>
      </div>
      <nav className="flex-1 space-y-0.5 p-4" aria-label="Navegación principal">
        {nav.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            onClick={onNavigate}
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
              pathname === item.href ||
                (item.href !== "/" && pathname.startsWith(item.href))
                ? "bg-primary/10 text-primary"
                : "text-muted-foreground hover:bg-muted hover:text-foreground"
            )}
          >
            <item.icon className="h-4 w-4 shrink-0" />
            {item.label}
          </Link>
        ))}
      </nav>
      <div className="border-t p-4">
        <LogoutButton />
      </div>
    </>
  );
}

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  const closeMobile = useCallback(() => setMobileOpen(false), []);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  return (
    <AuthGuard>
      <a
        href="#main-content"
        className="absolute left-4 top-4 z-50 -translate-y-[200%] rounded-md bg-primary px-4 py-2 text-primary-foreground transition focus:translate-y-0 focus:outline-none focus:ring-2 focus:ring-ring"
      >
        Saltar al contenido
      </a>
      <div className="flex min-h-screen bg-background">
        {/* Desktop sidebar — always visible on md+ */}
        <aside className="fixed inset-y-0 left-0 z-10 hidden w-64 flex-col border-r bg-card shadow-sm md:flex">
          <SidebarContent pathname={pathname} />
        </aside>

        {/* Mobile overlay */}
        {mobileOpen && (
          <div
            className="fixed inset-0 z-30 bg-black/50 md:hidden"
            onClick={closeMobile}
            aria-hidden="true"
          />
        )}

        {/* Mobile sidebar drawer */}
        <aside
          className={cn(
            "fixed inset-y-0 left-0 z-40 flex w-64 flex-col border-r bg-card shadow-lg transition-transform duration-200 md:hidden",
            mobileOpen ? "translate-x-0" : "-translate-x-full"
          )}
        >
          <SidebarContent pathname={pathname} onNavigate={closeMobile} />
        </aside>

        {/* Main content */}
        <main
          id="main-content"
          tabIndex={-1}
          className="flex-1 md:pl-64"
        >
          {/* Mobile top bar */}
          <header className="sticky top-0 z-20 flex h-14 items-center gap-3 border-b bg-card px-4 md:hidden">
            <button
              type="button"
              onClick={() => setMobileOpen(true)}
              className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
              aria-label="Abrir menú"
            >
              <Menu className="h-5 w-5" />
            </button>
            <span className="text-sm font-semibold">fichAR</span>
          </header>
          <div className="min-h-screen p-4 md:p-8">{children}</div>
        </main>
      </div>
    </AuthGuard>
  );
}
