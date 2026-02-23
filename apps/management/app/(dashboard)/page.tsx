"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Building2, Users, ArrowRight } from "lucide-react";

const stats = [
  {
    label: "Organizaciones",
    value: "12",
    change: "+2 este mes",
    icon: Building2,
    href: "/organizations",
    color: "text-primary",
    bg: "bg-primary/10",
  },
  {
    label: "Empleados totales",
    value: "847",
    change: "+34 este mes",
    icon: Users,
    href: "/organizations",
    color: "text-secondary",
    bg: "bg-secondary/10",
  },
];

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const item = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0 },
};

export default function DashboardPage() {
  return (
    <motion.div
      variants={container}
      initial="hidden"
      animate="show"
      className="space-y-8"
    >
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">
          Dashboard
        </h1>
        <p className="mt-1 text-muted-foreground">
          Resumen del backoffice de fichAR
        </p>
      </div>

      <motion.div
        variants={container}
        className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3"
      >
        {stats.map((stat) => (
          <motion.div key={stat.label} variants={item}>
            <Card className="overflow-hidden transition-shadow hover:shadow-lg">
              <Link href={stat.href}>
                <CardHeader className="flex flex-row items-center justify-between pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    {stat.label}
                  </CardTitle>
                  <div
                    className={`flex h-10 w-10 items-center justify-center rounded-xl ${stat.bg} ${stat.color}`}
                  >
                    <stat.icon className="h-5 w-5" />
                  </div>
                </CardHeader>
                <CardContent>
                  <p className="text-3xl font-bold tracking-tight">{stat.value}</p>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {stat.change}
                  </p>
                  <Button
                    variant="link"
                    className="mt-4 h-auto p-0 text-primary"
                    asChild
                  >
                    <span className="inline-flex items-center gap-1">
                      Ver detalle
                      <ArrowRight className="h-4 w-4" />
                    </span>
                  </Button>
                </CardContent>
              </Link>
            </Card>
          </motion.div>
        ))}
        <motion.div variants={item} className="sm:col-span-2 lg:col-span-1">
          <Card className="h-full border-dashed">
            <CardHeader>
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Accesos rápidos
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <Button variant="outline" className="w-full justify-start" asChild>
                <Link href="/organizations">
                  <Building2 className="mr-2 h-4 w-4" />
                  Nueva organización
                </Link>
              </Button>
            </CardContent>
          </Card>
        </motion.div>
      </motion.div>

      <motion.div variants={item}>
        <Card>
          <CardHeader>
            <CardTitle>Bienvenido a fichAR Management</CardTitle>
            <CardDescription>
              Este es un mock del panel de administración. Navegá a
              Organizaciones para ver la lista o creá una nueva desde el acceso
              rápido.
            </CardDescription>
          </CardHeader>
        </Card>
      </motion.div>
    </motion.div>
  );
}
