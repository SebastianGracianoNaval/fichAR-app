# fichAR

Sistema de Gestión y Administración de Cumplimiento Laboral para empresas y PyMEs argentinas.

## Descripción

fichAR permite el registro digital de entrada y salida (fichaje) con geolocalización, banco de horas, control de jornada y cumplimiento de la Ley de Contrato de Trabajo y la Reforma Laboral 2026. Los datos están diseñados para ser admisibles en juicios laborales. Diseñado bajo estándares ISO 27001 (ver documentation/tecnica/ISO-27001-ALIGNMENT.md).

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
└── documentation/       Documentación oficial (uso y técnica)
```

## Documentación

La documentación oficial está en **documentation/**:

- **documentation/uso/** — Documentación general de uso de la aplicación
- **documentation/tecnica/** — Documentación técnica para modificar y desarrollar

Los markdowns se irán añadiendo conforme avance el proyecto.

## Desarrollo

El proyecto está en fase inicial. Consultar la documentación técnica para el orden de implementación.

## Licencia

Privado. Todos los derechos reservados.
