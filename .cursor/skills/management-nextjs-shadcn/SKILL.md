---
name: management-nextjs-shadcn
description: Next.js App Router + shadcn/ui patterns for fichar-management. Use when building or reviewing management UI, auth flows, forms, or dashboard screens.
---

# fichar-management — Next.js + shadcn

Guía para desarrollo de fichar-management: Next.js 16 (App Router), shadcn/ui, Supabase Auth, Vercel.

## Cuándo usar

- Pantallas o componentes en `apps/management/`
- Auth (login, forgot-password, set-password)
- Formularios (crear org, cambio de contraseña)
- Dashboard y tablas (organizaciones)
- Route Handlers o Server Actions

---

## Stack

- **Next.js 16** App Router, RSC, Server Actions
- **shadcn/ui** new-york, zinc, CSS variables
- **Tailwind v4** + tw-animate
- **Framer Motion** para transiciones
- **React Hook Form + Zod** para formularios
- **Supabase** Auth (mismo proyecto que fichar-app)
- **Vercel** deploy

---

## Estructura de rutas

```
app/(auth)/login/
app/(auth)/forgot-password/
app/(auth)/set-password/
app/(dashboard)/          → /
app/(dashboard)/organizations/
app/(dashboard)/organizations/[id]/
```

- `(auth)` y `(dashboard)` son route groups; no cambian la URL.
- Usar `loading.tsx` y `error.tsx` por ruta cuando aplique.

---

## RSC y Client Components

- Por defecto: Server Components. No poner `'use client'` si no hace falta.
- `'use client'` para: hooks, eventos, estado, Framer Motion, formularios interactivos.
- Bajar Client Components al mínimo: wrappers pequeños que envuelvan solo la parte interactiva.

---

## shadcn/ui

- Instalar con: `bunx shadcn@latest add <component>`
- Usar variantes: `<Button variant="outline">`, `size="lg"`
- Composición: `asChild` con `Link`, `<Card><CardHeader><CardTitle>`
- Formularios: `Form` + `FormField` + `FormItem` + `FormLabel` + `FormControl` + `FormMessage`
- Validación: Zod schema + zodResolver

---

## Auth y Supabase

- Cliente browser: `lib/supabase/client.ts` (createBrowserClient)
- Cliente server: `lib/supabase/server.ts` (createServerClient, cookies)
- Middleware para proteger rutas de dashboard
- Whitelist: tabla `management_users`. Login solo si el email está en la whitelist.

---

## API Management

- Crear org: `POST /api/v1/management/organizations` (packages/api)
- Llamar desde Server Action o Route Handler con `MANAGEMENT_API_KEY`
- Nunca exponer `MANAGEMENT_API_KEY` al cliente
- Cliente: `lib/api/management.ts` → `createOrganization(orgName, adminEmail, apiKey)`

---

## Paleta (CSS variables)

- `--primary`: teal #0F766E
- `--secondary`: azul #0EA5E9
- `--accent`: verde éxito #10B981
- `--background`, `--foreground`, `--muted`, `--destructive`

Definidas en `app/globals.css`.

---

## Patrones clave

1. **Formularios:** useForm + zodResolver + shadcn Form
2. **Loading:** Skeleton que imite el contenido, no solo spinner
3. **Empty states:** Ilustración o mensaje + CTA
4. **Navegación:** `next/link` para rutas internas
5. **Env:** `NEXT_PUBLIC_*` solo para lo que el cliente necesita; secrets siempre en servidor

---

## Referencias

- `apps/management/AGENTS.md`
- `plans/fichar-management-full-plan.md`
- `documentation/tecnica/management-api.md`
- Next: https://nextjs.org/docs
- shadcn: https://ui.shadcn.com
- Supabase Auth (Next): https://supabase.com/docs/guides/auth/server-side/nextjs
