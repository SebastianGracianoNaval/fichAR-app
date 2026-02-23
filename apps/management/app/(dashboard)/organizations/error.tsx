"use client";

import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default function OrganizationsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Organizations error:", error);
  }, [error]);

  return (
    <div className="space-y-6">
      <Card>
        <CardContent className="flex flex-col items-center gap-4 py-12">
          <p className="text-center text-muted-foreground">
            Hubo un error al cargar las organizaciones.
          </p>
          <Button variant="outline" onClick={reset}>
            Reintentar
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
