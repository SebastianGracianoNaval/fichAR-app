# Audit: Cambios de auth (middleware vs client-side)

## Resumen

Por un bug en Edge Runtime (Supabase colgaba en localhost/Linux), el auth del middleware se deshabilito y se movio a client-side (AuthGuard). Este documento audita los cambios y recomienda pasos futuros.

---

## Cambios realizados

| Archivo | Cambio | Necesario |
|---------|--------|-----------|
| `middleware.ts` | Bypass total: solo `NextResponse.next()` | Temporal (workaround) |
| `components/features/auth/auth-guard.tsx` | Nuevo: protege dashboard, check management_users + set-password | Si |
| `app/(dashboard)/layout.tsx` | Envuelve con AuthGuard | Si |
| `app/loading.tsx` | UI de carga durante transiciones | Opcional, no hace dano |
| `next.config.ts` | turbopack.root para monorepo | Si |
| `docs/analisis-loading-y-supabase.md` | Documentacion del problema | Si |
| `docs/analisis-loading-localhost.md` | Analisis previo | Referencia |

---

## Por que funciona con el middleware deshabilitado

1. **Edge Runtime**: El middleware corre en Edge (V8 isolate). Las llamadas a Supabase desde ahi colgaban en ciertos entornos (localhost, Debian).
2. **Client-side**: AuthGuard usa el Supabase client en el navegador. Las peticiones van directo a Supabase, sin pasar por Edge.
3. **Sin bloqueo**: Sin middleware, el servidor responde de inmediato. La pagina carga, React hidrata, AuthGuard hace la verificacion en el cliente.

---

## Es buena practica deshabilitar el middleware?

**No es ideal**, pero es un workaround valido.

| Aspecto | Middleware (server) | AuthGuard (client) |
|---------|---------------------|--------------------|
| Seguridad | Auth antes de enviar HTML | Auth despues de cargar pagina |
| Flash de contenido | No | Breve "Verificando sesion..." |
| Whitelist management_users | Si | Si (en AuthGuard) |
| Set-password redirect | Si | Si (en AuthGuard) |
| Bypass por cliente | Imposible | Teoricamente, pero la API valida |

La API de management usa MANAGEMENT_API_KEY y sesion. Los datos sensibles siguen protegidos por RLS. El AuthGuard evita que usuarios no autenticados vean el dashboard; un atacante podria manipular el cliente pero no obtendria datos sin sesion valida.

---

## Flujo restaurado

1. **Login**: Usuario ingresa credenciales -> Supabase Auth -> redirect a /
2. **AuthGuard** (en dashboard): getSession -> query management_users
   - No en whitelist -> signOut, redirect /login
   - password_changed_at null -> redirect /set-password
   - OK -> mostrar dashboard
3. **Set-password**: Usuario cambia contrasena -> actualiza management_users -> redirect a /
4. **Dashboard**: AuthGuard valida de nuevo, ya tiene password_changed_at -> muestra contenido

---

## Recomendaciones futuras

1. **Migrar a proxy.ts**: Next.js 16 depreco middleware. Usar `proxy.ts` con runtime Node.js (no Edge) podria permitir restaurar auth en servidor sin el bug.
2. **Comando**: `npx @next/codemod@canary middleware-to-proxy .`
3. **Probar**: Con proxy en Node.js, las llamadas a Supabase deberian funcionar. Restaurar la logica original de auth en proxy.ts.
4. **Eliminar AuthGuard** del layout cuando el proxy asuma la proteccion (o mantener AuthGuard como capa defensiva extra).

---

## Codigo no espagueti

- AuthGuard: una responsabilidad (proteger rutas), ~60 lineas
- Middleware: minimo, comentario explicativo
- Sin duplicacion de logica: set-password y whitelist solo en AuthGuard
- LoadingState extraido como componente interno para claridad
