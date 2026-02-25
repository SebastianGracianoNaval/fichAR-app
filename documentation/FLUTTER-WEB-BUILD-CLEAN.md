# Flutter Web: build limpio y verificación de tema

Referencia para compilaciones web limpias y comprobación de que el tema (verde/teal) se despliega correctamente.

---

## 1. Tema en código (estado actual)

- **Archivo:** `apps/mobile/lib/theme.dart`
- **Color primario:** `Color(0xFF0F766E)` = **teal/verde** (#0F766E).
- **Color secundario:** `Color(0xFF1E3A5F)` = azul oscuro (solo acentos, no primario).
- **Uso:** `app.dart` asigna `theme: ficharTheme` al `MaterialApp`. No hay `darkTheme` ni tema alternativo por plataforma.
- **Conclusión:** En el código fuente el tema principal está en **verde/teal**. No hay lógica que ponga el tema en azul para web.

---

## 2. Condicionales por plataforma (kIsWeb)

Los usos de `kIsWeb` en el proyecto **no** cambian el tema:

| Archivo | Uso |
|---------|-----|
| `reportes_screen.dart` | Comportamiento de exportación (si web, otro flujo). |
| `legal_audit_logs_screen.dart` | `if (!kIsWeb)` → opción de compartir en móvil. |
| `legal_audit_hash_chain_screen.dart` | `if (!kIsWeb)` → idem. |
| `legal_audit_dashboard_screen.dart` | `if (kIsWeb)` → mensaje o comportamiento solo web. |

Ninguno modifica `ThemeData` ni `colorScheme`. El azul que ves en Vercel no viene de condicionales de tema en el código.

---

## 3. Comandos: limpieza profunda y build web desde cero

Ejecutar desde la **raíz del monorepo** (`fichar-app/`).

```bash
# 1. Ir a la app Flutter
cd apps/mobile

# 2. Limpiar build de Flutter (borra build/ de este proyecto)
flutter clean

# 3. Borrar carpeta build por si algo quedó (redundante tras flutter clean, pero explícito)
rm -rf build

# 4. Limpiar caché global de Flutter (pub, artifacts, etc.)
flutter pub cache repair

# 5. Obtener dependencias de nuevo
flutter pub get

# 6. Build web en release (100% limpio)
flutter build web --release
```

El resultado estará en `apps/mobile/build/web/`.  
Para **Vercel**: el proyecto debe apuntar a esa carpeta como output (p. ej. `apps/mobile` como root y **Output Directory** = `build/web`), y el comando de build debe ser algo como:

```bash
cd apps/mobile && flutter clean && flutter pub get && flutter build web --release
```

Así cada deploy hace un build limpio y no reutiliza artefactos viejos.

---

## 3.1. "2K+ Problems" después de build / deploy

Si tras hacer `flutter clean`, `flutter build web --release` y subir a Vercel ves **miles de Problems** en el IDE, es normal: el analizador está contando diagnósticos en la carpeta **`build/`** que se acaba de regenerar (código generado, caches), no en tu código.

- **No te preocupes:** no son errores reales de tu app.
- **Solución rápida:** Command Palette (Ctrl/Cmd+Shift+P) → **"Dart: Restart Analysis Server"**. Tras reiniciar, el análisis vuelve a aplicar los excludes de `analysis_options.yaml` (`build/**`, `.dart_tool/**`) y los Problems bajan.
- **Recomendación:** No agregues la carpeta `build/` ni `build/web` al workspace al hacer `npx vercel --prod`; usá la terminal desde la raíz del repo o desde `apps/mobile` y ejecutá `cd build/web && npx vercel --prod` sin abrir esa ruta en el árbol de archivos.

---

## 4. Verificar en simulador o dispositivo (que mobile tiene los últimos cambios)

- **iOS Simulator:**  
  `cd apps/mobile && flutter run`  
  (elige el simulador si hay varios)

- **Android emulador o dispositivo:**  
  `cd apps/mobile && flutter run`  
  (selecciona el dispositivo que quieras)

- **Dispositivo físico con cable:**  
  Conectá el dispositivo, habilitá depuración USB y ejecutá de nuevo `flutter run`. Flutter usará el tema definido en `theme.dart` (verde/teal).

Si en el simulador/dispositivo ves el verde/teal, el código está bien y el problema en web es de build/caché o de qué build está sirviendo Vercel.

---

## 5. ¿fichar-app está pensado solo para mobile?

**No.** fichar-app es un **monorepo** con varios productos:

| Parte | Rol |
|-------|-----|
| **packages/api** | Backend REST (Bun). Usado por mobile y por integraciones. |
| **packages/shared** | Tipos y constantes compartidos (p. ej. API). |
| **apps/mobile** | App Flutter: **iOS, Android y Web**. Mismo código, mismo tema. |
| **apps/management** | Backoffice web (Next.js). Crear orgs, gestionar clientes. |
| **supabase** | Base de datos y auth. |

La app en `apps/mobile` está pensada como **multiplataforma** (móvil + web), no solo mobile. Ver `documentation/STACK-TECHNOLOGY.md` para el detalle del stack.
