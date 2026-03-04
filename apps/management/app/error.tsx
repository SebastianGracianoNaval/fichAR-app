"use client";

import { useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

/**
 * Error boundary global (M18). Captura errores no manejados en el árbol de la app.
 * Muestra UI de recuperación: reintentar o volver al inicio.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("App error:", error);
  }, [error]);

  return (
    <div className="min-h-[60vh] flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardContent className="flex flex-col items-center gap-6 py-10">
          <h1 className="text-xl font-semibold text-center">
            Algo salió mal
          </h1>
          <p className="text-center text-muted-foreground text-sm">
            Ocurrió un error inesperado. Podés intentar de nuevo o volver al
            inicio.
          </p>
          <div className="flex flex-wrap gap-3 justify-center">
            <Button variant="outline" onClick={reset}>
              Reintentar
            </Button>
            <Button asChild>
              <Link href="/">Ir al inicio</Link>
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
