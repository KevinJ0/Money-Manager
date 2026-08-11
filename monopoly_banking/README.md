# Money Manager

<p align="center">
  <img src="assets/icon/app_icon.png" alt="Money Manager" width="120" height="120">
</p>

**Money Manager** es una aplicación de **banca digital P2P offline** para jugar juegos de mesa (Money Manager, Monopoly y variantes) con dinero virtual. Funciona **sin internet**: los jugadores conectan sus celulares a un dispositivo central ("el Banco") y gestionan saldos, transferencias, inversiones y premios en tiempo real.

> Toda la interfaz, los anuncios por voz y los textos están en **español**.

---

## Contenido

- [Características](#características)
- [Cómo funciona](#cómo-funciona)
- [Tecnologías](#tecnologías)
- [Plataformas soportadas](#plataformas-soportadas)
- [Guía de instalación](#guía-de-instalación)
  - [Android (APK)](#android-apk)
  - [Windows (instalador)](#windows-instalador)
  - [Desde código fuente](#desde-código-fuente)
- [Monitoreo y errores](#monitoreo-y-errores)
  - [Sentry](#sentry)
  - [Shorebird (actualizaciones OTA)](#shorebird-actualizaciones-ota)
- [CI/CD y releases automáticos](#cicd-y-releases-automáticos)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Solución de problemas](#solución-de-problemas)
- [Licencia](#licencia)

---

## Características

### Roles

| Rol | Descripción |
|---|---|
| **Banco** | Dispositivo que aloja el servidor, gestiona los saldos de todos los jugadores y aprueba transferencias. |
| **Jugador / Cliente** | Se conecta al banco, ve su cartera, envía dinero, pasa GO e invierte en la bóveda. |

### Funciones principales

- **Transferencias en tiempo real** entre jugadores con confirmación por parte del banco.
- **Modo "PASS GO"**: botón para avanzar, cobra `$200` (configurable) con sonido y vibración.
- **Bóveda (Vault)**: invierte dinero para generar interés a lo largo de 1 a 5 pasadas por GO (5–15 % de interés). Retiro anticipado con 80 % de penalización.
- **Niveles de tarjeta**: Standard `$0` → Gold `$4k` → Platinum `$8k` → Black `$15k`, con confeti al subir de nivel.
- **Historial de transacciones** con gráfica de balance (`fl_chart`).
- **Cuentómetro animado** para el balance (efecto odómetro).
- **Autenticación biométrica** para transferencias grandes (> `$5,000`).
- **Sonidos y música** de fondo (`audioplayers`) + **anuncios por voz** (`flutter_tts`).
- **Almacenamiento local cifrado** con Hive + AES (clave guardada en `flutter_secure_storage`).
- **Transmisión P2P múltiple**: TCP por Wi-Fi, NFC o Bluetooth Low Energy (BLE).

### Modos de conexión

| Transporte | Uso | Prioridad |
|---|---|---|
| **TCP / Wi-Fi** | El banco levanta un servidor en el puerto `8080` y los clientes se conectan por IP local. | Primario |
| **NFC** | Contacto físico entre teléfonos para traspasos directos. | Alternativo |
| **BLE** | Descubrimiento y conexión entre dispositivos cercanos. | Respaldo |

---

## Tecnologías

| Capa | Tecnología |
|---|---|
| Framework | Flutter (Dart ≥ 3.4) |
| Estado | `provider` + `ChangeNotifier` |
| Almacenamiento | Hive cifrado + `flutter_secure_storage` |
| Red | Sockets TCP, WebSocket propio, `flutter_reactive_ble`, `nfc_manager` |
| Sonido | `audioplayers`, `flutter_tts` |
| Servicios en segundo plano | `flutter_background_service` |
| Monitoreo | `sentry_flutter` + plugin nativo de Android |
| OTA | Shorebird (código push) |
| Otros | `qr_flutter`, `mobile_scanner`, `sensors_plus`, `confetti`, `flutter_animate`, `fl_chart` |

---

## Plataformas soportadas

| Plataforma | Soporte | Artefacto |
|---|---|---|
| Android | ✅ | APK / AAB firmado |
| Windows | ✅ | Ejecutable + instalador Inno Setup |
| iOS | 🟡 | Código y config listos (requiere Xcode en macOS) |

---

## Guía de instalación

### Android (APK)

1. Entra a la pestaña **Releases** de este repositorio.
2. Descarga `MoneyManager-v<version>.apk` de la última versión `android-v*`.
3. En el celular, habilita *Instalar apps desconocidas* para el navegador o administrador de archivos.
4. Abre el APK e instala.

> Si solo distribuyes en Google Play, en el mismo release encontrarás el **AAB** (`MoneyManager-v<version>.aab`) para subirlo a la consola de Play.

### Windows (instalador)

1. Entra a la pestaña **Releases** de este repositorio.
2. Descarga `MoneyManager-Setup-<version>.exe` de la última versión `desktop-v*`.
3. Ejecuta el instalador. Se instalará en `C:\Program Files\Money Manager`.
4. Abre la app desde el menú de inicio o el acceso directo del escritorio.

> Requiere **Windows 10/11 de 64 bits**.

### Desde código fuente

#### Requisitos

- Flutter SDK `>= 3.4.0` (`< 4.0.0`)
- Dart SDK (incluido con Flutter)
- Android SDK (para builds de Android)
- Xcode (solo iOS / macOS)

#### Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/KevinJ0/Money-Manager.git
cd Money-Manager/monopoly_banking

# 2. Instalar dependencias
flutter pub get

# 3. (Opcional) Regenerar adaptadores de Hive si cambiaste algún modelo
dart run build_runner build --delete-conflicting-outputs

# 4. (Opcional) Regenerar íconos si cambiaste assets/icon/app_icon.png
dart run flutter_launcher_icons
```

#### Ejecutar

```bash
# Ver dispositivos disponibles
flutter devices

# Ejecutar en un dispositivo o emulador
flutter run -d <device_id>
```

#### Compilar

```bash
# APK (release)
flutter build apk --release

# App Bundle (Google Play)
flutter build appbundle

# Windows (ejecutable)
flutter build windows --release
```

---

## Monitoreo y errores

### Sentry

La app integra **Sentry** para reportar errores y crashes a la nube, tanto en Dart como en el nativo de Android (con mapas de símbolos para desofuscar stack traces).

- El DSN se inyecta en **compilación** mediante `--dart-define`:

```bash
flutter build apk --release --dart-define=SENTRY_DSN=https://xxx@sentry.io/yyy
```

- Si **no** se provee `SENTRY_DSN`, la app se ejecuta normalmente sin Sentry y los errores se imprimen en consola (`debugPrint`).
- El log local en el dispositivo fue **eliminado**; toda la telemetría va a Sentry.

| Qué se captura | Detalle |
|---|---|
| Errores de Flutter (`FlutterError`) | Excepciones de widgets y build |
| Errores no capturados | `PlatformDispatcher.onError` |
| Errores de inicio | Fallos durante la inicialización de servicios |
| Errores traducidos | Errores mostrados al usuario vía `showFriendlyError` |
| Breadcrumbs | Eventos de operaciones (transferencias, confirmaciones, inicio) |

### Shorebird (actualizaciones OTA)

**Shorebird** permite enviar actualizaciones de código a los usuarios **sin publicar una nueva versión** en la Play Store o sin reenviar el APK. Solo el código Dart cambia; el binario nativo permanece intacto.

- El `app_id` está en `shorebird.yaml` (no es secreto).
- Las actualizaciones se aplican **automáticamente** al iniciar la app (`auto_update` está activado por defecto).

```bash
# Iniciar Shorebird en el proyecto (solo la primera vez)
shorebird init

# Publicar una versión de release para Android (requiere DSN si quieres Sentry en el release)
shorebird release android -- --dart-define=SENTRY_DSN=<tu_dsn>

# Publicar un parche OTA sobre el último release
shorebird patch android
```

> El token de Shorebird se guarda como secreto `SHOREBIRD_TOKEN` en el repositorio; el flujo de parches también está automatizado (ver [CI/CD](#cicd-y-releases-automáticos)).

---

## CI/CD y releases automáticos

Los workflows viven en `.github/workflows/` y se disparan automáticamente al crear **tags**:

| Workflow | Se dispara con | Artefactos |
|---|---|---|
| `android-github-release.yml` | Tag `android-v*` | APK + AAB firmados, Release en GitHub |
| `desktop-release.yml` | Tag `desktop-v*` | Instalador `.exe`, Release en GitHub |
| `shorebird-patch.yml` | Manual (workflow_dispatch) | Parche OTA de Android |

### Crear un release

```bash
# Subir versión (ej. 1.1.0)
# En pubspec.yaml: version: 1.1.0+3

git add pubspec.yaml
git commit -m "chore: subir version a 1.1.0"

# Tags de release (el workflow detecta la versión desde pubspec.yaml)
git tag android-v1.1.0
git push origin android-v1.1.0

git tag desktop-v1.1.0
git push origin desktop-v1.1.0
```

### Secretos requeridos por los workflows

| Secreto | Uso |
|---|---|
| `KEYSTORE_BASE64` | Keystore de firma Android codificado en base64 |
| `KEYSTORE_PASSWORD` | Contraseña del keystore |
| `KEYSTORE_ALIAS` | Alias de la clave |
| `SENTRY_DSN` | DSN de Sentry para inyectar en el build |
| `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` | Subida de símbolos de depuración |
| `SHOREBIRD_TOKEN` | Publicación de releases/parches OTA |

---

## Estructura del proyecto

```
monopoly_banking/
├── lib/
│   ├── main.dart                  # Punto de entrada: Sentry, servicios, runApp
│   ├── app.dart                   # MultiProvider + enrutado raíz
│   ├── core/                      # Constantes, tema, transiciones
│   ├── models/                    # Modelos Hive (sesión, transacciones, usuario)
│   ├── providers/                 # WalletController, SessionProvider, StatsProvider...
│   ├── screens/                   # Pantallas por rol y flujo
│   │   ├── bank/                  # Banco (diálogos, conexión, builders)
│   │   ├── player/                # Jugador (incoming, conexión, diálogos)
│   │   └── wallet/                # Cartera (bóveda, paneles, mixins)
│   ├── services/                  # Red, transporte, sonido, voz, auditoría
│   │   └── transports/            # TCP, WebSocket, modelos WS
│   └── widgets/                   # Widgets reutilizables
├── android/                       # Proyecto Android (firma, splash, BLE nativo)
├── windows/                       # Proyecto Windows + instalador Inno Setup
├── ios/                           # Proyecto iOS
├── assets/                        # Sonidos, íconos, fuentes
├── shorebird.yaml                 # Config de Shorebird (app_id)
└── pubspec.yaml                   # Dependencias y versionado
```

### Pantallas principales

| Ruta lógica | Pantalla | Rol |
|---|---|---|
| `/` | Splash animado con confeti | Ambos |
| `/role` | Selección de rol (Banco / Jugador) + avatar y color | Ambos |
| `/bank` | Panel del banco: lista de jugadores, transferencias | Banco |
| `/player` | Cartera del jugador: saldo, transferir, PASS GO, bóveda | Jugador |
| `/winner` / `/kicked` | Fin de partida y expulsiones | Ambos |

---

## Solución de problemas

| Problema | Solución |
|---|---|
| `Connection refused` al conectar | Inicia primero la app del **banco** y verifica que ambos estén en la misma red Wi-Fi. |
| Error de descifrado de Hive | Borra los datos de la app o reinstálala. |
| NFC no funciona | Activa NFC en el celular; algunos emuladores no lo soportan. |
| BLE no encuentra dispositivos | En Android, BLE requiere permiso de **ubicación** para escanear. |
| Errores de build | Ejecuta `flutter clean` y luego `flutter pub get`. |
| Los crash se ven en la consola pero no en Sentry | Compila con `--dart-define=SENTRY_DSN=<tu_dsn>`. |

---

## Licencia

Proyecto privado. El código fuente no se distribuye con licencia de uso libre; consulta al mantenedor para cualquier uso externo.

---

<p align="center">
  Hecho con Flutter · Money Manager
</p>
