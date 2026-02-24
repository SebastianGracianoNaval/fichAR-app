"use client";

import { useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { managementLogin, ManagementApiException } from "@/lib/api/management";
import { loginSchema, type LoginFormValues } from "@/lib/validations/auth";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";

const AUTH_ERROR_MESSAGE = "Credenciales incorrectas";
const NETWORK_ERROR_MESSAGE = "Error de conexion. Reintente.";
const RATE_LIMIT_MESSAGE = "Demasiados intentos. Espere unos minutos.";
const LOGIN_TIMEOUT_MS = 15_000;

function withTimeout<T>(promise: Promise<T>, ms: number, msg: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(msg)), ms)
    ),
  ]);
}

function mapAuthError(error: { message?: string }): string {
  const msg = error?.message?.toLowerCase() ?? "";
  if (msg.includes("rate") || msg.includes("too many")) return RATE_LIMIT_MESSAGE;
  if (msg.includes("network") || msg.includes("fetch")) return NETWORK_ERROR_MESSAGE;
  return AUTH_ERROR_MESSAGE;
}

export function LoginForm() {
  const [loading, setLoading] = useState(false);

  const form = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  async function onSubmit(values: LoginFormValues) {
    setLoading(true);
    try {
      const session = await withTimeout(
        managementLogin(values.email.trim().toLowerCase(), values.password),
        LOGIN_TIMEOUT_MS,
        "timeout"
      );

      const supabase = createClient();
      const { error } = await supabase.auth.setSession({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
      });

      if (error) {
        toast.error(mapAuthError(error));
        return;
      }

      window.location.href = "/";
    } catch (err) {
      if (err instanceof ManagementApiException) {
        const isRateLimit = err.status === 429;
        toast.error(isRateLimit ? RATE_LIMIT_MESSAGE : (err.message || AUTH_ERROR_MESSAGE));
        return;
      }
      const msg =
        err instanceof Error ? err.message : "Error inesperado al iniciar sesion";
      const isNetwork =
        msg.toLowerCase().includes("fetch") ||
        msg.toLowerCase().includes("timeout") ||
        msg.toLowerCase().includes("abort");
      toast.error(isNetwork ? NETWORK_ERROR_MESSAGE : msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card className="border-0 shadow-xl shadow-primary/5">
      <CardHeader className="space-y-1 pb-6">
        <div className="mb-4 flex items-center gap-2">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <span className="text-lg font-bold">f</span>
          </div>
          <span className="text-xl font-semibold tracking-tight">
            fichAR Management
          </span>
        </div>
        <CardTitle className="text-2xl font-semibold">Iniciar sesion</CardTitle>
        <CardDescription>
          Ingresa tu correo y contraseña para acceder al panel
        </CardDescription>
      </CardHeader>
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="email"
              render={({ field }) => (
                <FormItem>
                  <FormLabel htmlFor="login-email">Correo electronico</FormLabel>
                  <FormControl>
                    <Input
                      id="login-email"
                      type="email"
                      placeholder="admin@empresa.com"
                      autoComplete="email"
                      disabled={loading}
                      className="h-11 transition-colors"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            <FormField
              control={form.control}
              name="password"
              render={({ field }) => (
                <FormItem>
                  <div className="flex items-center justify-between">
                    <FormLabel htmlFor="login-password">Contrasena</FormLabel>
                    <Link
                      href="/forgot-password"
                      className="text-sm text-muted-foreground underline-offset-4 transition-colors hover:text-primary hover:underline"
                    >
                      Olvide mi contrasena
                    </Link>
                  </div>
                  <FormControl>
                    <Input
                      id="login-password"
                      type="password"
                      placeholder="••••••••"
                      autoComplete="current-password"
                      disabled={loading}
                      className="h-11 transition-colors"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
          <CardFooter className="flex flex-col gap-4 pt-2">
            <Button
              type="submit"
              className="h-11 w-full"
              size="lg"
              disabled={loading}
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-primary-foreground border-t-transparent" />
                  Ingresando...
                </span>
              ) : (
                "Ingresar"
              )}
            </Button>
          </CardFooter>
        </form>
      </Form>
    </Card>
  );
}
