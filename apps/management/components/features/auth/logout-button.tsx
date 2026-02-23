"use client";

import { useRouter } from "next/navigation";
import { LogOut } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";

export function LogoutButton() {
  const router = useRouter();

  async function handleLogout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.refresh();
    router.push("/login");
  }

  return (
    <Button
      variant="ghost"
      className="w-full justify-start gap-3 px-3 py-2.5 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground"
      onClick={handleLogout}
    >
      <LogOut className="h-4 w-4 shrink-0" />
      Cerrar sesion
    </Button>
  );
}
