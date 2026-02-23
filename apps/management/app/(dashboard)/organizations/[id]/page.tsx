"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { ArrowLeft, Building2, Mail, Users } from "lucide-react";

const MOCK_ORGS: Record<string, { name: string; employees: number; adminEmail: string; createdAt: string }> = {
  "1": {
    name: "Acme Corp",
    employees: 45,
    adminEmail: "admin@acme.com",
    createdAt: "2025-01-15",
  },
  "2": {
    name: "TechStart SA",
    employees: 12,
    adminEmail: "contacto@techstart.com",
    createdAt: "2025-02-01",
  },
  "3": {
    name: "Logística Norte",
    employees: 78,
    adminEmail: "admin@logisticanorte.com",
    createdAt: "2025-02-10",
  },
  "4": {
    name: "Consultora Verde",
    employees: 8,
    adminEmail: "info@consultoraverde.com",
    createdAt: "2025-02-18",
  },
  "5": {
    name: "Industrias del Sur",
    employees: 156,
    adminEmail: "rrhh@industriasdelsur.com",
    createdAt: "2025-02-20",
  },
};

export default function OrganizationDetailPage() {
  const params = useParams<{ id: string }>();
  const org = params?.id ? MOCK_ORGS[params.id] : null;

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
            Organización no encontrada
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
                <CardDescription>Detalle de la organización</CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-3 text-sm">
              <Users className="h-4 w-4 text-muted-foreground" />
              <span className="text-muted-foreground">Empleados:</span>
              <span className="font-medium">{org.employees}</span>
            </div>
            <div className="flex items-center gap-3 text-sm">
              <Mail className="h-4 w-4 text-muted-foreground" />
              <span className="text-muted-foreground">Admin:</span>
              <span className="font-medium">{org.adminEmail}</span>
            </div>
            <div className="pt-2 text-sm text-muted-foreground">
              Alta: {org.createdAt}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Acciones</CardTitle>
            <CardDescription>
              Operaciones disponibles para esta organización
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <Button variant="outline" className="w-full justify-start" disabled>
              Ver empleados (próximamente)
            </Button>
            <Button variant="outline" className="w-full justify-start" disabled>
              Configuración (próximamente)
            </Button>
          </CardContent>
        </Card>
      </div>
    </motion.div>
  );
}
