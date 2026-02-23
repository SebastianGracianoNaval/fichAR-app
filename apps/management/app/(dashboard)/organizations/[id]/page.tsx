"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { ArrowLeft, Building2, Mail, Users } from "lucide-react";
import { getOrganizationByIdAction } from "../actions";
import type { OrganizationDetail } from "@/lib/api/management";

function formatDate(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleDateString("es-AR", {
      year: "numeric",
      month: "long",
      day: "numeric",
    });
  } catch {
    return iso;
  }
}

export default function OrganizationDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params?.id ?? "";
  const [org, setOrg] = useState<OrganizationDetail | null | undefined>(undefined);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!id) {
      setOrg(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    getOrganizationByIdAction(id).then((result) => {
      if (cancelled) return;
      setLoading(false);
      if (result.ok) {
        setOrg(result.data);
      } else {
        setOrg(null);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [id]);

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="h-10 w-32 animate-pulse rounded bg-muted" />
        <div className="grid gap-6 md:grid-cols-2">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-3">
                <div className="h-12 w-12 animate-pulse rounded-xl bg-muted" />
                <div className="space-y-2">
                  <div className="h-6 w-40 animate-pulse rounded bg-muted" />
                  <div className="h-4 w-48 animate-pulse rounded bg-muted" />
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="h-4 w-full animate-pulse rounded bg-muted" />
              <div className="h-4 w-3/4 animate-pulse rounded bg-muted" />
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  if (!org) {
    return (
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        className="space-y-6"
      >
        <Button variant="ghost" asChild>
          <Link href="/organizations" className="gap-2">
            <ArrowLeft className="h-4 w-4" />
            Volver
          </Link>
        </Button>
        <Card>
          <CardContent className="py-12 text-center text-muted-foreground">
            Organizacion no encontrada
          </CardContent>
        </Card>
      </motion.div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <Button variant="ghost" asChild>
          <Link href="/organizations" className="gap-2">
            <ArrowLeft className="h-4 w-4" />
            Volver a organizaciones
          </Link>
        </Button>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary">
                <Building2 className="h-6 w-6" />
              </div>
              <div>
                <CardTitle className="text-xl">{org.name}</CardTitle>
                <CardDescription>Detalle de la organizacion</CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-3 text-sm">
              <Users className="h-4 w-4 text-muted-foreground" />
              <span className="text-muted-foreground">Empleados:</span>
              <span className="font-medium">{org.employee_count}</span>
            </div>
            {org.admin_email && (
              <div className="flex items-center gap-3 text-sm">
                <Mail className="h-4 w-4 text-muted-foreground" />
                <span className="text-muted-foreground">Admin:</span>
                <span className="font-medium">{org.admin_email}</span>
              </div>
            )}
            <div className="pt-2 text-sm text-muted-foreground">
              Alta: {formatDate(org.created_at)}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Acciones</CardTitle>
            <CardDescription>
              Operaciones disponibles para esta organizacion
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <Button variant="outline" className="w-full justify-start" disabled>
              Ver empleados (proximamente)
            </Button>
            <Button variant="outline" className="w-full justify-start" disabled>
              Configuracion (proximamente)
            </Button>
          </CardContent>
        </Card>
      </div>
    </motion.div>
  );
}
