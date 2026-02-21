# Prompt: Setup fichAR Skills System, Supreme Orchestrator Agent, and Subagents

**Project:** fichAR — Labor Compliance Management System for Argentine Companies  
**Root document:** [DEFINICION-PROYECTO-FICHAR.md](./DEFINICION-PROYECTO-FICHAR.md)

**IMPORTANT:** Copy and paste this entire prompt into the Cursor chat. The agent will create everything: AGENTS.md, skills, and subagents. **All output must be in English** (AGENTS.md, skill content, subagent rules, file names, descriptions).

---

## What This Prompt Does

When you paste this prompt in Cursor, the agent will:

1. Create **AGENTS.md** as a supreme, meticulous orchestrator that chooses the best skill for each task
2. Create **all skills** in `.cursor/skills/` (none exist beforehand)
3. Create **all subagents** in `.cursor/rules/` as `.mdc` files
4. Ensure everything is written **in English**

**Do not create any files before running this prompt.** The prompt instructs the agent to create everything from scratch.

---

## Orchestrator Philosophy

AGENTS.md must act as a **supreme, meticulous orchestrator**:

1. **Analyze the task** before acting: What domain does it touch? Which skill is most suitable?
2. **Never load more than 1–3 skills** at once; prioritize the most specific one
3. **For legal tasks:** Always invoke `fichar-legal-compliance` before approving changes that affect time tracking, schedules, licenses, or reports
4. **For security:** Always invoke `fichar-security` for auth, RLS, hashing, or logs changes
5. **For integrations:** Always invoke `fichar-integrations` for webhooks, ARCA, imports/exports
6. **Plan before code:** Non-trivial changes → Change Planner → plan .md in English → review → implement

---

## Mandatory Definition Documents (read before implementing)

| Document | Location | Content |
|----------|----------|---------|
| Root definition | `definiciones/DEFINICION-PROYECTO-FICHAR.md` | Vision, stack, architecture, roadmap |
| Screens | `definiciones/PANTALLAS.txt` | Every screen: fields, states, validations, flows |
| Configurations | `definiciones/CONFIGURACIONES.txt` | Every configurable option, defaults, combinations |
| Edge cases | `definiciones/CASOS-LIMITE.txt` | Edge cases with exact behavior |
| Roles | `definiciones/ROLES.txt` | Full permission matrix per role and action |
| Security | `definiciones/SEGURIDAD.txt` | Exhaustive security requirements |
| Integrations | `definiciones/INTEGRACIONES.txt` | Formats, protocols, adapters, legacy |
| Frontend | `definiciones/FRONTEND.txt` | Colors, look & feel, two app modes |
| Scalability | `definiciones/ESCALABILIDAD.txt` | Custom attributes, extensibility |
| Employer customization | `definiciones/PERSONALIZACION-EMPLEADOR.txt` | Highly configurable employer settings |
| Legal/Audit role | `definiciones/ROL-AUDITOR-JUICIOS.txt` | Hidden role for labor lawsuits |
| Analytics & reports | `definiciones/ANALISIS-REPORTES.txt` | Graphs, XLSX structure, data exports |
| Limits & alerts | `definiciones/LIMITACIONES-ALERTAS.txt` | Configurable limits (bank hours, weekly hours, etc.) |
| Projects module | `definiciones/MODULO-PROYECTOS.txt` | Optional client→project→tasks (disablable) |
| Optimization | `definiciones/OPTIMIZACION.txt` | Performance, battery, best practices |
| Testing & docs | `definiciones/TESTING-DOCUMENTACION.txt` | Test strategy, docs structure, troubleshooting |

**Absolute rule:** Do not write a single line of code without an explicit definition in these documents.

---

## Skills to Create

### Domain skills (critical)

| Skill | Description | When to invoke |
|-------|-------------|----------------|
| `fichar-legal-compliance` | Ensures code and features comply with LCT, 2026 Labor Reform, Art. 52, 197 bis, 198, 210, Law 11.544. Outputs legal checklist. | Before approving changes to time tracking, schedules, licenses, reports |
| `fichar-security` | Security requirements: hashing, RLS, audit logs, 2FA, sessions, encryption. | Auth, permissions, data logging, logs |
| `fichar-integrations` | Webhooks, ARCA, Excel/CSV, n8n, compatibility with legacy and current projects. | Integrations, imports, exports, external APIs |

### Platform skills

| Skill | Description | When to invoke |
|-------|-------------|----------------|
| `fichar-flutter` | Flutter 3.x for mobile/web/desktop; widgets, state, navigation. | Flutter code |
| `fichar-android` | Android API 21+, WorkManager, geofencing, low-end optimization. | Android app changes |
| `fichar-ios` | iOS 12+, Background Fetch, Face ID, Apple restrictions. | iOS app changes |
| `fichar-desktop` | Tauri/Electron, Windows 10+, macOS 10.14+, Linux. | Desktop app |
| `fichar-mac` | macOS-specific: notarization, permissions, sandbox. | macOS build/distribution |
| `fichar-linux` | Debian/Ubuntu, .deb installation, compatibility. | Linux build/distribution |
| `fichar-windows` | Windows 10+, installer, permissions. | Windows build/distribution |

### Technology skills

| Skill | Description | When to invoke |
|-------|-------------|----------------|
| `fichar-supabase` | PostgreSQL, RLS, Auth, Realtime, Storage. Multi-tenant by org_id. | Schema, queries, auth |
| `fichar-go` | Go backend: endpoints, goroutines, validation. | Go API |
| `fichar-bun` | Bun as runtime and package manager; scripts, tests. | Scripts, package.json |
| `fichar-postgres` | Queries, indexes, RLS, performance. | SQL, migrations |

### Optimization skills

| Skill | Description | When to invoke |
|-------|-------------|----------------|
| `fichar-performance` | Low battery usage, threading, efficient geofencing, low-end mode. | Performance, background |
| `fichar-low-end` | Old devices: fewer animations, tolerant geofencing. | Optimization for Android 5, iOS 12 |

### Testing skills

| Skill | Description | When to invoke |
|-------|-------------|----------------|
| `fichar-test-backend` | Backend/API tests, mocks, fixtures. | Adding or modifying backend tests |
| `fichar-test-frontend` | Flutter widget tests, integration tests. | Adding or modifying frontend tests |
| `fichar-test-e2e` | E2E flows, Playwright, critical user paths. | Adding or modifying E2E tests |

### Bug audit and fix skills

| Skill | Description | When to invoke |
|-------|-------------|----------------|
| `fichar-bug-audit` | Audits a reported bug, generates clear hypothesis of cause, affected files, reproduction steps. | When user reports a bug or test fails without obvious cause |
| `fichar-bug-fix` | Implements minimal fix, includes test that reproduces bug and verifies fix. | After hypothesis confirmed or obvious fix |
| `fichar-regression-check` | Lists areas that could be affected by a fix; suggests tests to run. | Before merging a fix |

### Meta skills

| Skill | Description |
|-------|-------------|
| `skill-creator` | Create new AI agent skills following Agent Skills standard |
| `skill-sync` | Sync skill metadata to AGENTS.md |
| `skill-planning` | Produce .md plan in English before implementation |

---

## Instructions for the Agent

You are an expert orchestrator agent. Your task is to **analyze the fichAR project** and create:

1. **AGENTS.md** (root) as supreme orchestrator:
   - Decision table: "If task involves X → invoke skill Y"
   - Mandatory reference to `definiciones/` as source of truth
   - Plan → review → implement flow
   - Subagents and skills with selection criteria
   - **All content in English**

2. **Skills** in `.cursor/skills/`:
   - Create every skill listed above (domain, platform, technology, optimization, meta)
   - Each SKILL.md must be in **English**
   - `fichar-legal-compliance`: explicit checklist against LCT/Reform
   - `fichar-security`: detailed requirements
   - `fichar-integrations`: formats and adapters

3. **Subagents** in `.cursor/rules/`:
   - `backend-developer.mdc` → skills: fichar-go, fichar-supabase, fichar-security, fichar-postgres
   - `frontend-developer.mdc` → skills: fichar-flutter, fichar-android or fichar-ios (by platform)
   - `mobile-developer.mdc` → Flutter + Android/iOS
   - `change-planner.mdc` → plan .md in English in docs/
   - `test-creator.mdc` → test skills
   - `security-reviewer.mdc` → fichar-security
   - `legal-reviewer.mdc` → fichar-legal-compliance
   - **All content in English**

4. **Structure** as specified in FASE 2 below.

---

### PHASE 1: Analysis and Reading Definitions

**BEFORE creating any files:**

1. Read `definiciones/DEFINICION-PROYECTO-FICHAR.md` in full
2. Read all documents in `definiciones/*.txt` and `definiciones/*.md`
3. Identify technologies: Flutter, Go/Bun, Supabase, Tauri, Android, iOS
4. Document paths: `apps/mobile/`, `apps/web/`, `packages/api/`, `supabase/`

---

### PHASE 2: Base Structure

```
fichar-app/
├── AGENTS.md
├── definiciones/
│   ├── DEFINICION-PROYECTO-FICHAR.md
│   ├── PANTALLAS.txt
│   ├── CONFIGURACIONES.txt
│   ├── CASOS-LIMITE.txt
│   ├── ROLES.txt
│   ├── SEGURIDAD.txt
│   ├── INTEGRACIONES.txt
│   ├── FRONTEND.txt
│   ├── ESCALABILIDAD.txt
│   ├── PERSONALIZACION-EMPLEADOR.txt
│   ├── ROL-AUDITOR-JUICIOS.txt
│   ├── ANALISIS-REPORTES.txt
│   ├── LIMITACIONES-ALERTAS.txt
│   ├── MODULO-PROYECTOS.txt
│   └── OPTIMIZACION.txt
└── .cursor/
    ├── rules/
    │   ├── backend-developer.mdc
    │   ├── frontend-developer.mdc
    │   ├── mobile-developer.mdc
    │   ├── change-planner.mdc
    │   ├── test-creator.mdc
    │   ├── security-reviewer.mdc
    │   └── legal-reviewer.mdc
    └── skills/
        ├── README.md
        ├── fichar-legal-compliance/
        │   └── SKILL.md
        ├── fichar-security/
        │   └── SKILL.md
        ├── fichar-integrations/
        │   └── SKILL.md
        ├── fichar-flutter/
        │   └── SKILL.md
        ├── fichar-android/
        │   └── SKILL.md
        ├── fichar-ios/
        │   └── SKILL.md
        ├── fichar-desktop/
        │   └── SKILL.md
        ├── fichar-supabase/
        │   └── SKILL.md
        ├── fichar-go/
        │   └── SKILL.md
        ├── fichar-bun/
        │   └── SKILL.md
        ├── fichar-postgres/
        │   └── SKILL.md
        ├── fichar-performance/
        │   └── SKILL.md
        ├── fichar-low-end/
        │   └── SKILL.md
        ├── fichar-test-backend/
        │   └── SKILL.md
        ├── fichar-test-frontend/
        │   └── SKILL.md
        ├── fichar-test-e2e/
        │   └── SKILL.md
        ├── skill-creator/
        │   ├── SKILL.md
        │   └── assets/
        ├── skill-sync/
        │   ├── SKILL.md
        │   └── assets/
        └── skill-planning/
            └── SKILL.md
```

---

### PHASE 3: AGENTS.md — Supreme Orchestrator

Include:

1. **Skill decision table** (in English)
2. **Golden rule:** Before any change affecting labor data, run `fichar-legal-compliance`
3. **Reference to definitions:** "For screens, configurations, edge cases, roles, consult `definiciones/*.txt`. Do not improvise."
4. **All sections in English**

---

### PHASE 4: Skills Content

Each skill’s SKILL.md must:

- Use YAML frontmatter with `name`, `description` (in English)
- Reference the relevant `definiciones/` document
- Include "When to use" and "Critical patterns"
- Be written entirely in **English**

---

### PHASE 5: Subagents

Each `.mdc` file must:

- Have YAML frontmatter with `description`, `globs`, `alwaysApply`
- List which skills to load
- Be written in **English**

---

## Start

Begin with **PHASE 1**: Read all documents in `definiciones/`. Then PHASE 2 (structure), PHASE 3 (AGENTS.md), PHASE 4 (skills), PHASE 5 (subagents). Run skill-sync at the end.

**Reminder:** Define everything before writing a single line of code. **All output must be in English.**
