# fichAR — Definición Completa del Proyecto

> **Sistema de Gestión y Administración de Cumplimiento Laboral para Empresas y PyMEs Argentinas**

**Filosofía:** *"Código de Grado Bancario, Interfaz de Grado Humano"*

**Versión del documento:** 1.0  
**Fecha:** 20 de febrero de 2026

---

## Índice

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Contexto Socio-Político Argentina 2026](#2-contexto-socio-político-argentina-2026)
3. [Marco Legal — Reforma Laboral](#3-marco-legal--reforma-laboral)
4. [Stack Tecnológico](#4-stack-tecnológico)
5. [Arquitectura del Sistema](#5-arquitectura-del-sistema)
6. [Roles y Permisos](#6-roles-y-permisos)
7. [Pantallas y Flujos por Rol](#7-pantallas-y-flujos-por-rol)
8. [Funcionalidades Detalladas](#8-funcionalidades-detalladas)
9. [Casos Edge y Manejo de Excepciones](#9-casos-edge-y-manejo-de-excepciones)
10. [Seguridad](#10-seguridad)
11. [Integraciones y Compatibilidad](#11-integraciones-y-compatibilidad)
12. [Entorno de Desarrollo y Comandos](#12-entorno-de-desarrollo-y-comandos)
13. [Plan de Despliegue](#13-plan-de-despliegue)
14. ["Sabías que..." — Cultura Legal](#14-sabías-que--cultura-legal)
15. [Hoja de Ruta Sugerida](#15-hoja-de-ruta-sugerida)

---

## 1. Resumen Ejecutivo

**fichAR** es una aplicación multiplataforma diseñada para que empresas y PyMEs argentinas cumplan con la Ley de Contrato de Trabajo (LCT) y la **Ley de Modernización Laboral 2026**, centrada en:

- **Registro horario digital** (fichaje entrada/salida) con geolocalización
- **Banco de horas** y control de jornada según la reforma
- **Cumplimiento legal** con registros inalterables válidos en juicios laborales
- **Optimización** para dispositivos de gama baja y alto rendimiento

### Oportunidad de Mercado

- Informalidad laboral en Argentina: **40-45%**
- La reforma laboral **reduce exigencias documentales** y favorece el registro digital
- PyMEs buscan **simplificar** el control horario sin perder validez legal
- **ARCA** (ex-AFIP) centraliza el registro de empleados; fichAR complementa con control de jornada

---

## 2. Contexto Socio-Político Argentina 2026

### Situación Económica y Laboral

| Indicador | Valor | Implicancia para fichAR |
|-----------|-------|-------------------------|
| Desocupación | ~6-7% | Mercado estable, demanda de herramientas formales |
| Empleo formal | Estancado (~misma cantidad que hace 10 años) | Necesidad de facilitar la formalización |
| Informalidad | 40-45% | Oportunidad: RIFL incentiva formalizar con reducción de cargas |
| Reforma Laboral | En debate (Feb 2026) | Normativa en transición; fichAR debe ser adaptable |

### Reformas Clave que Impactan a fichAR

1. **RIFL** (Régimen de Incentivo a la Formalización Laboral): Reduce cargas patronales 48 meses al formalizar trabajadores.
2. **FAL** (Fondo de Asistencia Laboral): Contribución 1% grandes empresas, 2,5% PyMEs sobre nómina.
3. **Banco de horas**: Permite compensar jornadas con acuerdo voluntario escrito.
4. **Registro simplificado**: Eliminación de registros tradicionales complejos; ARCA como único registro obligatorio.
5. **Método fehaciente de control**: La reforma exige un sistema que permita registrar horas efectivamente trabajadas — **fichAR responde a esto**.

### Contexto Político

- Resistencia sindical con paros nacionales.
- Apoyo de gobernadores y cámaras empresariales (UIA).
- **fichAR** debe posicionarse como herramienta neutral que beneficia a empleadores (control) y trabajadores (transparencia, bancos de horas, descansos).

---

## 3. Marco Legal — Reforma Laboral

### Artículos Relevantes para fichAR

| Artículo / Norma | Contenido | Implicancia técnica |
|------------------|-----------|---------------------|
| **Art. 52 LCT** | Registro de trabajadores ante ARCA. Libros digitalizados con misma validez que papel. | Integración futura con ARCA; exportación de datos para auditorías. |
| **Art. 197 bis** | Régimen de compensación (banco de horas). Acuerdo voluntario por escrito. **Método fehaciente de control** que registre horas efectivas. | Core de fichAR: fichaje, tiempos, banco de horas. |
| **Art. 198** | Jornada reducida, promedio. **Descanso mínimo 12h entre jornadas**, 35h descanso semanal. | Validaciones: no permitir fichar si no pasaron 12h; alertas de fatiga. |
| **Art. 210** | Certificados médicos firmados digitalmente (Ley 27.553). | Integración con plataformas de firma; OCR para certificados adjuntos. |
| **Ley 11.544** | 8h diarias, 48h semanales; excepciones. Pausa 12h entre jornadas. | Cálculo de horas extras, alertas de sobrecarga. |

### Requisitos Legales que fichAR debe Cumplir

- [ ] Registro inalterable de cada fichaje (validez probatoria en juicios).
- [ ] Timestamp de servidor (no solo del dispositivo).
- [ ] Geolocalización para verificar lugar de trabajo.
- [ ] Método fehaciente de control de horas efectivamente trabajadas.
- [ ] Respeto a descansos mínimos (12h entre jornadas, 35h semanales).
- [ ] Banco de horas con trazabilidad y acuerdo documentado.

---

## 4. Stack Tecnológico

### Resumen

| Capa | Tecnología | Justificación |
|------|------------|---------------|
| **Frontend Mobile** | Flutter 3.x | Un solo código para iOS, Android; rendimiento nativo; soporte dispositivos viejos. |
| **Frontend Web/Desktop** | Flutter Web + Tauri o Electron | Escritorio Windows/macOS/Linux; distribución como .exe, .dmg, .deb. |
| **Backend** | Go (Golang) | Rendimiento, goroutines para concurrencia, binarios pequeños. Alternativa: Node/Bun si priorizas velocidad de desarrollo. |
| **Base de datos / Auth** | **Supabase** (PostgreSQL) | RLS, Auth, Realtime; no queda chico para PyMEs. Escalable. |
| **Gestor de paquetes** | **Bun** | Más rápido que npm; compatible con scripts shell; preferencia del desarrollador. |
| **Integraciones** | n8n / Webhooks | Conectar con Jira, SAP, ERPs con desarrollo mínimo. |

### Supabase — ¿Queda pequeño?

**No.** Para PyMEs argentinas (decenas a cientos de empleados por empresa):

- PostgreSQL maneja millones de registros sin problema.
- RLS (Row Level Security) es crítico para multi-tenant (cada empresa aislada).
- Auth integrado (email, OTP, futura integración OAuth).
- Realtime para notificaciones y actualización de dashboards.
- Límites free tier generosos para MVP; planes Pro escalables.

### Compatibilidad de Dispositivos

| Plataforma | Versiones mínimas |
|------------|-------------------|
| Android | API 21+ (Android 5.0) |
| iOS | iOS 12+ |
| Windows | Windows 10+ |
| macOS | macOS 10.14+ |
| Linux | Ubuntu 18.04+ / Debian 10+ |

### Estrategia "Dos Apps que se comunican"

- **App ligera** (low-end): Menos animaciones, geofencing simplificado, menos features en segundo plano.
- **App full** (high-end): Animaciones, sonidos, haptics, todas las features.
- Misma API y base de datos; detección de capacidad del dispositivo para ajustar UX.

---

## 5. Arquitectura del Sistema

### Diagrama de Capas

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAPA DE PRESENTACIÓN                          │
│  Flutter (Mobile)  │  Flutter Web  │  Desktop (Tauri/Electron)   │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                    API (Go / Node+Bun)                           │
│  REST + WebSockets  │  Auth JWT  │  Rate Limiting  │  Validación │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                    SUPABASE                                      │
│  PostgreSQL (RLS)  │  Auth  │  Realtime  │  Storage (archivos)   │
└─────────────────────────────────────────────────────────────────┘
```

### Principios

- **Clean Architecture + DDD**: Dominio independiente de frameworks.
- **Multi-tenant**: Una organización (empresa) por tenant; RLS por `org_id`.
- **Event-driven** donde aplique: fichajes, licencias, alertas vía Realtime.

### Estructura de Carpetas Sugerida

```
fichar-app/
├── apps/
│   ├── mobile/          # Flutter (iOS + Android)
│   ├── web/             # Flutter Web
│   └── desktop/         # Tauri/Electron wrapper
├── packages/
│   ├── api/             # Backend Go o Node
│   ├── shared/          # Modelos, tipos compartidos
│   └── ui-kit/          # Componentes Flutter compartidos
├── definiciones/        # Documentos como este
├── supabase/
│   ├── migrations/
│   └── seed/
└── scripts/             # Bun scripts (deploy, tests)
```

---

## 6. Roles y Permisos

### Matriz de Roles

| Rol | Descripción | Permisos principales |
|-----|-------------|----------------------|
| **Empleado** | Trabajador estándar | Fichar, ver su banco de horas, solicitar licencias, ver tareas asignadas, ver "Sabías que..." |
| **Supervisor / Gerente** | A cargo de un equipo | Todo lo de Empleado + ver equipo, aprobar licencias, alertas de incumplimiento descanso (Art. 198), reportes de equipo |
| **Empleador / Admin** | Dueño o RRHH | Configuración total, lugares de trabajo, reportes masivos, creación batch de cuentas, activar/desactivar funcionalidades |
| **Auditor** (opcional) | Solo lectura forense | Acceso a logs inmutables para peritajes; sin edición |

### Permisos Granulares (Configurables por Empleador)

El empleador puede, por ejemplo:

- Desactivar la app móvil (solo tracking desde PC de trabajo).
- Activar/desactivar geolocalización.
- Activar/desactivar timesheet de tareas.
- Activar/desactivar notificaciones "¿Qué hiciste hoy?".
- Definir si el banco de horas está habilitado.

---

## 7. Pantallas y Flujos por Rol

### 7.1 Empleado

| Pantalla | Descripción | Acceso |
|----------|-------------|--------|
| **Login** | Email/contraseña, 2FA, huella/Face ID (mobile) | Público |
| **Dashboard** | Botón central "Fichar", barra banco de horas, resumen del día | Empleado+ |
| **Mis Horas** | Historial de fichajes, banco de horas, horas extras | Empleado+ |
| **Licencias** | Solicitar licencia, adjuntar PDF/imagen certificado | Empleado+ |
| **Tareas** | Tareas asignadas, vincular a timesheet | Empleado+ (si habilitado) |
| **Perfil** | Datos personales, preferencias, dispositivos autorizados | Empleado+ |
| **Sabías que...** | Splash o modal con tips legales | Empleado+ |

### 7.2 Supervisor / Gerente

| Pantalla | Descripción | Acceso |
|----------|-------------|--------|
| Todas las de Empleado | — | Sí |
| **Mi Equipo** | Lista de empleados a cargo, estado de fichaje | Supervisor+ |
| **Aprobar Licencias** | Cola de solicitudes pendientes | Supervisor+ |
| **Alertas** | Incumplimiento descanso 12h, intentos de fichar fuera de zona | Supervisor+ |
| **Reportes de Equipo** | Horas trabajadas, presentismo del equipo | Supervisor+ |

### 7.3 Empleador / Admin

| Pantalla | Descripción | Acceso |
|----------|-------------|--------|
| Todas las anteriores | — | Sí |
| **Panel de Control** | Resumen global, KPIs, alertas | Admin |
| **Empleados** | CRUD, importar Excel/CSV (DNI, CUIT, nombre, etc.) | Admin |
| **Crear Cuentas Batch** | Crear 50+ cuentas a la vez | Admin |
| **Lugares de Trabajo** | Definir perímetros (oficina, remoto, híbrido), importar Excel/CSV | Admin |
| **Reportes** | Excel con presentismo, horas pico, días sin trabajar, ranking banco de horas | Admin |
| **Configuración** | Activar/desactivar funcionalidades, integraciones, notificaciones | Admin |
| **Logs / Auditoría** | Registro de acciones críticas (solo lectura para Auditor) | Admin / Auditor |

---

## 8. Funcionalidades Detalladas

### 8.1 Fichaje (Core)

- **Acción**: Un botón para marcar entrada o salida (alterna).
- **Geolocalización**: Obligatoria; el botón se habilita solo si el GPS está dentro del radio definido (ej. 100m de la oficina).
- **Lugares de trabajo**: El empleador define múltiples ubicaciones (oficina, sucursales, domicilio remoto). Cada empleado tiene asignados sus lugares según modalidad (ej. L-Mi presencial, J-V remoto).
- **Importación**: Excel/CSV para cargar empleados + lugares en batch.
- **Modo offline**: Fichar sin internet; guardar cifrado localmente; sincronizar al recuperar conexión con timestamp firmado (hash).

### 8.2 Banco de Horas

- Visualización para empleado y empleador.
- Cálculo automático según fichajes.
- Límite máximo según reforma (acuerdo escrito).
- Alertas cuando el banco supere umbrales definidos (ej. riesgo de pago de extras).

### 8.3 Licencias

- Solicitud con adjuntos: PDF, imagen (certificado médico).
- OCR (opcional) para extraer fechas del certificado y pre-aprobar período.
- Flujo: Empleado solicita → Supervisor/Admin aprueba o rechaza.
- Integración con certificados firmados digitalmente (Ley 27.553) cuando esté disponible.

### 8.4 Tareas y Timesheet

- Asignación de tareas por Supervisor/Admin.
- Empleado puede vincular horas a tareas específicas.
- Notificación "¿Qué hiciste hoy?" opcional para recordar registrar.

### 8.5 Reportes

| Reporte | Contenido | Formato |
|---------|-----------|---------|
| Presentismo | Índice por empleado, período | Excel |
| Banco de horas | Ranking, riesgo de extras | Excel |
| Horas trabajadas | Por día, semana, mes | Excel |
| Alertas fatiga | Incumplimiento Art. 198 (12h descanso) | Excel / Dashboard |
| Días sin trabajar | Inasistencias, licencias | Excel |
| Reportes programados | Envío automático cada N días (ej. día 3 de cada mes) | Email + Excel adjunto |

### 8.6 Configuración Activable/Desactivable

- App móvil habilitada/deshabilitada.
- Geolocalización obligatoria/opcional.
- Timesheet de tareas.
- Notificaciones "¿Qué hiciste hoy?".
- Banco de horas.

---

## 9. Casos Edge y Manejo de Excepciones

### 9.1 Fichaje fuera de zona

- **Caso**: Empleado intenta fichar desde casa en día presencial.
- **Comportamiento**: Botón deshabilitado; notificación al Supervisor: "Empleado X intentó fichar fuera de zona a las HH:MM".
- **Log**: Registro inmutable del intento (para posibles disputas).

### 9.2 Fichaje remoto no autorizado

- **Caso**: Empleado híbrido intenta fichar desde ubicación no definida como remoto.
- **Comportamiento**: Igual que 9.1; validación contra lista de lugares asignados.

### 9.3 Descanso insuficiente (Art. 198)

- **Caso**: Empleado fichó salida a las 22:00 y intenta fichar entrada a las 07:00 (solo 9h de descanso).
- **Comportamiento**: Advertencia; opcionalmente bloquear fichaje hasta cumplir 12h. Alerta al Supervisor.
- **Excepciones**: Turnos rotativos, convenios que permitan excepciones (configurable).

### 9.4 Cambio de dispositivo

- **Caso**: Empleado se loguea en celular nuevo.
- **Comportamiento**: Requiere validación por email + código enviado al dispositivo anterior o aprobación Admin.
- **Seguridad**: Evitar robo de credenciales.

### 9.5 Modo offline prolongado

- **Caso**: Empleado sin conexión varios días.
- **Comportamiento**: Fichajes guardados localmente cifrados; al reconectar, sincronización con timestamp del servidor; conflictos resueltos por timestamp más antiguo registrado.

### 9.6 Solicitud de licencia con certificado

- **Caso**: Empleado sube foto de certificado médico.
- **Comportamiento**: OCR para extraer fechas; pre-aprobar período si coincide. Si OCR falla, revisión manual por Supervisor.
- **Adjuntos**: PDF, JPG, PNG soportados.

### 9.7 Edición fraudulenta de horarios

- **Caso**: Admin intenta modificar un fichaje pasado.
- **Comportamiento**: Sistema de hashing en cadena (cada registro con hash del anterior); si se edita, la cadena se rompe; Auditor puede detectar manipulación.
- **Regla**: No se permiten ediciones directas; solo correcciones con justificación y nuevo registro que enlace al anterior.

### 9.8 Dispositivos con OS muy antiguos

- **Caso**: Android 5 o iOS 12 con limitaciones.
- **Comportamiento**: App en modo "low-end": menos animaciones, geofencing más tolerante, sincronización menos frecuente en background.

---

## 10. Seguridad

### Prioridad #1

- **Inalterabilidad**: Hash SHA-256 por cada registro; cadena de bloques simplificada.
- **Audit logs**: IP, dispositivo, versión app, timestamp servidor en cada acción crítica.
- **2FA/MFA**: Obligatorio para Admin; opcional para Empleados (recomendado).
- **Biometría**: Huella / Face ID en mobile para "firmar" cierre de jornada semanal (opcional).
- **Sesiones**: Login dura 3h en esa IP/dispositivo; renovación con actividad.
- **Row Level Security (RLS)**: Cada query filtrada por `org_id`; imposible ver datos de otra empresa.

### Recomendaciones Adicionales

- Cifrado en tránsito (HTTPS) y en reposo (Supabase lo provee).
- Logs de todo acceso a datos sensibles.
- Backups automáticos con retención según normativa (ej. 10 años para registros laborales según Art. 52).
- Cumplimiento con normativas de protección de datos (leyes locales argentinas).

---

## 11. Integraciones y Compatibilidad

### 11.1 ARCA (ex-AFIP)

- **Objetivo**: Sincronización de altas/bajas de empleados (futuro).
- **Datos**: CUIL, fecha ingreso, categoría, etc. — solo lectura o alimentar desde fichAR si ARCA lo permite.
- **Prioridad**: Media; no bloqueante para MVP.

### 11.2 Integraciones con Desarrollo Mínimo

- **Webhooks**: Eventos (fichaje, licencia aprobada) enviados a URL configurable.
- **n8n / Zapier**: Conectores para ERPs, Jira, SAP.
- **Exportación Excel**: Ya contemplada en reportes.

### 11.3 Importación de Datos

- **Empleados**: Excel/CSV con columnas: DNI, CUIT/CUIL, nombre, email, dirección, lugar de trabajo, modalidad (presencial/híbrido/remoto).
- **Lugares de trabajo**: Excel/CSV con dirección, radio (m), días asignados.

---

## 12. Entorno de Desarrollo y Comandos

### Entorno

- **OS**: Debian 12 (Linux).
- **Gestor**: Bun.

### Comandos (package.json ejemplo)

```json
{
  "scripts": {
    "dev": "echo 'fichAR: Gestor y Administración | v1.0.0-dev' && bun run server.ts",
    "dev:mobile": "cd apps/mobile && flutter run",
    "dev:web": "cd apps/web && flutter run -d chrome",
    "test": "bun test",
    "test:e2e": "bun run test:e2e",
    "db:migrate": "supabase db push",
    "lint": "bun run lint:api && cd apps/mobile && flutter analyze"
  }
}
```

### Banner de Terminal

```
#################################################
#   __ _      _        _    ____                #
#  / _(_) ___| |__    / \  |  _ \               #
# | |_| |/ __| '_ \  / _ \ | |_) |               #
# |  _| | (__| | | |/ ___ \|  _ <               #
# |_| |_|\___|_| |_/_/   \_\_| \_\               #
#                                               #
# SISTEMA DE CUMPLIMIENTO LEGAL ARGENTINA 2026  #
#################################################
```

### Estándares

- Tests unitarios y E2E.
- Linter (ESLint/equivalente) y formateador.
- CI/CD con checks automáticos.
- Documentación de API (OpenAPI/Swagger).

---

## 13. Plan de Despliegue

| Componente | Infraestructura |
|------------|-----------------|
| Base de datos + Auth | Supabase Cloud |
| API Backend | Render, Railway o similar (Go/Node) |
| Frontend Web | Vercel, Netlify o mismo servidor |
| Mobile | App Store, Google Play |
| Desktop | Landing con descarga .exe, .dmg, .deb (binarios firmados) |

### Reportes Programados

- Cron job en backend (ej. día 1 de cada mes).
- Generar Excel según configuración del empleador.
- Enviar por email (SendGrid, AWS SES) a direcciones configuradas.

---

## 14. "Sabías que..." — Cultura Legal

Mensajes breves durante carga o splash:

- *"¿Sabías que el Art. 198 exige un descanso de 12h entre jornadas? fichAR te cuida."*
- *"La reforma de 2026 permite que tus horas extra se acumulen en un banco de horas por hasta un año."*
- *"Tu empleador debe registrar tus horas de forma fehaciente. Con fichAR, tenés trazabilidad."*
- *"El descanso semanal mínimo es de 35 horas corridas."*

---

## 15. Hoja de Ruta Sugerida

### Fase 1 — MVP (3-4 meses)

1. Auth (email/contraseña, 2FA básico).
2. Fichaje con geolocalización y lugares de trabajo.
3. Dashboard empleado (banco de horas simple).
4. Panel Admin: empleados, lugares, reporte Excel básico.
5. App mobile (Flutter) + Web (Flutter Web).

### Fase 2 — Crecimiento (2-3 meses)

6. Licencias con adjuntos y flujo de aprobación.
7. Roles Supervisor.
8. Alertas (descanso 12h, fichaje fuera de zona).
9. Tareas y timesheet.
10. Reportes programados por email.
11. Desktop (Tauri).

### Fase 3 — Escala (2-3 meses)

12. Integración ARCA (si API disponible).
13. Webhooks e integraciones.
14. Modo low-end optimizado.
15. Auditoría forense (rol Auditor).
16. OCR para certificados médicos.

---

## Anexos

### A. Glosario

- **ARCA**: Agencia de Recaudación y Control Aduanero (ex-AFIP en materia laboral).
- **RLS**: Row Level Security (PostgreSQL).
- **RIFL**: Régimen de Incentivo a la Formalización Laboral.
- **FAL**: Fondo de Asistencia Laboral.
- **LCT**: Ley de Contrato de Trabajo 20.744.

### B. Documentos de Definición (Fuente de Verdad)

**Regla:** No escribir código sin definición explícita en estos documentos.

| Documento | Contenido |
|-----------|-----------|
| [PANTALLAS.txt](./PANTALLAS.txt) | Cada pantalla: campos, estados, validaciones, flujos |
| [CONFIGURACIONES.txt](./CONFIGURACIONES.txt) | Cada opción configurable, defaults, dependencias |
| [CASOS-LIMITE.txt](./CASOS-LIMITE.txt) | Edge cases con comportamiento exacto |
| [ROLES.txt](./ROLES.txt) | Matriz completa de permisos por rol |
| [SEGURIDAD.txt](./SEGURIDAD.txt) | Requisitos de seguridad exhaustivos |
| [INTEGRACIONES.txt](./INTEGRACIONES.txt) | Formatos, protocolos, adaptadores |
| [FRONTEND.txt](./FRONTEND.txt) | Colores, look & feel, dos apps (low-end vs high-end) |
| [ESCALABILIDAD.txt](./ESCALABILIDAD.txt) | Atributos custom (JSONB), endpoint schema |
| [PERSONALIZACION-EMPLEADOR.txt](./PERSONALIZACION-EMPLEADOR.txt) | Banco horas, vencimientos, intercambio jornada |
| [ROL-AUDITOR-JUICIOS.txt](./ROL-AUDITOR-JUICIOS.txt) | Rol oculto para peritajes y juicios laborales |
| [ANALISIS-REPORTES.txt](./ANALISIS-REPORTES.txt) | Gráficos, XLSX multi-hoja, extracciones |
| [LIMITACIONES-ALERTAS.txt](./LIMITACIONES-ALERTAS.txt) | Intercambio jornada, alertas configurables |
| [MODULO-PROYECTOS.txt](./MODULO-PROYECTOS.txt) | Cliente→Proyecto→Tarea (opcional, desactivable) |
| [MEJORAS-FUNCIONALIDADES.txt](./MEJORAS-FUNCIONALIDADES.txt) | Ideas adicionales |
| [OPTIMIZACION.txt](./OPTIMIZACION.txt) | Performance, batería, mejores prácticas |
| [PROGRAMADOR-SETUP.txt](./PROGRAMADOR-SETUP.txt) | Setup Debian 12, Bun vs Yarn, instalación |
| [VERIFICACION-FICHAR-FIRTS.txt](./VERIFICACION-FICHAR-FIRTS.txt) | Checklist contra requisitos originales |
| [TESTING-DOCUMENTACION.txt](./TESTING-DOCUMENTACION.txt) | Estrategia de tests, documentación oficial |

### C. Setup del Sistema de Skills

Para configurar el agente orquestador y skills personalizadas:

- [PROMPT_SETUP_FICHAR_SKILLS_SYSTEM.md](./PROMPT_SETUP_FICHAR_SKILLS_SYSTEM.md) — Prompt para generar AGENTS.md y skills

### D. Referencias Externas

- [Reforma Laboral Proyecto con cambios Senado](./Reforma-Laboral-Proyecto-con-cambios-Senado.txt)
- [fichAR — Primer documento de ideas](./fichAR-firts-txt.txt)
- [ARCA — Servicios empleadores](https://www.argentina.gob.ar/arca/empleadores)
- [Ley 27.553 — Firma digital](https://www.argentina.gob.ar/justicia/derechofacil/leysimple/firma-digital)

---

*Documento vivo. Actualizar según evolución del proyecto y de la normativa.*
