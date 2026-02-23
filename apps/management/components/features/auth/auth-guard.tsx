"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useAuth } from "@/hooks/use-auth";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, loading: authLoading } = useAuth();
  const [checkComplete, setCheckComplete] = useState(false);
  const router = useRouter();

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      router.replace("/login");
      return;
    }

    const supabase = createClient();
    supabase
      .from("management_users")
      .select("password_changed_at")
      .maybeSingle()
      .then(({ data, error }) => {
        if (error || !data) {
          void supabase.auth.signOut();
          router.replace("/login");
          return;
        }
        if (data.password_changed_at === null) {
          router.replace("/set-password");
          return;
        }
        setCheckComplete(true);
      });
  }, [user, authLoading, router]);

  if (authLoading) {
    return <LoadingState />;
  }
  if (!user) {
    return null;
  }
  if (!checkComplete) {
    return <LoadingState />;
  }
  return <>{children}</>;
}

function LoadingState() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background">
      <div
        className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
        role="status"
        aria-label="Cargando"
      />
      <p className="mt-4 text-sm text-muted-foreground">
        Verificando sesion...
      </p>
    </div>
  );
}
