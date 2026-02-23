"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Input } from "@/components/ui/input";
import { Plus, Search } from "lucide-react";

const MOCK_ORGS = [
  { id: "1", name: "Acme Corp", employees: 45, createdAt: "2025-01-15" },
  { id: "2", name: "TechStart SA", employees: 12, createdAt: "2025-02-01" },
  { id: "3", name: "Logística Norte", employees: 78, createdAt: "2025-02-10" },
  { id: "4", name: "Consultora Verde", employees: 8, createdAt: "2025-02-18" },
  { id: "5", name: "Industrias del Sur", employees: 156, createdAt: "2025-02-20" },
];

export default function OrganizationsPage() {
  const [search, setSearch] = useState("");

  const filtered = MOCK_ORGS.filter((org) =>
    org.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            Organizaciones
          </h1>
          <p className="mt-1 text-muted-foreground">
            Gestioná las organizaciones y sus empleados
          </p>
        </div>
        <Button asChild>
          <Link href="#" className="inline-flex items-center gap-2">
            <Plus className="h-4 w-4" />
            Nueva organización
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Listado</CardTitle>
          <CardDescription>
            Buscá por nombre para filtrar
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="relative max-w-sm">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Buscar por nombre..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-9"
            />
          </div>
          <div className="overflow-hidden rounded-lg border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nombre</TableHead>
                  <TableHead>Empleados</TableHead>
                  <TableHead>Fecha alta</TableHead>
                  <TableHead className="w-[100px]" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((org) => (
                  <TableRow key={org.id}>
                    <TableCell className="font-medium">{org.name}</TableCell>
                    <TableCell>{org.employees}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {org.createdAt}
                    </TableCell>
                    <TableCell>
                      <Button variant="ghost" size="sm" asChild>
                        <Link href={`/organizations/${org.id}`}>
                          Ver detalle
                        </Link>
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          {filtered.length === 0 && (
            <div className="py-12 text-center text-muted-foreground">
              No se encontraron organizaciones
            </div>
          )}
        </CardContent>
      </Card>
    </motion.div>
  );
}
