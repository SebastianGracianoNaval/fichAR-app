# Analisis: Loading infinito y estado Supabase

## Resumen

El problema de "Loading" infinito se debia al middleware ejecutando llamadas a Supabase (`getUser`, query `management_users`) en el **Edge Runtime**, que en ciertos entornos (localhost, Linux/Debian) colgaba sin responder.

**Solucion aplicada (v2):** El middleware se deshabilito por completo (bypass total). La proteccion de auth se movio al layout del dashboard via `AuthGuard` (client-side con `useAuth`). El cliente hace las llamadas a Supabase desde el navegador, evitando el Edge que colgaba.

---

## Supabase: advisory set_updated_at

El aviso de Supabase:

> Function public.set_updated_at has a role mutable search_path

**Causa:** La funcion `set_updated_at` en las migraciones no define `search_path` explicitamente. Es una recomendacion de seguridad (evitar search_path injection), no causa el Loading.

**Donde esta:** `supabase/migrations/20260221110001_phase4_licencias_alertas.sql`

**Como corregirlo (opcional):** Agregar `SET search_path = ''` o `SET search_path = public` a la definicion de la funcion. No es urgente para el Loading.

---

## Linux Debian

No es causa del Loading. El monorepo, Next.js 16 y Supabase funcionan en Debian. El problema era el middleware en Edge con llamadas a Supabase que colgaban en localhost.

---

## Estructura monorepo

- **workspaces:** Solo `packages/*`. `apps/management` no esta en workspaces, tiene su propio `package.json` y `bun.lock`.
- **turbopack.root:** Configurado en `next.config.ts` apuntando a la raiz del repo.
- **bun run management:** Ejecuta `bun run --cwd apps/management dev`. Correcto.

Mover el proyecto a otra carpeta no deberia cambiar el comportamiento; el problema era el flujo del middleware, no la ruta del proyecto.

---

## Comandos y configuracion

| Comando | Comportamiento |
|---------|----------------|
| `bun run management` | OK. Ejecuta `next dev -p 3001` en apps/management |
| `.env.local` | OK. Carga NEXT_PUBLIC_SUPABASE_*, etc. |
