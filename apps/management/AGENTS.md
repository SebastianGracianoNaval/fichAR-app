# fichar-management — Agent Guide

> **Backoffice web para fichAR. Crear organizaciones, gestionar clientes, administrar acceso.**

**Stack:** Next.js 16 (App Router), TypeScript, Tailwind, shadcn/ui, Framer Motion, Supabase Auth, React Hook Form + Zod.

---

## 1. Principios (heredados de fichAR)

Estos principios aplican. Consultar `AGENTS.md` raíz para detalles.

- **Security:** Auth, whitelist (`management_users`), defensa en profundidad. No exponer `MANAGEMENT_API_KEY` al cliente.
- **Velocity:** Carga rápida, feedback inmediato, lazy loading, paginación.
- **Optimization:** Caché, SWR/TanStack Query, Server Components donde aplique.
- **Integration:** Llamada a `POST /api/v1/management/organizations` vía Server Action o Route Handler. Comparte Supabase con fichar-app.
- **Personalization:** Panel configurable; futuros CFG-* si se requieren.

---

## 2. Stack Tecnológico

| Capa | Tecnología |
|------|------------|
| Framework | Next.js 16+ (App Router) |
| Lenguaje | TypeScript |
| Estilos | Tailwind CSS v4 |
| Componentes | shadcn/ui (new-york, zinc) |
| Animaciones | Framer Motion |
| Auth | Supabase Auth + tabla `management_users` |
| Formularios | React Hook Form + Zod + @hookform/resolvers |
| HTTP | fetch / SWR o TanStack Query |
| Deploy | Vercel |

---

## 3. Paleta y Estética

**Colores (verde + azul):**
- Primario: #0F766E (teal)
- Secundario: #0EA5E9 (azul)
- Acento: #10B981 (verde éxito)
- Fondo: #F8FAFC
- Texto: #0F172A
- Texto secundario: #64748B

**Look & Feel:** Bordes 8–12px, sombras sutiles, transiciones 200–300ms, skeletons para loading, empty states con CTA.

---

## 4. Estructura de Carpetas

```
apps/management/
├── app/(auth)/           # login, forgot-password, set-password
├── app/(dashboard)/      # layout, page, organizations
├── components/ui/        # shadcn
├── components/layout/    # Sidebar, header
├── components/features/  # login-form, org-table, etc.
├── lib/supabase/         # client.ts, server.ts
├── lib/api/              # management.ts
├── hooks/
├── types/
└── .env.local.example
```

Ver `plans/fichar-management-folder-structure.md` para detalles.

---

## 5. Skills y Cómo Elegirlas

Las skills están instaladas en `.agents/skills/` (vía `bunx skills add` desde [skills.sh](https://skills.sh/)).

### Skill Decision Table (fichar-management)

| Task | Skill principal | Ubicación | Secundarias |
|------|-----------------|-----------|-------------|
| Next.js, RSC, Route Handlers | management-nextjs-shadcn | .cursor/skills/ | next-best-practices, nextjs-app-router |
| shadcn/ui, forms, tables | management-nextjs-shadcn, shadcn-ui | .agents/skills/ | design-system-patterns |
| Supabase Auth, management_users | supabase-postgres-best-practices | .agents/skills/ | fichar-security |
| Auth Next.js (Supabase) | nextjs-authentication | .agents/skills/ | — |
| Data fetching, SWR, React Query | nextjs-data-fetching | .agents/skills/ | — |
| UI/UX, paleta, empty states | ui-ux-pro-max, frontend-design | .agents/skills/ | web-design-guidelines |
| Revisión UI, best practices | web-design-guidelines | .agents/skills/ | vercel-react-best-practices |
| React patterns, composition | vercel-react-best-practices, react-patterns | .agents/skills/ | vercel-composition-patterns |
| Tailwind, theming | tailwind-css-patterns | .agents/skills/ | — |
| Performance, caching | nextjs-performance, next-cache-components | .agents/skills/ | — |
| Deploy Vercel | nextjs-deployment | .agents/skills/ | — |
| Tests E2E web | webapp-testing | .agents/skills/ | e2e-testing-patterns |
| API design, management API | api-design-principles | .cursor/skills/ | — |
| Plan antes de implementar | skill-planning | .cursor/skills/ | — |

### Skills instaladas (`.agents/skills/`)

| Skill | Repo origen | Uso |
|-------|-------------|-----|
| next-best-practices | vercel-labs/next-skills | RSC, file conventions, data patterns |
| next-cache-components | vercel-labs/next-skills | PPR, use cache, cacheLife |
| next-upgrade | vercel-labs/next-skills | Migraciones Next.js |
| vercel-react-best-practices | vercel-labs/agent-skills | React perf, Vercel |
| vercel-composition-patterns | vercel-labs/agent-skills | Composición React |
| web-design-guidelines | vercel-labs/agent-skills | Revisión UI |
| supabase-postgres-best-practices | supabase/agent-skills | Postgres, RLS |
| frontend-design | anthropics/skills | Layouts, tipografía |
| webapp-testing | anthropics/skills | Tests web, Playwright |
| ui-ux-pro-max | nextlevelbuilder/ui-ux-pro-max-skill | Paletas, admin panels |
| shadcn-ui | giuseppe-trisciuoglio/developer-kit | Componentes shadcn |
| nextjs-app-router | giuseppe-trisciuoglio/developer-kit | App Router, routing |
| nextjs-authentication | giuseppe-trisciuoglio/developer-kit | Auth en Next.js |
| nextjs-data-fetching | giuseppe-trisciuoglio/developer-kit | Data fetching |
| nextjs-deployment | giuseppe-trisciuoglio/developer-kit | Deploy |
| nextjs-performance | giuseppe-trisciuoglio/developer-kit | Performance |
| tailwind-css-patterns | giuseppe-trisciuoglio/developer-kit | Tailwind |
| react-patterns | giuseppe-trisciuoglio/developer-kit | React |

### Skills del repo (`.cursor/skills/`)

| Skill | Uso |
|-------|-----|
| management-nextjs-shadcn | Contexto fichar-management, paleta, estructura |
| design-system-patterns | Tokens, theming |
| api-design-principles | REST, contracts |
| skill-planning | Planes antes de implementar |
| fichar-security | Auth, RLS (desde raíz) |

### Comandos para (re)instalar skills

```bash
cd /home/sebastiang/fichar-app
bunx skills add vercel-labs/next-skills -y
bunx skills add vercel-labs/agent-skills -y
bunx skills add supabase/agent-skills -y
bunx skills add anthropics/skills -y
bunx skills add nextlevelbuilder/ui-ux-pro-max-skill -y
bunx skills add giuseppe-trisciuoglio/developer-kit -y
```

---

## 6. Reglas de Código

- **Comentarios:** Mínimos. Solo lógica no obvia o reglas de negocio.
- **Sin emojis** en código, commits o logs.
- **Naming:** camelCase (TS/React). `verb_noun` para funciones si es legible.
- **Errores:** No tragar excepciones. Mensajes descriptivos. Validar en servidor.
- **`MANAGEMENT_API_KEY`:** Solo server-side (Server Actions, Route Handlers). Nunca en cliente.

---

## 7. Fuente de Verdad

| Documento | Contenido |
|-----------|-----------|
| `plans/fichar-management-full-plan.md` | Objetivo, pantallas, auth, UX contraseña |
| `plans/fichar-management-folder-structure.md` | Estructura, Supabase compartido, Vercel |
| `documentation/tecnica/management-api.md` | Contrato POST /management/organizations |
| `definiciones/SEGURIDAD.md` | Seguridad (heredada) |

---

## 8. Integración con fichar-app

- **API:** `NEXT_PUBLIC_FICHAR_API_URL` + `MANAGEMENT_API_KEY` (server).
- **Supabase:** `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
- **CORS:** La API debe incluir el origen de management en `CORS_ORIGINS`.

---

## 9. Comandos Útiles

```bash
# Dev
bun run management   # desde raíz
bun run dev          # desde apps/management

# Build
bun run build        # desde apps/management

# shadcn
bunx shadcn@latest add <component>
```

---

*Este AGENTS.md complementa el AGENTS.md raíz de fichar-app. Para principios generales, VOIS+P y auditorías, consultar el raíz.*
