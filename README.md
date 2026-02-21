# fichAR

Sistema de Gestión y Administración de Cumplimiento Laboral para empresas y PyMEs argentinas.

## Descripción

fichAR permite el registro digital de entrada y salida (fichaje) con geolocalización, banco de horas, control de jornada y cumplimiento de la Ley de Contrato de Trabajo y la Reforma Laboral 2026. Los datos están diseñados para ser admisibles en juicios laborales.

**Filosofía:** Código de Grado Bancario, Interfaz de Grado Humano.

## Requisitos

- Bun 1.0+
- Flutter 3.x
- Supabase (cuenta)
- Node 20 LTS (alternativa a Bun)

## Estructura del proyecto

```
fichar-app/
├── apps/
│   ├── mobile/          Flutter iOS/Android
│   └── web/             Flutter Web
├── packages/
│   ├── api/             Backend (Bun/Node)
│   └── shared/          Tipos y constantes compartidos
├── supabase/            Migraciones y configuración
├── definiciones/        Especificaciones detalladas
├── clean_definitions/   Documentación consolidada
└── docs/                Guías de desarrollo
```

## Documentación

- **clean_definitions/FICHAR-DEFINICION-COMPLETA.txt** - Referencia única del producto
- **clean_definitions/INDICE-REFERENCIAS.txt** - Índice de todos los documentos
- **clean_definitions/PLAN-CRONOLOGICO-DESARROLLO.txt** - Plan de desarrollo por fases
- **docs/getting-started.md** - Setup paso a paso

## Desarrollo

El proyecto está en fase inicial. Consultar el plan cronológico para el orden de implementación.

## Licencia

Privado. Todos los derechos reservados.
