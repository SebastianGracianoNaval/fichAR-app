"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { LayoutDashboard, Building2 } from "lucide-react";
import { LogoutButton } from "@/components/features/auth/logout-button";
import { AuthGuard } from "@/components/features/auth/auth-guard";

const nav = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/organizations", label: "Organizaciones", icon: Building2 },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();

  return (
    <AuthGuard>
    <div className="flex min-h-screen bg-background">
      <aside className="fixed inset-y-0 left-0 z-10 flex w-64 flex-col border-r bg-card shadow-sm">
        <div className="flex h-16 items-center gap-2 border-b px-6">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary text-primary-foreground">
            <span className="font-bold">f</span>
          </div>
          <span className="text-lg font-semibold tracking-tight">
            fichAR
          </span>
        </div>
        <nav className="flex-1 space-y-0.5 p-4">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                pathname === item.href || (item.href !== "/" && pathname.startsWith(item.href))
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
      </aside>
      <main className="flex-1 pl-64">
        <div className="min-h-screen p-8">
          {children}
        </div>
      </main>
    </div>
    </AuthGuard>
  );
}
