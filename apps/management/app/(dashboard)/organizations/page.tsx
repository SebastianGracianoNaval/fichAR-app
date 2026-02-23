"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
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
import { Plus, Search, ChevronLeft, ChevronRight, Building2 } from "lucide-react";
import { getOrganizationsAction } from "./actions";
import { CreateOrgDialog } from "@/components/features/organizations/create-org-dialog";
import type { OrganizationListItem } from "@/lib/api/management";

const PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 300;

function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const id = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);

  return debouncedValue;
}

function formatDate(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleDateString("es-AR", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  } catch {
    return iso;
  }
}

export default function OrganizationsPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<{
    items: OrganizationListItem[];
    total: number;
    page: number;
    limit: number;
  } | null>(null);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);

  const debouncedSearch = useDebounce(search, SEARCH_DEBOUNCE_MS);

  const fetchData = useCallback(async () => {
    setLoading(true);
    const result = await getOrganizationsAction(page, PAGE_SIZE, debouncedSearch);
    setLoading(false);
    if (result.ok) {
      setData(result.data);
    } else {
      setData({ items: [], total: 0, page: 1, limit: PAGE_SIZE });
    }
  }, [page, debouncedSearch]);

  useEffect(() => {
    void fetchData();
  }, [fetchData]);

  const totalPages = data ? Math.ceil(data.total / data.limit) : 0;
  const hasNext = data && page < totalPages;
  const hasPrev = page > 1;
  const isEmpty = data && data.items.length === 0;
  const isSearchEmpty = isEmpty && debouncedSearch.length > 0;

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="space-y-6"
    >
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Organizaciones</h1>
          <p className="mt-1 text-muted-foreground">
            Gestiona las organizaciones y sus empleados
          </p>
        </div>
        <Button onClick={() => setDialogOpen(true)} className="inline-flex items-center gap-2">
          <Plus className="h-4 w-4" />
          Nueva organizacion
        </Button>
      </div>

      <CreateOrgDialog open={dialogOpen} onOpenChange={setDialogOpen} />

      <Card>
        <CardHeader>
          <CardTitle>Listado</CardTitle>
          <CardDescription>Busca por nombre para filtrar</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="relative max-w-sm">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Buscar por nombre..."
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              className="pl-9"
            />
          </div>

          {loading ? (
            <div className="space-y-3">
              {[1, 2, 3, 4, 5].map((i) => (
                <div
                  key={i}
                  className="h-12 animate-pulse rounded-lg bg-muted"
                  aria-hidden
                />
              ))}
            </div>
          ) : (
            <>
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
                    {data?.items.map((org) => (
                      <TableRow key={org.id}>
                        <TableCell className="font-medium">{org.name}</TableCell>
                        <TableCell>{org.employee_count}</TableCell>
                        <TableCell className="text-muted-foreground">
                          {formatDate(org.created_at)}
                        </TableCell>
                        <TableCell>
                          <Button variant="ghost" size="sm" asChild>
                            <Link href={`/organizations/${org.id}`}>Ver detalle</Link>
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              {isEmpty && (
                <div className="flex flex-col items-center gap-4 py-12 text-center">
                  <div className="flex h-16 w-16 items-center justify-center rounded-full bg-muted">
                    <Building2 className="h-8 w-8 text-muted-foreground" />
                  </div>
                  <div>
                    <p className="font-medium">
                      {isSearchEmpty
                        ? "No se encontraron organizaciones"
                        : "No hay organizaciones"}
                    </p>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {isSearchEmpty
                        ? "Proba con otro termino de busqueda"
                        : "Crea la primera organizacion"}
                    </p>
                    {!isSearchEmpty && (
                      <Button
                        className="mt-4"
                        onClick={() => setDialogOpen(true)}
                      >
                        Crear organizacion
                      </Button>
                    )}
                  </div>
                </div>
              )}

              {!isEmpty && data && data.total > 0 && (
                <div className="flex items-center justify-between">
                  <p className="text-sm text-muted-foreground">
                    {data.items.length} de {data.total} organizaciones
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setPage((p) => Math.max(1, p - 1))}
                      disabled={!hasPrev}
                    >
                      <ChevronLeft className="h-4 w-4" />
                      Anterior
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setPage((p) => p + 1)}
                      disabled={!hasNext}
                    >
                      Siguiente
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
    </motion.div>
  );
}
