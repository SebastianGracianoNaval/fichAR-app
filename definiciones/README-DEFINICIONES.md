# definiciones/ — Documentos de Especificación fichAR

**Regla absoluta:** Definir TODO antes de escribir una sola línea de código.

## Documento Raíz

- **[DEFINICION-PROYECTO-FICHAR.md](./DEFINICION-PROYECTO-FICHAR.md)** — Visión, stack, arquitectura, hoja de ruta. Punto de entrada.

## Especificaciones Detalladas

| Documento | Propósito |
|-----------|-----------|
| [PANTALLAS.txt](./PANTALLAS.txt) | Cada pantalla: ID, campos, estados, validaciones, acciones |
| [CONFIGURACIONES.txt](./CONFIGURACIONES.txt) | 50+ configs: ID, tipo, default, dependencias, impacto |
| [CASOS-LIMITE.txt](./CASOS-LIMITE.txt) | 36 edge cases: precondiciones, comportamiento exacto, mensajes |
| [ROLES.txt](./ROLES.txt) | Matriz acción × rol (Empleado, Supervisor, Admin, Auditor) |
| [SEGURIDAD.txt](./SEGURIDAD.txt) | Requisitos de seguridad exhaustivos |
| [INTEGRACIONES.txt](./INTEGRACIONES.txt) | Formatos, webhooks, ARCA, adaptadores legacy |
| [FRONTEND.txt](./FRONTEND.txt) | 3 paletas de colores, look & feel Duolingo, dos apps (low/high-end) |
| [ESCALABILIDAD.txt](./ESCALABILIDAD.txt) | Atributos custom JSONB, schema dinámico |
| [PERSONALIZACION-EMPLEADOR.txt](./PERSONALIZACION-EMPLEADOR.txt) | Banco horas, vencimientos, intercambio |
| [ROL-AUDITOR-JUICIOS.txt](./ROL-AUDITOR-JUICIOS.txt) | Rol oculto para juicios laborales |
| [ANALISIS-REPORTES.txt](./ANALISIS-REPORTES.txt) | XLSX multi-hoja, gráficos, datos raw |
| [LIMITACIONES-ALERTAS.txt](./LIMITACIONES-ALERTAS.txt) | Intercambio jornada configurable |
| [MODULO-PROYECTOS.txt](./MODULO-PROYECTOS.txt) | Cliente→Proyecto→Tarea (desactivable) |
| [MEJORAS-FUNCIONALIDADES.txt](./MEJORAS-FUNCIONALIDADES.txt) | Ideas adicionales |
| [OPTIMIZACION.txt](./OPTIMIZACION.txt) | Performance, batería, mejores prácticas |
| [PROGRAMADOR-SETUP.txt](./PROGRAMADOR-SETUP.txt) | Setup Debian 12, Bun vs Yarn |
| [VERIFICACION-FICHAR-FIRTS.txt](./VERIFICACION-FICHAR-FIRTS.txt) | Checklist requisitos originales |
| [TESTING-DOCUMENTACION.txt](./TESTING-DOCUMENTACION.txt) | Tests, documentación, troubleshooting |

## Fuentes Legales

- [Reforma-Laboral-Proyecto-con-cambios-Senado.txt](./Reforma-Laboral-Proyecto-con-cambios-Senado.txt)
- [fichAR-firts-txt.txt](./fichAR-firts-txt.txt) — Ideas iniciales

## Configurar Sistema de Skills y Agente

Para generar AGENTS.md y skills personalizadas, usar:

- **[PROMPT_SETUP_FICHAR_SKILLS_SYSTEM.md](./PROMPT_SETUP_FICHAR_SKILLS_SYSTEM.md)**

Copiar y pegar el contenido completo en Cursor. El agente creará:

- AGENTS.md (orquestador supremo)
- Skills en `.cursor/skills/`
- Subagents en `.cursor/rules/`

## Skills (se crean al ejecutar el prompt)

Las skills NO se crean manualmente. Al pegar el contenido de PROMPT_SETUP_FICHAR_SKILLS_SYSTEM.md en el chat de Cursor, el agente creará AGENTS.md, todas las skills y subagents. Todo en inglés.
