# Prompt V2: Configurar Sistema de Skills, Agente Orquestador y Subagents para Cursor

Copia y pega este prompt completo en Cursor para configurar:

- Un **agente orquestador** (AGENTS.md) con skills y flujo plan → revisar → implementar.
- **Skills** por tecnología y una **skill de planificación** sencilla.
- **Subagents** (reglas `.mdc` en `.cursor/rules/`) para backend, frontend, planificador y testing, creados según el análisis del proyecto.

---

## Best practices (Agent Skills y Cursor Rules)

Al crear o modificar skills y reglas, aplicar:

**Agent Skills (estándar [Agent Skills](https://agentskills.io)):**

- **Frontmatter**: `name` (máx. 64 caracteres; solo minúsculas, números, guiones; sin tags XML; sin palabras reservadas como "anthropic"/"claude"). `description` (no vacía; máx. 1024; sin tags XML): debe indicar **qué hace** y **cuándo se activa**.
- **Descripciones**: En **tercera persona**; específicas; incluir términos disparadores (ej. "PDF", "TypeScript types").
- **Naming**: Estilo consistente; se recomienda **gerundio** (creating, syncing, organizing).
- **Progressive disclosure**: SKILL.md como overview; cuerpo **&lt; 500 líneas**; detalles en assets/references; referencias a un nivel desde SKILL.md; en archivos largos (&gt; 100 líneas), tabla de contenidos al inicio.
- **Contenido**: Evitar información sensible al tiempo; terminología consistente. No usar paths con backslashes; usar **forward slashes** (`/`).
- **Evaluación**: Definir ≥3 casos que reflejen fallas reales; probar con los modelos objetivo.

**Cursor Rules (.mdc en `.cursor/rules/`):**

- Formato **.mdc**: YAML frontmatter (`description`, `globs`, `alwaysApply`) + cuerpo en Markdown.
- **globs**: Patrones de archivo para aplicar la regla cuando coincidan (ej. `backend/**/*.ts`, `frontend/**/*.tsx`). Usar forward slashes.
- **alwaysApply**: `false` para reglas por contexto o manuales; `true` solo si debe aplicarse en toda la sesión.
- Reglas concisas; una preocupación principal por regla; &lt; 500 líneas.

**Flujo recomendado (Cursor):**

- **Plan before code**: Para implementaciones no triviales, generar primero un plan (documento .md) antes de escribir código; revisar el plan con criterio estricto (solo pulir cuando algo está mal o falta); luego implementar según el plan.
- **Contexto bajo demanda**: No cargar todos los skills a la vez; orquestador + un skill o subagente (regla) que apunte a 1–3 skills reduce tokens.

---

## Instrucciones para la IA

Eres un agente orquestador experto en configurar sistemas de Skills y Subagents para Cursor. Tu tarea es **analizar el proyecto actual** y crear:

1. Infraestructura de **Skills** siguiendo el estándar Agent Skills y las best practices anteriores.
2. **AGENTS.md** como orquestador, con sección de **Subagents** y flujo **plan → revisar → implementar** (plan en inglés antes de ejecutar cambios complejos).
3. **Skill de planificación** sencilla, además de skill-creator y skill-sync.
4. **Subagents** como reglas en `.cursor/rules/`: Backend, Frontend, Change Planner, Test Creator; cada una con nombre, descripción, globs y contenido según el análisis del proyecto.

**Requisito obligatorio:** Crear skills para **todas las tecnologías utilizadas en el proyecto** (lenguajes, frameworks, librerías principales, build y testing). Ninguna tecnología del stack debe quedar sin skill asociada.

---

### FASE 1: Análisis del Proyecto

**ANTES de crear cualquier archivo:**

1. **Explorar la estructura del proyecto:**
   - Stack tecnológico (lenguajes, frameworks, librerías).
   - Arquitectura (monorepo, microservicios, monolito).
   - Componentes principales y organización (ej. `backend/`, `frontend/`, `shared/`).
   - Archivos de configuración clave (package.json, pyproject.toml, requirements.txt, etc.).
   - README.md si existe.
   - Convenciones de código existentes.

2. **Identificar patrones y convenciones:**
   - Estilos de código (linters, formatters).
   - Estructura de carpetas.
   - Convenciones de naming.
   - Flujos de trabajo (testing, CI/CD).
   - Frameworks y librerías específicas del proyecto.

3. **Documentar hallazgos:**
   - Resumen del proyecto (tecnologías, arquitectura, propósito).
   - Lista de **todas** las tecnologías principales del stack; cada una tendrá una skill en FASE 5.
   - Identificar áreas que requieren skills personalizados (API, UI, tests, export, etc.).
   - Identificar **rutas típicas** para subagents: dónde está el backend, el frontend, los tests (ej. `backend/`, `frontend/`, `backend/src/__tests__/`, `frontend/src/**/*.test.tsx`).

---

### FASE 2: Estructura Base

Crear la siguiente estructura:

```
{project-root}/
├── AGENTS.md
└── .cursor/
    ├── rules/                    # Subagents (reglas .mdc)
    │   ├── backend-developer.mdc
    │   ├── frontend-developer.mdc
    │   ├── change-planner.mdc
    │   └── test-creator.mdc
    └── skills/
        ├── README.md
        ├── skill-creator/
        │   ├── SKILL.md
        │   └── assets/
        │       └── SKILL-TEMPLATE.md
        ├── skill-sync/
        │   ├── SKILL.md
        │   └── assets/
        │       └── sync.sh
        ├── skill-planning/        # Skill de planificación sencilla
        │   └── SKILL.md
        └── {skill-personalizado-1}/
            └── SKILL.md
```

---

### FASE 3: AGENTS.md (Orquestador)

Crear `AGENTS.md` en la raíz con esta estructura (adaptar placeholders al análisis):

```markdown
# Repository Guidelines

## How to Use This Guide

- Este archivo actúa como README para agentes de IA.
- Proporciona contexto del proyecto y guía el comportamiento del agente orquestador.
- Cada componente puede tener su propio AGENTS.md si el proyecto es grande.

## Orchestrator, Skills and Subagents (optimización de carga)

### Roles

| Capa | Ubicación | Función | Cuándo se carga |
|------|-----------|---------|------------------|
| **Orchestrator** | Este archivo (AGENTS.md) | Define proyecto, tech stack, cuándo usar cada skill/subagent y convenciones globales. | Siempre (o como regla de proyecto). |
| **Skills** | `.cursor/skills/*/SKILL.md` | Instrucciones detalladas por dominio. | Solo cuando la tarea lo requiera: orquestador o subagente indican "lee skill X". |
| **Subagents** | `.cursor/rules/*.mdc` | Reglas que acotan el alcance y listan los skills a leer. | Por contexto (archivos abiertos → globs) o por selección manual. |

### Flujo de uso (resumido)

1. **Tarea general** (pregunta, documentación, bug que toca varias partes): Orquestador usa la tabla "Auto-invoke Skills" y lee solo el skill que toque (uno o dos). No cargar todos los skills.
2. **Tarea acotada** (solo backend / solo frontend / solo plan / solo tests): Activar un subagente (regla en `.cursor/rules/`): abrir archivos de esa área para que Cursor aplique la regla por glob, o elegir la regla a mano. La regla indica "lee AGENTS.md + estos 1–3 skills". Solo se cargan esos.
3. **Resumen:** Orquestador = siempre; Skills = bajo demanda; Subagente = opcional para acotar y cargar solo los skills que tocan.

### Flujo plan → revisar → implementar

Para **implementaciones no triviales** (features, cambios transversales):

1. **Planificar:** Usar primero el subagente **Change Planner**. Genera un plan en un archivo **.md en inglés** en la carpeta **`docs/`** (puede estar en .gitignore; artefactos locales). El plan incluye: contexto de negocio, áreas afectadas, dependencias, skills a invocar, buenas prácticas, riesgos/edge cases, checklist.
2. **Revisar el plan:** Antes de implementar, el orquestador o el subagente que vaya a implementar (Backend/Frontend) debe leer el plan y decidir si hay que **pulirlo**. Criterio estricto: **solo proponer cambios o pulir cuando algo está claramente mal o falta por aclarar**; no pulir por gusto.
3. **Implementar:** Orquestador o subagente Backend/Frontend usa el plan .md como especificación y ejecuta según el checklist.

**Convención de planes:** Guardar en `docs/` con nombre descriptivo (ej. `docs/plan-<feature>.md` o `docs/plans/<nombre>.md`). El artefacto (.md) del Change Planner se escribe **siempre en inglés**; la conversación con el usuario puede ser en otro idioma.

### Cuándo delegar en un subagente (regla)

- **Antes de implementar una feature o cambio complejo** → Usar primero el subagente **Change Planner** para generar el plan .md en inglés en `docs/`.
- **Tarea compleja o acotada en backend** → Regla **Backend Developer** (o abrir archivos del backend para que aplique por glob).
- **Tarea compleja o acotada en frontend** → Regla **Frontend Developer** (o abrir archivos del frontend).
- **Necesidad de un plan antes de implementar** → Regla **Change Planner**. No escribe código; solo produce plan .md (en inglés) y checklist.
- **Crear o revisar tests** → Regla **Test Creator**.

### Tabla rápida: Subagent → Skills que usa

| Subagent (regla en `.cursor/rules/`) | Skills a cargar (solo estos cuando actúes) |
|--------------------------------------|--------------------------------------------|
| Backend Developer | {Listar skills de API/backend del proyecto; si hay Prisma/schema, typescript; si webhooks/auth, security; si export, export-formats} |
| Frontend Developer | {Listar skills de UI/React del proyecto; si diseño, plan de diseño; si tipos/API, typescript} |
| Change Planner | Ninguno obligatorio; en el plan indicar qué skills debe invocar quien implemente. **Salida:** plan .md en inglés en `docs/`. |
| Test Creator | {Skills de test-backend y/o test-frontend; si código bajo test es API/Prisma, skill api; si componente/hook, skill react} |

### Optimización de carga

- No cargar todos los skills a la vez. Leer solo el skill (o la regla) relevante para la acción actual.
- Preferir una regla (subagente) cuando la tarea es clara: backend-only, frontend-only, solo plan, solo tests.
- Orquestador ligero: en conversaciones genéricas, AGENTS.md + un solo skill (o ninguno). En tareas complejas, sugerir usar la regla correspondiente.

## Project Overview

{Resumen del proyecto: propósito, stack, arquitectura, componentes principales}

## Tech Stack

| Component | Location | Tech Stack |
|-----------|----------|------------|
{Tabla con componentes y tecnologías}

## Available Skills

### Generic Skills (Any Project)
{Lista de skills genéricos}

### Project-Specific Skills
{Lista de skills específicos del proyecto}

### Meta Skills

| Skill | Description | URL |
|-------|-------------|-----|
| `skill-creator` | Create new AI agent skills | [SKILL.md](.cursor/skills/skill-creator/SKILL.md) |
| `skill-sync` | Sync skill metadata to AGENTS.md | [SKILL.md](.cursor/skills/skill-sync/SKILL.md) |
| `skill-planning` | Simple planning: produce .md plan in English before implementation | [SKILL.md](.cursor/skills/skill-planning/SKILL.md) |

## Auto-invoke Skills

When performing these actions, ALWAYS invoke the corresponding skill FIRST:

| Action | Skill |
|--------|-------|
{Tabla generada por skill-sync según metadata.auto_invoke}

## Development Guidelines

### Code Quality
{Convenciones de código}

### Testing
{Convenciones de testing}

### Git Workflow
{Convenciones de commits, branches, PRs si existen}

## Commands

```bash
{Comandos comunes del proyecto}
```

## References

- Subagents (reglas): `.cursor/rules/` — backend-developer.mdc, frontend-developer.mdc, change-planner.mdc, test-creator.mdc.
{Otros enlaces relevantes}
```

**IMPORTANTE:**

- Mantener AGENTS.md entre 250–500 líneas máximo (ajustar si el proyecto es muy grande; priorizar concisión).
- Incluir solo información crítica; apuntar a documentación detallada en lugar de duplicar.

---

### FASE 4: Meta Skills y Skill de Planificación

#### 4.1 Skill: skill-creator

Crear `.cursor/skills/skill-creator/SKILL.md` según el original (estructura, frontmatter, When to Create, Skill Structure, SKILL.md Template, Naming Conventions, Frontmatter Fields, Content Guidelines, Checklist). Incluir `assets/SKILL-TEMPLATE.md`.

#### 4.2 Skill: skill-sync

Crear `.cursor/skills/skill-sync/SKILL.md` según el original (Purpose, Required Skill Metadata, Scope Values, Usage, Commands, Checklist). Crear `assets/sync.sh` (o equivalente en Node si el proyecto no usa bash) que lea `.cursor/skills/*/SKILL.md`, extraiga `metadata.scope` y `metadata.auto_invoke`, y actualice la sección Auto-invoke en AGENTS.md. Soportar `--dry-run` y `--scope {scope}` si es posible.

#### 4.3 Skill: skill-planning (planificación sencilla)

Crear `.cursor/skills/skill-planning/SKILL.md`:

```markdown
---
name: skill-planning
description: >
  Produces a short implementation plan as a .md file in English before coding.
  Trigger: When user or orchestrator requests a plan before implementing a feature or non-trivial change.
license: Apache-2.0
metadata:
  author: {project-name}
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Before implementing a non-trivial feature or cross-cutting change"
    - "When user asks for a plan or checklist before coding"
allowed-tools: Read, Edit, Write, Glob, Grep
---

## When to Use

Use this skill when:
- The user or orchestrator wants a **plan first** (plan → review → implement flow).
- A feature or change is non-trivial (touches multiple areas, new endpoints, schema changes, etc.).
- The user explicitly asks for a plan, analysis, or checklist before implementation.

## Output

- **Location:** Save the plan in `docs/` with a descriptive name (e.g. `docs/plan-<feature>.md` or `docs/plans/<name>.md`). Use forward slashes.
- **Language:** The **content of the .md file** must be **in English**. Conversation with the user may be in any language.
- **Content:** Include business context (if relevant), affected areas, dependencies and order of changes, skills the implementer should invoke, risks/edge cases, and a step-by-step checklist. Do not write code; only the plan.

## Rules

- Do not write or edit application code; only produce the plan .md.
- Keep the plan concise for small tasks; be thorough for large or cross-cutting changes.
- After creating the plan, the orchestrator or the Backend/Frontend subagent will review it (strict: only suggest changes when something is wrong or missing) and then implement.
```

Añadir esta skill a la tabla **Meta Skills** en AGENTS.md y a la tabla **Auto-invoke** (o dejar que skill-sync la incluya vía `metadata.auto_invoke`).

---

### FASE 5: Skills de Tecnologías y Personalizados del Proyecto

**Obligatorio:** Una skill por cada tecnología utilizada en el proyecto (lenguajes, frameworks, librerías críticas, testing, build). Además, skills específicos del proyecto (ej. `{project}-api`, `{project}-ui`, `{project}-test-backend`, `{project}-test-frontend`, `{project}-export-formats`, etc.) según el análisis de FASE 1.

Para cada skill:

1. Analizar patrones específicos del proyecto.
2. Identificar reglas críticas (ALWAYS/NEVER).
3. Crear ejemplos mínimos pero claros.
4. Definir `metadata.scope` y `metadata.auto_invoke`.
5. Estructura: frontmatter, When to Use, Critical Patterns, Code Examples (opcional), Commands, Resources. Opcional: **Plan from Change Planner** — "Before implementing complex changes, check for a plan .md in `docs/`. If it exists, use it as the specification; review it and only suggest changes or polish when something is clearly wrong or missing (strict criterion)."

---

### FASE 6: Subagents (reglas en `.cursor/rules/`)

**Objetivo:** Crear 4 reglas .mdc que actúen como subagents: Backend Developer, Frontend Developer, Change Planner, Test Creator. Cada una debe generarse **según el análisis del proyecto** (nombres de carpetas, skills existentes, convenciones).

Usar formato **.mdc** con frontmatter YAML:

- `description`: Descripción breve (visible en el selector de reglas de Cursor).
- `globs`: Patrón de archivos para aplicación automática (usar forward slashes). Ejemplos: `backend/**/*.ts`, `frontend/**/*.tsx`, `backend/src/__tests__/**/*.ts`, `frontend/src/**/*.test.tsx`. Para Change Planner no es obligatorio glob (se elige a mano).
- `alwaysApply`: `false` para todas.

Contenido de cada regla (adaptar al proyecto):

**1. backend-developer.mdc**

- Título: Subagente Backend Developer / API & Backend Code.
- Cuándo invocar: modificar/añadir código backend, endpoints, modelos, lógica de negocio, webhooks, export, auth.
- Contexto obligatorio: Leer AGENTS.md; leer y aplicar la skill principal de API/backend del proyecto; si aplica, skills de typescript, security, export-formats.
- Optimización: Cargar solo los skills listados que apliquen al cambio.
- **Plan previo:** Si existe un plan .md en `docs/` para esta tarea (del Change Planner), leerlo y usarlo como especificación. Revisar el plan y solo sugerir pulir cuando haya un error claro o falte por aclarar (criterio estricto).
- Alcance: Solo la carpeta del backend (ej. `backend/`). Incluir arquitectura en capas, validación, errores tipados, estructura de carpetas según el proyecto.
- Reglas: Convenciones de estilo (comillas, punto y coma, no `any`, etc.); tras cambios, ejecutar lint/test/build del backend.

**2. frontend-developer.mdc**

- Título: Subagente Frontend Developer / React & UI (o el framework que use el proyecto).
- Cuándo invocar: componentes, páginas, hooks, estilos, integración con librerías UI.
- Contexto obligatorio: AGENTS.md; skills de UI y React/frontend del proyecto; si diseño, plan de diseño; si tipos/API, skill typescript.
- Optimización y **Plan previo:** Igual que Backend (usar plan .md en `docs/` si existe; pulir solo si hay error o falta).
- Alcance: Solo la carpeta del frontend. Estructura de componentes, estado/datos, estilos, convenciones.
- Reglas: No API keys en frontend; no omitir loading/error; tras cambios, lint/test/build del frontend.

**3. change-planner.mdc**

- Título: Subagente Change Planner / Task Analyst.
- Descripción: Analiza tareas y produce planes (sin escribir código). Invocar antes de cambios complejos o transversales.
- Sin glob o glob opcional; `alwaysApply: false`.
- Cuándo invocar: Antes de implementar una feature compleja o que afecte varias áreas; cuando se pida un plan o checklist.
- Contexto obligatorio: AGENTS.md; revisar `.cursor/skills/` para indicar en el plan qué skills debe invocar quien implemente.
- **Salida del plan:** Ubicación `docs/` (ej. `docs/plan-<feature>.md`). **Idioma del .md: siempre inglés.** Conversación con el usuario puede ser en otro idioma. El plan lo usa orquestador o subagente Backend/Frontend; el Planificador no implementa.
- Alcance (solo análisis): Contexto de negocio, áreas afectadas, dependencias, skills a invocar, buenas prácticas, riesgos/edge cases, checklist.
- Reglas: No escribir ni editar código. Plan .md en inglés; si la tarea es pequeña, plan breve; si es grande, exhaustivo.

**4. test-creator.mdc**

- Título: Subagente Test Creator / Test & QA.
- Cuándo invocar: añadir o modificar tests; edge cases; regresión.
- Contexto obligatorio: AGENTS.md; skills de test-backend y test-frontend del proyecto; si el código bajo test es API/Prisma o componente/hook, alinear con skills api/react para mocks.
- **Plan previo:** Si existe un plan .md en `docs/` para la feature que se testea, usarlo para alinear alcance y casos cuando sea relevante.
- Alcance: Backend (carpeta de tests, Jest/Supertest, mocks, etc.) y Frontend (Vitest/Testing Library, *.test.tsx, mock API/auth, etc.) según el proyecto.
- Reglas: Probar comportamiento y accesibilidad; edge cases (vacío, errores, loading, input inválido); tras añadir tests, ejecutar tests y comprobar lint/build.

Al crear cada archivo, usar **forward slashes** en paths dentro del contenido. Los nombres de archivos deben ser: `backend-developer.mdc`, `frontend-developer.mdc`, `change-planner.mdc`, `test-creator.mdc`.

---

### FASE 7: README.md de Skills

Crear `.cursor/skills/README.md` con: qué son los Agent Skills, cómo usarlos, lista de skills (genéricos, proyecto, meta incluyendo skill-planning), estructura de directorios, por qué Auto-invoke, cómo crear nuevas skills (skill-creator + checklist), design principles, recursos (agentskills.io, best practices, AGENTS.md). Incluir mención a **Subagents** en `.cursor/rules/` y al flujo plan → revisar → implementar (plan en inglés en `docs/`).

---

### FASE 8: Ejecutar skill-sync y Validación Final

1. Ejecutar el script de sincronización (ej. `./.cursor/skills/skill-sync/assets/sync.sh` o `node .cursor/skills/skill-sync/assets/sync.mjs`) para generar/actualizar la tabla Auto-invoke en AGENTS.md.
2. Verificar:
   - [ ] AGENTS.md tiene la sección Orchestrator/Skills/Subagents y el flujo plan → revisar → implementar.
   - [ ] AGENTS.md tiene menos de 500 líneas (o se justifica).
   - [ ] Todas las skills tienen frontmatter completo (incluida skill-planning).
   - [ ] La tabla Auto-invoke está actualizada.
   - [ ] Existen los 4 subagents en `.cursor/rules/` (backend-developer.mdc, frontend-developer.mdc, change-planner.mdc, test-creator.mdc) con globs y contenido adaptados al proyecto.
   - [ ] Los planes del Change Planner se documentan como .md en inglés en `docs/`.
   - [ ] Referencias en AGENTS.md a `.cursor/rules/` y a la convención de planes en `docs/`.

---

## Notas Importantes

1. **Análisis primero:** NUNCA crear archivos sin analizar el proyecto (FASE 1).
2. **Adaptación:** Skills y subagents deben reflejar las convenciones REALES del proyecto (rutas, nombres de skills, stack).
3. **Plan antes de implementar:** Para implementaciones no triviales, el orquestador debe planificar un .md en inglés (Change Planner o skill-planning) antes de ejecutar; revisar con criterio estricto; luego implementar.
4. **Subagents como reglas:** Los subagents son archivos .mdc en `.cursor/rules/`; Cursor los aplica por glob o por selección manual. Reducen carga de contexto al apuntar a 1–3 skills por tarea.
5. **Concisión:** Cada skill &lt; 500 líneas; reglas concisas; AGENTS.md como overview.
6. **Paths:** Usar siempre forward slashes (`/`) en documentación y en reglas.

---

## Comenzar

Comienza con la **FASE 1: Análisis del Proyecto**. Explora la estructura, identifica tecnologías, patrones y rutas para backend/frontend/tests. Luego procede en orden: FASE 2 (estructura), FASE 3 (AGENTS.md), FASE 4 (meta skills + skill-planning), FASE 5 (skills por tecnología y proyecto), FASE 6 (subagents .mdc), FASE 7 (README skills), FASE 8 (sync y validación).
