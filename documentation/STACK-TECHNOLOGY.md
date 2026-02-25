# fichAR — Stack tecnológico y estructura del proyecto

Documento de referencia con tecnologías, lenguajes, librerías y estructura de carpetas de **fichar-app** (monorepo) y **fichar-management** (app dentro del monorepo).

---

## 1. Visión general del monorepo

| Componente | Descripción |
|------------|-------------|
| **fichar-app** | Monorepo raíz. Gestión de dependencias con **Bun** (workspaces: `packages/*`). |
| **packages/api** | API REST (Bun runtime). Backend principal para fichajes, auth, empleados, legal, management, integraciones. |
| **packages/shared** | Código compartido entre API y otros paquetes (tipos, constantes, banner). |
| **apps/mobile** | Aplicación Flutter (iOS, Android, Web). Cliente empleados/supervisores/admin. |
| **apps/management** | Backoffice Next.js 16. Creación de organizaciones, gestión de clientes, login management. |
| **supabase** | Migraciones SQL, esquema PostgreSQL, RLS. Auth y base de datos. |

---

## 2. Lenguajes de programación

| Lenguaje | Uso |
|----------|-----|
| **TypeScript** | API (`packages/api`), management (`apps/management`), shared (`packages/shared`). |
| **Dart** | App móvil Flutter (`apps/mobile`). |
| **SQL** | Migraciones Supabase, scripts ad-hoc (`supabase/migrations/`, `scripts/*.sql`). |
| **CSS** | Estilos management: Tailwind v4, variables CSS, shadcn. |
| **JSON** | Configuración (package.json, components.json, etc.). |

---

## 3. Runtime y herramientas de desarrollo

| Herramienta | Versión / Uso |
|-------------|----------------|
| **Bun** | Runtime y package manager para Node/TS. Ejecuta la API y scripts. |
| **Node.js** | Implícito en Next.js (management). Next dev/build usa Node. |
| **Flutter** | SDK para apps/mobile. Dart 3.11+. |
| **npm/bun** | Instalación de dependencias: `bun install` en raíz y en cada app. |

---

## 4. Stack por aplicación

### 4.1 Backend: packages/api (@fichar/api)

| Categoría | Tecnología |
|-----------|------------|
| **Runtime** | Bun |
| **Lenguaje** | TypeScript (ESM, `"type": "module"`) |
| **Servidor HTTP** | `Bun.serve()` (fetch API nativa) |
| **Base de datos / Auth** | Supabase (PostgreSQL + Auth) |
| **Cliente DB** | `@supabase/supabase-js` (service role + anon) |
| **Rate limiting** | `@upstash/redis` (Redis); fallback in-memory |
| **JWT / crypto** | `jose` (SignJWT, jwtVerify, decodeJwt) |
| **Variables de entorno** | `dotenv` (load-env.ts) |
| **Email** | `nodemailer`, `resend` (email-service.ts) |
| **Export Excel/CSV** | `xlsx`, `jszip` (legal-export, reportes) |
| **Tests** | Bun test (runner nativo) |

**Estructura típica de la API:**

- `src/index.ts`: entrada, CORS, security headers, compresión gzip, enrutado.
- `src/routes.ts`: definición de rutas (exact/dynamic) y `matchRoute`.
- `src/routes/*.ts`: handlers por dominio (auth, fichajes, employees, legal, management, integrations, etc.).
- `src/lib/*.ts`: middleware (auth, rate-limit), validadores, logger, Supabase client, org-config, errores.
- `src/services/*.ts`: lógica de negocio (fichaje-hash, fichaje-rules, webhook-dispatch).

**Versión de API:** `API_VERSION` desde `@fichar/shared`. Rutas bajo `/api/v1/...`.

---

### 4.2 Shared: packages/shared (@fichar/shared)

| Contenido | Archivos |
|-----------|----------|
| **Tipos** | `types/index.ts` (Role, EmployeeStatus, etc.) |
| **Constantes** | `constants/roles.ts` (VALID_ROLES), `constants/index.ts` |
| **Utilidad** | `banner.ts` (printBanner para consola API) |
| **Export** | `index.ts` reexporta types, constants, banner |

Sin dependencias externas. Consumido por `@fichar/api` (workspace).

---

### 4.3 Mobile: apps/mobile (fichar_mobile)

| Categoría | Tecnología |
|-----------|------------|
| **Framework** | Flutter (SDK) |
| **Lenguaje** | Dart 3.11+ |
| **Auth / sesión** | `supabase_flutter` (sesión después de login vía API) |
| **HTTP** | `http` (paquete oficial). Cliente centralizado en `ApiClient`. |
| **Env** | `flutter_dotenv` (assets/.env) |
| **UI** | Material 3, `google_fonts`, `flutter_svg`, `cupertino_icons` |
| **Utilidades** | `path_provider`, `share_plus`, `file_picker`, `device_info_plus` |
| **Desarrollo** | `device_preview` |
| **Tests** | `flutter_test`, `shared_preferences` (dev), `flutter_lints` |

**Login:** La app no usa Supabase Auth directo para login; llama `POST /api/v1/auth/login` (AuthApiService), luego establece sesión con `Supabase.instance.client.auth.setSession(refreshToken)`.

**Temas:** `lib/theme.dart` — Material 3, paleta teal/azul (definiciones/FRONTEND.md), tokens de spacing/radius/animación.

---

### 4.4 Management: apps/management

| Categoría | Tecnología |
|-----------|------------|
| **Framework** | Next.js 16.1.6 (App Router) |
| **Lenguaje** | TypeScript |
| **React** | React 19.2.3 |
| **Estilos** | Tailwind CSS v4, `tw-animate-css`, shadcn (new-york, zinc) |
| **Componentes UI** | shadcn/ui (Radix primitives), `lucide-react`, `class-variance-authority`, `clsx`, `tailwind-merge` |
| **Formularios** | `react-hook-form`, `@hookform/resolvers`, **Zod 4** |
| **Auth** | `@supabase/ssr`, `@supabase/supabase-js` (Supabase Auth + cookies) |
| **HTTP** | `fetch` (lib/api/management.ts) hacia API fichar (`NEXT_PUBLIC_FICHAR_API_URL` + `MANAGEMENT_API_KEY`) |
| **Fuentes** | `next/font`: Geist, Geist_Mono |
| **Notificaciones** | `sonner` |
| **Temas** | `next-themes` |
| **Animaciones** | `framer-motion` |
| **Build** | Turbopack (root monorepo), React Compiler (`reactCompiler: true`) |
| **Tests** | Jest 30, `@testing-library/react`, `@testing-library/jest-dom`, `@testing-library/user-event` |
| **Lint** | ESLint 9, `eslint-config-next` |

**Rutas principales:** App Router: `app/(auth)/` (login, forgot-password, set-password), `app/(dashboard)/` (page, organizations, organizations/[id]).

---

## 5. Base de datos y auth (Supabase)

| Componente | Uso |
|-------------|-----|
| **PostgreSQL** | Base de datos principal. Esquema vía migraciones en `supabase/migrations/`. |
| **Supabase Auth** | Usuarios (auth.users). Employees vinculados por `auth_user_id`. Management: tabla `management_users`. |
| **RLS** | Row Level Security en tablas con `org_id` (organizations, employees, fichajes, places, branches, org_configs, audit_logs, webhooks, solicitudes_licencia, licencia_adjuntos, alertas, management_users, integration_api_keys). |
| **Migraciones** | Nombres `YYYYMMDDHHMMSS_descripcion.sql`. Orden aplicado por número. |

**Tablas principales (referencia):**

- organizations, employees, branches, places, employee_places
- fichajes (inmutables, cadena de hashes)
- org_configs, audit_logs
- solicitudes_licencia, licencia_adjuntos, alertas
- webhooks, management_users, integration_api_keys

---

## 6. Librerías detalladas por paquete

### 6.1 Raíz (package.json)

| Dependencia | Tipo | Uso |
|-------------|------|-----|
| @biomejs/biome | dev | Lint y formato (JS/TS). |
| @supabase/supabase-js | dev | Referencia/scripts. |
| @types/bun | dev | Tipos Bun. |
| supabase | dev | CLI Supabase (migraciones, local). |

Workspaces: `["packages/*"]`. Scripts: `management`, `dev`, `start`, `test`, `test:api`, `test:mobile`, `lint`, `format`, `mobile`, `mobile:web`, `seed:test-admin`.

### 6.2 packages/api

| Dependencia | Uso |
|-------------|-----|
| @fichar/shared | workspace | Versión API, roles, tipos. |
| @supabase/supabase-js | Cliente Supabase (admin + anon). |
| @upstash/redis | Rate limit login (opcional; fallback in-memory). |
| dotenv | Carga .env desde raíz. |
| jose | JWT (invites, decode). |
| jszip | Export legal (ZIP). |
| nodemailer | Envío de emails (fallback). |
| resend | Envío de emails (preferido). |
| xlsx | Export Excel (legal, reportes). |

### 6.3 packages/shared

Sin dependencias externas.

### 6.4 apps/management

| Dependencia | Uso |
|-------------|-----|
| next | Framework. |
| react, react-dom | UI. |
| @supabase/ssr | Supabase en Server Components / cookies. |
| @supabase/supabase-js | Cliente Supabase. |
| react-hook-form, @hookform/resolvers, zod | Formularios y validación. |
| class-variance-authority, clsx, tailwind-merge | Clases CSS. |
| framer-motion | Animaciones. |
| lucide-react | Iconos. |
| radix-ui | Primitivas (shadcn). |
| sonner | Toasts. |
| next-themes | Tema claro/oscuro. |

Dev: tailwindcss v4, @tailwindcss/postcss, typescript, eslint, jest, @testing-library/*, babel-plugin-react-compiler, shadcn.

### 6.5 apps/mobile (pubspec.yaml)

| Dependencia | Uso |
|-------------|-----|
| flutter | SDK. |
| cupertino_icons | Iconos iOS-style. |
| supabase_flutter | Sesión y auth después del login vía API. |
| flutter_dotenv | Variables de entorno. |
| http | Peticiones HTTP. |
| flutter_svg | SVG. |
| path_provider | Rutas de sistema. |
| share_plus | Compartir. |
| file_picker | Selección de archivos. |
| device_info_plus | Info del dispositivo. |
| google_fonts | Fuentes. |
| device_preview | Preview multi-dispositivo. |

---

## 7. Estructura de carpetas

### 7.1 Raíz del monorepo

```
fichar-app/
├── AGENTS.md                 # Guía orquestador / agentes
├── package.json              # Workspaces, scripts
├── biome.json                # Lint y formato
├── .env                      # Variables (no commitear)
├── apps/
│   ├── management/           # Next.js backoffice
│   └── mobile/               # Flutter app
├── packages/
│   ├── api/                  # API Bun
│   └── shared/               # Tipos y constantes
├── supabase/
│   └── migrations/           # SQL
├── scripts/                  # Scripts TS y SQL
├── documentation/            # Docs técnicos y manuales
├── plans/                    # Planes de producto/tech
├── audits/                   # Informes de auditoría (gitignored)
└── definiciones/             # Definiciones producto (referenciadas en AGENTS.md)
```

### 7.2 packages/api

```
packages/api/
├── package.json
├── src/
│   ├── index.ts              # Entrada HTTP, CORS, gzip, security headers
│   ├── load-env.ts           # Carga .env
│   ├── routes.ts             # Definición de rutas
│   ├── routes/
│   │   ├── auth.ts           # Login, register, MFA, change-password
│   │   ├── me.ts             # GET /me, devices, revoke
│   │   ├── fichajes.ts
│   │   ├── employees.ts
│   │   ├── branches.ts
│   │   ├── places.ts
│   │   ├── org-configs.ts
│   │   ├── webhooks.ts
│   │   ├── integration-keys.ts
│   │   ├── integrations.ts   # Gateway integraciones (fichajes, empleados)
│   │   ├── legal.ts
│   │   ├── licencias.ts
│   │   ├── alertas.ts
│   │   ├── banco.ts
│   │   ├── reportes.ts
│   │   ├── dashboard.ts
│   │   └── management.ts     # Management auth, orgs
│   ├── services/
│   │   ├── fichaje-hash.ts
│   │   ├── fichaje-rules.ts
│   │   └── webhook-dispatch.ts
│   └── lib/
│       ├── supabase.ts
│       ├── auth-middleware.ts
│       ├── management-auth.ts
│       ├── legal-auth-middleware.ts
│       ├── rate-limit.ts
│       ├── logger.ts
│       ├── errors.ts
│       ├── validators.ts
│       ├── org-config.ts
│       ├── org-config-cache.ts
│       ├── org-config-whitelist.ts
│       ├── require-admin.ts
│       ├── password-generator.ts
│       ├── email-service.ts
│       ├── geo.ts
│       ├── geocoding.ts
│       ├── legal-export.ts
│       ├── integration-auth.ts
│       ├── integration-rate-limit.ts
│       └── load-env.ts
```

### 7.3 packages/shared

```
packages/shared/
├── package.json
├── index.ts
├── types/
│   └── index.ts
├── constants/
│   ├── roles.ts
│   └── index.ts
└── banner.ts
```

### 7.4 apps/management

```
apps/management/
├── package.json
├── next.config.ts
├── tsconfig.json
├── components.json            # shadcn
├── app/
│   ├── layout.tsx
│   ├── loading.tsx
│   ├── globals.css
│   ├── (auth)/
│   │   ├── layout.tsx
│   │   ├── login/page.tsx
│   │   ├── forgot-password/page.tsx
│   │   └── set-password/page.tsx
│   └── (dashboard)/
│       ├── layout.tsx
│       ├── page.tsx
│       ├── actions.ts
│       └── organizations/
│           ├── page.tsx
│           ├── loading.tsx
│           ├── error.tsx
│           ├── actions.ts
│           └── [id]/
│               ├── page.tsx
│               ├── loading.tsx
│               └── error.tsx
├── components/
│   ├── ui/                    # shadcn: button, input, form, table, card, dialog, label, sonner
│   └── features/
│       ├── auth/              # login-form, auth-guard, logout-button, forgot-password, set-password
│       └── organizations/     # create-org-dialog
├── lib/
│   ├── supabase/
│   │   ├── client.ts
│   │   ├── server.ts
│   │   └── proxy.ts
│   ├── api/
│   │   └── management.ts      # createOrganization, getStats, getOrganizations, getOrganizationById
│   ├── utils.ts
│   └── validations/
│       ├── auth.ts
│       ├── password.ts
│       └── organization.ts
├── hooks/
│   └── use-auth.ts
├── types/
│   └── index.ts
└── proxy.ts
```

### 7.5 apps/mobile

```
apps/mobile/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── theme.dart
│   ├── theme/
│   │   └── layout_tokens.dart
│   ├── core/
│   │   ├── api_client.dart
│   │   ├── device_capabilities.dart
│   │   ├── offline_queue.dart
│   │   └── places_cache.dart
│   ├── services/
│   │   ├── auth_api_service.dart
│   │   ├── me_api_service.dart
│   │   ├── fichajes_api_service.dart
│   │   ├── employees_api_service.dart
│   │   ├── places_api_service.dart
│   │   ├── org_configs_api_service.dart
│   │   ├── licencias_api_service.dart
│   │   ├── legal_api_service.dart
│   │   └── dashboard_api_service.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── forgot_password_screen.dart
│   │   ├── reset_password_screen.dart
│   │   ├── change_password_screen.dart
│   │   ├── mfa_enroll_screen.dart
│   │   ├── mfa_verify_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── perfil_screen.dart
│   │   ├── mis_horas_screen.dart
│   │   ├── reportes_screen.dart
│   │   ├── equipo_screen.dart
│   │   ├── licencias_screen.dart
│   │   ├── licencias_aprobar_screen.dart
│   │   ├── alertas_screen.dart
│   │   ├── admin_empleados_screen.dart
│   │   ├── admin_lugares_screen.dart
│   │   ├── admin_config_screen.dart
│   │   ├── legal_audit_*.dart (shell, dashboard, logs, hash chain)
│   │   └── ...
│   ├── widgets/
│   │   ├── auth_home_resolver.dart
│   │   ├── fichar_button.dart
│   │   ├── inline_error.dart
│   │   ├── screen_error_view.dart
│   │   └── responsive_content_wrapper.dart
│   └── utils/
│       ├── error_utils.dart
│       ├── device_utils.dart
│       ├── device_utils_io.dart
│       ├── device_utils_stub.dart
│       ├── export_helper.dart
│       ├── export_helper_io.dart
│       └── export_helper_stub.dart
├── assets/
│   ├── .env
│   └── env.example
└── test/
```

### 7.6 supabase

```
supabase/
└── migrations/
    ├── 20260220000001_create_organizations.sql
    ├── 20260220000002_create_employees.sql
    ├── 20260220000003_create_org_configs.sql
    ├── 20260220000004_create_audit_logs.sql
    ├── 20260220100005_create_branches.sql
    ├── 20260220100006_create_places.sql
    ├── 20260220100007_create_employee_places.sql
    ├── 20260220100008_create_fichajes.sql
    ├── 20260220100009_seed_logs_retencion_dias.sql
    ├── 20260221100001_phase3_employees_columns.sql
    ├── 20260221110001_phase4_licencias_alertas.sql
    ├── 20260221120001_fix_licencia_adjuntos_rls.sql
    ├── 20260221130001_add_password_changed_at.sql
    ├── 20260221140001_seed_descanso_minimo_horas.sql
    ├── 20260221150001_seed_org_configs_priority.sql
    ├── 20260221160001_create_webhooks.sql
    ├── 20260221170001_add_performance_indexes.sql
    ├── 20260222120000_rename_legal_auditor_to_integrity_viewer.sql
    ├── 20260222130000_create_management_users.sql
    ├── 20260223120000_fix_set_updated_at_search_path.sql
    └── 20260224120000_create_integration_api_keys.sql
```

---

## 8. API REST (resumen de rutas)

Base: `/api/v1`. Autenticación: header `Authorization: Bearer <token>` (JWT Supabase), excepto login, register, forgot-password y management auth.

| Grupo | Método | Ruta | Descripción |
|-------|--------|------|-------------|
| Auth | POST | /auth/register-org | Registro de organización (si habilitado) |
| Auth | POST | /auth/register | Registro con invite token |
| Auth | POST | /auth/login | Login empleados (rate limit) |
| Auth | POST | /auth/forgot-password | Recuperación de contraseña |
| Auth | POST | /auth/invite | Crear invitación (Admin) |
| Auth | GET | /me | Perfil del usuario autenticado |
| Auth | GET | /me/devices | Dispositivos de sesión |
| Auth | POST | /me/devices/:id/revoke | Revocar dispositivo |
| Auth | POST | /auth/mfa/verify | Verificar código MFA |
| Auth | POST | /auth/mfa/enroll | Iniciar enrolamiento MFA |
| Auth | POST | /auth/mfa/enroll-verify | Confirmar enrolamiento MFA |
| Auth | POST | /auth/change-password | Cambiar contraseña |
| Auth | POST | /auth/password-set-complete | Marcar contraseña establecida |
| Fichajes | POST | /fichajes/batch | Alta batch de fichajes |
| Fichajes | POST | /fichajes | Alta de fichaje |
| Fichajes | GET | /fichajes | Listado de fichajes (paginado) |
| Employees | GET | /employees | Listado |
| Employees | POST | /employees/import | Importación |
| Employees | GET | /employees/:id | Detalle |
| Employees | PATCH | /employees/:id | Actualizar |
| Employees | POST | /employees/:id/offboard | Baja |
| Branches | GET/POST/PATCH/DELETE | /branches, /branches/:id | Sucursales |
| Legal | GET | /legal/fichajes, /legal/audit-logs, /legal/hash-chain, /legal/licencias | Auditoría legal |
| Legal | POST | /legal/export | Export (CSV/XLSX/ZIP) |
| Licencias | GET | /licencias, /licencias/pendientes | Listados |
| Licencias | POST | /licencias, /licencias/:id/aprobar, /licencias/:id/rechazar | Alta y aprobación |
| Places | GET/POST/PATCH/DELETE | /places, /places/import, /places/:id | Lugares de trabajo |
| Org configs | GET/PATCH | /org-configs | Configuración por organización (Admin) |
| Webhooks | GET/POST/PATCH/DELETE | /webhooks, /webhooks/:id | Webhooks (Admin) |
| Integration keys | POST/GET/PATCH/DELETE | /integration-keys, /integration-keys/:id | Claves API integraciones |
| Integrations | GET | /integrations/fichajes, /integrations/empleados | Gateway con API key |
| Management | POST | /management/auth/login | Login management (API key o Supabase) |
| Management | GET | /management/stats | Estadísticas |
| Management | GET | /management/organizations | Listado de organizaciones |
| Management | GET | /management/organizations/:id | Detalle organización |
| Management | POST | /management/organizations | Crear organización |
| Admin | GET | /admin/dashboard | Dashboard admin |
| Alertas / Banco | GET | /alertas, /banco, /banco/equipo | Alertas y banco de horas |
| Reportes | POST | /reportes/export | Export reportes |

---

## 9. Configuración y convenciones

| Aspecto | Detalle |
|---------|---------|
| **Lint / formato** | Biome (raíz): formatter 2 espacios, lineWidth 100, single quotes. Incluye todo el repo salvo node_modules, build, .dart_tool. |
| **Mobile lint** | `flutter_lints` en analysis_options.yaml. |
| **Management lint** | ESLint + eslint-config-next. |
| **Tipos** | TypeScript strict en api y management. Dart 3.11 en mobile. |
| **Naming** | Backend/DB: snake_case. TypeScript/Dart: camelCase. |
| **Env** | Raíz: `.env`. Mobile: `assets/.env` (flutter_dotenv). Management: `.env.local` (Next.js). |

---

## 10. Documentación relacionada

| Documento | Contenido |
|------------|-----------|
| AGENTS.md | Principios, skills, VOIS+P, stack, reglas de código. |
| documentation/tecnica/supabase-setup.md | Configuración Supabase. |
| documentation/tecnica/management-api.md | Contrato API management. |
| documentation/tecnica/integration-api.md | API de integraciones. |
| documentation/tecnica/getting-started.md | Puesta en marcha. |
| definiciones/*.md | Definiciones de producto (referenciadas en AGENTS.md; pueden vivir en otro repo o path). |

---

*Última actualización: 2025-02-23. Refleja el estado del repositorio en la fecha indicada.*
