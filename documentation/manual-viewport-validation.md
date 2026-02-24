# Manual Viewport Validation

Validacion manual de layouts en viewports 375px, 768px y 1920px. Alineado con plan-phase-5b, definiciones/FRONTEND.md.

## Como ejecutar

### Opcion A - Flutter web

```bash
cd apps/mobile && flutter run -d chrome
```

Redimensionar la ventana del navegador o usar DevTools device toolbar para 375, 768, 1920.

### Opcion B - Chrome DevTools

- F12 para abrir DevTools
- Toggle device toolbar (Ctrl+Shift+M / Cmd+Shift+M)
- Seleccionar dispositivo o fijar ancho manual a 375, 768, 1920

### Opcion C - device_preview (disponible en main.dart)

La app usa DevicePreview en modo no-release. Se puede alternar entre dispositivos desde la UI.

## Checklist por viewport

| Viewport | Ancho | Target | Verificar |
|----------|-------|--------|-----------|
| Mobile | 375px | iPhone SE, Android pequeno | Contenido legible, sin overflow horizontal; padding 16px; max-width respetado |
| Tablet | 768px | iPad | Padding 24px; contenido centrado; listas/formularios max 560 |
| Desktop | 1920px | Monitor grande | Contenido centrado, max 560; lineas de texto no estiradas |

## Flujo de smoke manual (por plan-phase-5)

1. Login (credenciales validas)
2. Dashboard (Fichar visible, layout OK)
3. Licencias (lista o vacio, formulario abre)
4. Perfil (tarjeta perfil, dispositivos)
5. Reportes (form, date pickers, boton export)
6. Admin (si rol lo permite): Empleados, Lugares, Config

## Tabla de sign-off

| Viewport | Fecha | Tester | OK/Fail |
|----------|-------|--------|---------|
| 375px | | | |
| 768px | | | |
| 1920px | | | |
