# AI Instructions for NAS Dash

This document contains critical project context, architectural guidelines, and specific rules that AI coding assistants (Claude, Gemini, Antigravity, etc.) must follow when working on the NAS Dash codebase.

> For the full architectural reference — data models, REST/WebSocket schemas, Riverpod provider API surface, and known issues — see **[`CLAUDE.md`](CLAUDE.md)** and **[`STRUCTURE.md`](STRUCTURE.md)**. This file is the condensed, rules-first companion. If any document conflicts with code, verify against live TrueNAS SCALE API schemas.

---

## 1. Project Context & Stack

- **Application Name:** NAS Dash
- **Package Identity:** `com.ma.nasdash` (Flutter package name and Android Application ID)
- **Version:** `1.0.0+1` (`pubspec.yaml`)
- **Target OS:** Android only (minSdk 26 / Android 8.0 Oreo+, compileSdk 36, targetSdk 36)
- **Toolchain:** Flutter `3.47.6` / Dart `3.13.5`, Java JDK 21 LTS, Gradle 8.12, AGP 8.9.0, Kotlin 2.1.0 with Android Core Library Desugaring (`desugar_jdk_libs:2.1.5`).
- **Target Backend:** TrueNAS SCALE (tested against TrueNAS SCALE `25.10.7` / Dragonfish & Electric Eel on Linux kernel 6.12+).
- **State Management:** `flutter_riverpod` (v2.x). Providers and `StateNotifier` manage server telemetry, storage metrics, alert streams, apps, and theme preferences.
- **Networking:**
  - `dio` for secure HTTPS REST API communication with pinned self-signed certificate handling.
  - `web_socket_channel` for bidirectional real-time JSON-RPC (`core.subscribe`, `alert.list`, `reporting.realtime`).
- **UI & Theming:**
  - Native Android Material 3 with `dynamic_color` system wallpaper palette adaptation in both Light and Dark modes.
  - In-app ThemeMode switcher (System / Dark / Light) and Dynamic Colors toggle in Settings.
  - `google_fonts` (`Space Grotesk`) provides app-wide typography.
  - High-performance `GlassCard` containers (eliminating card `BackdropFilter` to avoid GPU rasterization lag) and frosted glass blur across navigation chrome (`FrostedAppBar` and `NavigationBar` with `sigma: 18`) and sheets.
  - 4 primary navigation destinations: **Dashboard**, **Storage**, **Apps**, and **Settings** (System and Settings merged).
  - App Launcher Icon: Vibrant 3D color foreground (`ic_launcher_foreground.png`) scaled to 51% canvas height on solid white `#FFFFFF`.
  - Adaptive Homescreen Icon (Android 13+): Monochrome themed icon (`ic_launcher_monochrome.png`) with clean cutouts generated from `assets/adaptive_icon.png` at 51% canvas height.
  - Status Bar Notification Icon: Full-width 90% glyph scale pure white silhouette with transparent cutouts generated from `assets/adaptive_icon.png` in `@drawable/ic_notification`.
- **Background & Notifications:**
  - `flutter_local_notifications` for high-priority alert notifications with in-notification `Dismiss` action button.
  - `workmanager` running periodic background alert checks (15-minute intervals) using fallback REST API polling.
- **Security:**
  - `flutter_secure_storage` for AES-encrypted credential and API token storage.
  - `local_auth` for biometric fingerprint / face / PIN confirmation before disruptive power actions (Reboot/Shutdown).

---

## 2. Core Architectural Rules

### 2.1 Mandatory Documentation Rule
- **Every AI assistant and developer must update all `.md` documentation files** (`README.md`, `STRUCTURE.md`, `CHANGELOG.md`, `AGENTS.md`, `AI_INSTRUCTIONS.md`, `CLAUDE.md`, `AUDIT_FIX_PLAN.md`, `release_notes_*.md`) upon completing any task, feature implementation, refactoring, or bugfix.

### 2.2 Transport Security & TrueNAS Key Safety (CRITICAL)
- **Zero Insecure Transports:** Under NO circumstances should any API call or WebSocket connection be initiated over unencrypted `http://` or `ws://`. TrueNAS SCALE 25.04+ actively revokes any user API key passed over plain HTTP.
- **Certificate Handling:** Always configure Dio `HttpClientAdapter` with `badCertificateCallback = (cert, host, port) => true` (or custom SHA-256 fingerprint matching) to allow secure self-signed HTTPS connections without dropping encryption.
- **WebSocket Security:** WebSocket URLs must strictly use `wss://<host>/websocket`.

### 2.3 Storage Safety Guardrails (CRITICAL)
- **No Destructive Storage UI:** The application is explicitly prohibited from exposing pool destruction, pool deletion, dataset deletion, or VDEV detachment.
- **Permitted Operations:**
  - Read-only pool inspection, topology tree, and disk health metrics.
  - Read-only dataset browsing and space usage analysis.
  - Read-only OS boot pool wear and scrub monitoring.
  - Manual snapshot creation UI is excluded to maintain strict read-only safety.

---

## 4. Startup Sequence & Android Native Asset Conventions

- **Fail-Safe Startup:**
  - `main()` must never await blocking native or permission methods prior to `runApp()`.
  - Notification and background workers initialize asynchronously in `try/catch` wrappers.
  - Runtime notification permission prompt occurs post-first-frame in `AppShell` with an attached Activity.
  - Register `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `ErrorWidget.builder` to prevent silent black screen freezes.
- **Adaptive Launcher & Status Bar Icons:**
  - The normal launcher icon is generated from `assets/app_icon.png` with foreground (`ic_launcher_foreground.png`) scaled strictly at **51% canvas height** on a permanent `#FFFFFF` white background, and legacy icons (`ic_launcher.png`, `ic_launcher_round.png`) at **66% canvas height** on solid white.
  - Homescreen adaptive monochrome icons (`ic_launcher_monochrome.png` at **51% canvas height**) and status bar notification icons (`ic_notification` at full-width **90% glyph scale**) are generated exclusively from `assets/adaptive_icon.png` (pure white `#FFFFFF` pixels with transparent cutout lines) and protected by `res/raw/keep.xml` and `isShrinkResources = false`.
- **Collapsible Dashboard & Advanced Settings:**
  - Dashboard cards support header-row tap collapse/expand with a hardware-accelerated `AnimatedSize` and `RepaintBoundary` for 120fps butter-smooth non-laggy animations into single-line status summaries with states saved in `SharedPreferences`.
  - Uptime values in telemetry summaries have microsecond decimals stripped (`.split('.').first.trim()`) to prevent erratic number artifacts.
  - Settings uses neutral monochrome section icons (`colorScheme.onSurfaceVariant`) and includes instant SMB Share toggles, username-resolved Filesystem ACL inspector, Host Power History with formatted operation dates, Created Users, and Advanced Controls & Telemetry sheets (Storage pool warning slider, Active jobs monitor, Boot pool SSD health, and App container resources).
