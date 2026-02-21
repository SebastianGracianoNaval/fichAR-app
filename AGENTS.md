# fichAR — Supreme Orchestrator Agent

> **Labor Compliance Management System for Argentine Companies**

**Philosophy:** *"Bank-Grade Code, Human-Grade Interface"*

---

## Golden Rules

1. **Never write code without an explicit definition** in `definiciones/*.txt` or `clean_definitions/*.txt`
2. **Before any change affecting labor data** (time tracking, schedules, licenses, reports) → invoke `fichar-legal-compliance`
3. **For auth, RLS, hashing, logs** → invoke `fichar-security`
4. **For webhooks, ARCA, imports/exports** → invoke `fichar-integrations`
5. **Plan before code**: Non-trivial changes → Change Planner → plan `.md` in English in `docs/` → review → implement
6. **Load at most 1–3 skills** at once; prioritize the most specific one

---

## Skill Decision Table

| Task involves | Primary skill | Secondary skills |
|---------------|---------------|------------------|
| Time tracking, schedules, bank hours, descansos | fichar-legal-compliance | fichar-postgres, fichar-supabase |
| Auth, RLS, hashing, audit logs, 2FA | fichar-security | fichar-postgres |
| Webhooks, ARCA, Excel/CSV, n8n | fichar-integrations | fichar-go, fichar-postgres |
| Flutter mobile/web UI | fichar-flutter | fichar-android or fichar-ios |
| Android-specific (WorkManager, geofencing) | fichar-android | fichar-flutter |
| iOS-specific (Background Fetch, Face ID) | fichar-ios | fichar-flutter |
| Desktop app (Tauri/Electron) | fichar-desktop | fichar-flutter |
| macOS build, notarization | fichar-mac | fichar-desktop |
| Linux .deb, Ubuntu/Debian | fichar-linux | fichar-desktop |
| Windows installer | fichar-windows | fichar-desktop |
| Schema, queries, migrations, RLS | fichar-postgres | fichar-supabase |
| Supabase Auth, Realtime, Storage | fichar-supabase | fichar-postgres |
| Go API, endpoints | fichar-go | fichar-supabase |
| Scripts, package.json, Bun | fichar-bun | — |
| Battery, threading, geofencing | fichar-performance | fichar-android, fichar-ios |
| Android 5, iOS 12, low memory | fichar-low-end | fichar-flutter |
| Backend/API tests | fichar-test-backend | — |
| Flutter widget tests | fichar-test-frontend | fichar-flutter |
| E2E, Playwright | fichar-test-e2e | — |
| Bug reported, unclear cause | fichar-bug-audit | — |
| Implement fix after hypothesis | fichar-bug-fix | — |
| Before merging fix | fichar-regression-check | — |
| Create new skill | skill-creator | — |
| Sync skills to AGENTS | skill-sync | — |
| Produce plan before implementation | skill-planning | — |

---

## Source of Truth

**For screens, configurations, edge cases, roles, security:** Consult `definiciones/*.txt` and `clean_definitions/*.txt`. **Do not improvise.**

| Document | Location | Content |
|----------|----------|---------|
| Root definition | `definiciones/DEFINICION-PROYECTO-FICHAR.md` | Vision, stack, roadmap |
| Complete definition | `clean_definitions/FICHAR-DEFINICION-COMPLETA.txt` | Consolidated reference |
| Screens | `definiciones/PANTALLAS.txt` | Every screen: fields, states, validations |
| Configurations | `definiciones/CONFIGURACIONES.txt` | All CFG-* options, defaults |
| Edge cases | `definiciones/CASOS-LIMITE.txt` | CL-001 to CL-043 |
| Roles | `definiciones/ROLES.txt` | Permission matrix per role |
| Security | `definiciones/SEGURIDAD.txt` | Exhaustive security requirements |
| Integrations | `definiciones/INTEGRACIONES.txt` | Formats, webhooks, ARCA |
| Frontend | `definiciones/FRONTEND.txt` | Palettes, look & feel, low-end vs high-end |
| Index | `clean_definitions/INDICE-REFERENCIAS.txt` | Quick lookup by topic |

---

## Workflow: Plan → Review → Implement

1. **Non-trivial change?** → Invoke `skill-planning` → Create `docs/plans/<feature>.md` in English
2. **Review plan** against definitions
3. **Implement** with appropriate domain/tech skills
4. **Run tests** before considering done

---

## Subagents

| Subagent | Use when | Skills loaded |
|----------|----------|---------------|
| backend-developer | API, DB, Go, Supabase | fichar-go, fichar-supabase, fichar-security, fichar-postgres |
| frontend-developer | Flutter web/desktop | fichar-flutter, fichar-desktop |
| mobile-developer | Flutter iOS/Android | fichar-flutter, fichar-android, fichar-ios |
| change-planner | Need structured plan | skill-planning |
| test-creator | Adding/modifying tests | fichar-test-backend, fichar-test-frontend, fichar-test-e2e |
| security-reviewer | Auth, RLS, logs changes | fichar-security |
| legal-reviewer | Fichaje, schedules, reports | fichar-legal-compliance |

---

## Technology Stack

- **Frontend:** Flutter 3.x (mobile, web, desktop)
- **Desktop:** Tauri (preferred) or Electron
- **Backend:** Go or Node/Bun
- **DB/Auth:** Supabase (PostgreSQL, RLS, Auth, Realtime)
- **Package manager:** Bun

---

## Compatibility

| Platform | Minimum version |
|----------|-----------------|
| Android | API 21+ (Android 5.0) |
| iOS | iOS 12+ |
| Windows | Windows 10+ |
| macOS | macOS 10.14+ |
| Linux | Ubuntu 18.04+ / Debian 10+ |
