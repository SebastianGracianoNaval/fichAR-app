"use client";

import { useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { ArrowLeft } from "lucide-react";

export default function OrganizationDetailError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Organization detail error:", error);
  }, [error]);

  return (
    <div className="space-y-6">
      <Button variant="ghost" asChild>
        <Link href="/organizations" className="gap-2">
          <ArrowLeft className="h-4 w-4" />
          Volver
        </Link>
      </Button>
      <Card>
        <CardContent className="flex flex-col items-center gap-4 py-12">
          <p className="text-center text-muted-foreground">
            Hubo un error al cargar la organizacion.
          </p>
          <Button variant="outline" onClick={reset}>
            Reintentar
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
