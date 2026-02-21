# fichAR - Getting Started

Guía de configuración inicial del entorno de desarrollo.

## Requisitos previos

- Git
- Bun 1.0+ ([bun.sh](https://bun.sh))
- Flutter 3.x ([flutter.dev](https://flutter.dev))
- Cuenta en Supabase ([supabase.com](https://supabase.com))

## Estructura del repositorio

```
fichar-app/
├── apps/           Aplicaciones Flutter (mobile, web)
├── packages/       Código compartido (api, shared)
├── supabase/       Migraciones y config
└── documentation/  Documentación oficial
```

## Setup inicial

### 1. Clonar e instalar dependencias

```bash
git clone <repo-url>
cd fichar-app
bun install
```

### 2. Variables de entorno

Crear `.env` en la raíz (no commiteado). Usar `.env.example` como plantilla cuando exista.

```bash
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=   # Para la API (auth, register-org, etc.)
```

### 3. Supabase

Crear proyecto en Supabase. Configurar URL y anon key en `.env`.

Para desarrollo local con Supabase CLI:

```bash
supabase init
supabase start
```

### 4. Desarrollo

| Comando | Descripcion |
|---------|-------------|
| `bun run dev` | Levanta API (Bun) |
| `bun run mobile` | Levanta Flutter (dispositivo/emulador) |
| `bun run mobile:web` | Levanta Flutter en Chrome |
| `bun run test` | Tests API |
| `bun run test:api` | Solo tests API |
| `bun run test:mobile` | Solo tests Flutter |
| `bun run lint` | Biome lint |
| `bun run format` | Biome format |

Al iniciar API o mobile se muestra el banner de fichAR en terminal.

## Siguientes pasos

Revisar la documentación técnica en `documentation/tecnica/` según vaya estando disponible.
