# Analisis: Loading infinito en localhost (fichar-management)

## Resumen del problema

Al ejecutar `bun run management` y abrir **Local** (http://localhost:3001), la app queda en "Loading..." sin llegar a mostrar login ni dashboard. En **Network** (http://192.168.x.x:3001) el comportamiento puede ser distinto.

---

## 1. Estructura del monorepo

### Situacion actual

- **Raiz:** `package.json` con `workspaces: ["packages/*"]` (solo packages, no apps)
- **Management:** `apps/management/` tiene su propio `package.json`, `bun.lock`, `node_modules`
- **API:** `packages/api` corre en puerto 3000
- **Mobile:** Flutter en `apps/mobile/`; `bun run dev` + `bun run mobile:web` funcionan bien

### Impacto

Next.js 16 con Turbopack detecta **varios lockfiles**:

```
We detected multiple lockfiles and selected the directory of /home/sebastiang/fichar-app/bun.lock
Detected additional lockfiles: apps/management/bun.lock
```

Esto genera ambiguedad en la resolucion de modulos y puede afectar la carga en dev. No es la causa principal del Loading infinito, pero contribuye a comportamientos erraticos.

### Recomendacion

- Definir `turbopack.root` en `next.config.ts` apuntando al directorio del proyecto
- Valorar eliminar `apps/management/bun.lock` si se usa el lockfile de la raiz

---

## 2. Configuracion .env

### .env (raiz)

Usado por `packages/api`. Contiene Supabase, MANAGEMENT_API_KEY, CORS_ORIGINS, etc. Correcto para la API.

### apps/management/.env.local

| Variable | Uso | Estado |
|----------|-----|--------|
| NEXT_PUBLIC_SUPABASE_URL | Supabase Auth (cliente y middleware) | OK |
| NEXT_PUBLIC_SUPABASE_ANON_KEY | Supabase Auth | OK |
| NEXT_PUBLIC_FICHAR_API_URL | Llamadas a API (crear org, etc.) | OK (http://localhost:3000) |
| MANAGEMENT_API_KEY | Server-side para API | OK |
| NEXT_PUBLIC_APP_URL | Redirect forgot-password | OK (http://localhost:3001) |

El terminal muestra `Environments: .env.local`, asi que Next.js carga bien el archivo.

**Conclusion:** Los .env no parecen la causa del Loading infinito.

---

## 3. Por que se queda en Loading

### Hipotesis principal: middleware bloqueante

El middleware (`middleware.ts`) se ejecuta en **cada** request (excepto `_next/static`, `_next/image`, `favicon.ico`, `api`):

1. `createServerClient` con cookies
2. `supabase.auth.getUser()` (llamada de red a Supabase)
3. Si hay usuario: query a `management_users` (RLS filtra por auth.uid())
4. Redirecciones segun estado de auth

**Si alguna de estas llamadas cuelga** (timeout, DNS, red), la respuesta HTTP nunca llega. El navegador queda esperando y muestra "Loading" o una pagina en blanco.

### Posibles causas de cuelgue

| Causa | Probabilidad | Notas |
|-------|--------------|-------|
| Supabase `getUser()` lento/timeout | Alta | Sin timeout explícito en el middleware |
| Query `management_users` lenta | Media | Depende de RLS y latencia a Supabase |
| localhost vs 127.0.0.1 / IPv6 | Media | En algunos entornos localhost se comporta distinto |
| CORS / cookies en localhost | Media | Cookies pueden variar entre localhost y 192.168.x.x |
| Turbopack / monorepo | Baja | Mas bien afecta al build que a la ejecucion en runtime |

### Por que no hay logs

El middleware corre en el **Edge Runtime**. Los errores no controlados pueden no aparecer en la consola del servidor. Si la promesa de `getUser()` o de la query nunca se resuelve, no hay excepcion que loguear.

---

## 4. Diferencia Local vs Network

- **Local:** http://localhost:3001
- **Network:** http://192.168.x.x:3001

Son el mismo proceso, distinto host. Las cookies de Supabase se asocian al origen:

- Si inicias sesion en 192.168.x.x, las cookies son para ese host
- Si cambias a localhost, no hay cookies; el usuario aparece como no autenticado

Si ademas el middleware cuelga en localhost por algun motivo (DNS, resolución, etc.), el efecto es doble: sin sesion y sin respuesta.

---

## 5. Acciones realizadas / recomendadas

1. **next.config.ts:** Configurar `turbopack.root` para quitar el warning y estabilizar resolucion
2. **middleware.ts:** Añadir timeout y try/catch para que no quede colgado indefinidamente
3. **app/loading.tsx:** Añadir UI de carga para tener feedback mientras el middleware o la pagina cargan
4. **Lockfiles:** Eliminar `apps/management/bun.lock` si se usa solo el de la raiz
5. **Debug:** Abrir DevTools > Network y ver qué request queda pendiente (documento HTML, JS, etc.)

---

## 6. Verificacion manual

1. Abrir http://localhost:3001 en modo incognito
2. DevTools > Network > conservar log
3. Identificar la request que no completa
4. Si la request al documento HTML (/) nunca llega: el problema esta en el middleware
5. Si el HTML llega pero el contenido no: el problema esta en el cliente (React, CSS, etc.)
