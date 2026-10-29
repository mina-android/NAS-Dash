# NAS Dash AI Agent Instructions & Guidelines

This document outlines mandatory project-specific rules, requirements, and conventions for AI assistants working on **NAS Dash** (`com.ma.nasdash`). For full architectural guidelines and complete API references, refer to [`AI_INSTRUCTIONS.md`](AI_INSTRUCTIONS.md), [`CLAUDE.md`](CLAUDE.md), and [`STRUCTURE.md`](STRUCTURE.md).

---

## 1. Mandatory Workflow & Documentation Rules

1. **Mandatory Documentation Synchronization**:
   - After **any** task execution, code change, bugfix, schema adjustment, or configuration update, **every `.md` documentation file** in the project must be actively reviewed and updated to reflect the changes:
     - [`README.md`](README.md): App overview, feature list, developer instructions, release tables.
     - [`STRUCTURE.md`](STRUCTURE.md): Architecture diagrams, data models, state flows, layer division.
     - [`CHANGELOG.md`](CHANGELOG.md): Comprehensive itemized changelog under the active version.
     - [`AGENTS.md`](AGENTS.md): Project rules and behavioral constraints.
     - [`AI_INSTRUCTIONS.md`](AI_INSTRUCTIONS.md): Detailed architectural rules and coding standards.
     - [`CLAUDE.md`](CLAUDE.md): Fast-lookup project reference, API surface, directory tree.
     - [`AUDIT_FIX_PLAN.md`](AUDIT_FIX_PLAN.md): Enterprise audit matrix, security verification, code health.
     - `release_notes_*.md`: Detailed version release notes.
2. **Changelog Maintenance**:
   - All feature additions, bugfixes, UI refinements, native modifications, and schema updates must be recorded in [`CHANGELOG.md`](CHANGELOG.md) under the active version section (`1.0.0+1`).
3. **AI Rules Maintenance**:
   - Any new project conventions, API discoveries, or architectural constraints must be preserved in this file and reflected across companion documentation files.

---

## 2. Critical Architectural Rules & Safety Guardrails

1. **Package Identity**:
   - Flutter package name and Android Application ID must strictly remain `com.ma.nasdash`.
2. **TrueNAS Transport Security (CRITICAL)**:
   - **Never** allow API keys to be sent over plain HTTP (`http://`) or unencrypted WebSockets (`ws://`). TrueNAS SCALE 25.04+ middleware permanently revokes API keys passed over insecure channels.
   - Always route REST API calls through `https://` and WebSocket subscriptions through `wss://` with proper self-signed TLS certificate handling via `BadCertificateCallback` pinning.
3. **Storage & Dataset Safety Guardrails (CRITICAL)**:
   - Pool and Dataset modification/deletion operations are **strictly prohibited** in the UI to prevent catastrophic data loss.
   - Storage actions are strictly restricted to **Read-Only Inspection** (Pool topology, VDEV status, disk temperatures, dataset properties, and OS boot pool wear & health). Manual snapshot creation buttons are omitted from the UI to preserve strict read-only safety.
4. **4-Tab Navigation & Shell Architecture**:
   - The primary navigation consists strictly of 4 tabs: **Dashboard**, **Storage**, **Apps**, and **Settings** (with System and Settings unified).
   - SMB file manager frontend and SMB credential setup are completely excluded from the app shell.
5. **State Management & Architecture**:
   - State management: `flutter_riverpod` (v2.x) with immutable state models.
   - Networking: `dio` (with custom TLS adapter) and `web_socket_channel`.
   - Charts & Telemetry: `fl_chart` with smooth cubic splines and 20-sample rolling memory buffers.
   - Persistence: `shared_preferences` for non-sensitive UI layouts/theming, `flutter_secure_storage` for credentials and API keys.
6. **Biometric Security Guard**:
   - High-impact system actions (Server Reboot, Server Shutdown) must be guarded behind `LocalAuthentication` biometric/device credential verification.
7. **NetBird VPN Smart Failover & Host Rewriting**:
   - The app must support dual connection profiles: primary LAN host (e.g. `https://192.168.1.11`) and fallback VPN host (e.g. `https://100.102.141.91`).
   - Web portal URLs reported by TrueNAS Apps must dynamically rewrite their host to match the currently connected profile host so portal links resolve seamlessly over remote VPN.
8. **Material 3 Adaptive Theming, Space Grotesk & Butter-Smooth Performance**:
   - The application UI must strictly adhere to Material 3 styling, utilizing `dynamic_color` for Android 12+ wallpaper color extraction in both light and dark themes with in-app ThemeMode control (System / Dark / Light).
   - Space Grotesk (`google_fonts`) is the mandatory app-wide typeface.
   - All interactive elements, cards, buttons, dialogs, and sheets must feature continuous rounded corners (16–24dp). To prevent GPU scrolling stutter, `GlassCard` uses hardware-accelerated container surfaces with subtle borders, reserving blur effects for floating chrome and bottom sheets.
9. **Android Adaptive & Notification Icon Compliance**:
   - The normal colored launcher icon is generated from `assets/app_icon.png` with foreground (`ic_launcher_foreground.png`) scaled strictly at **51% canvas height** centered on solid `#FFFFFF` so all corners fit safely inside Android's circular mask, and legacy launcher icons (`ic_launcher.png`, `ic_launcher_round.png`) at **66% canvas height** on solid `#FFFFFF`.
   - Android themed monochrome adaptive icons (`ic_launcher_monochrome.png` at **51% canvas height**) and status bar notification icons (`ic_notification` at full-width **90% glyph scale**) are generated exclusively from `assets/adaptive_icon.png` (pure white `#FFFFFF` pixels with transparent cutout lines) and protected by `res/raw/keep.xml` and `isShrinkResources = false`.
10. **Fail-Safe Startup & KeyStore Resilience**:
   - `runApp()` must be invoked immediately in `main()` without being blocked by background network or notification initialization, with `HttpOverrides.global` configured for self-signed TLS image/SVG loading.
   - Notification permissions (`requestPermissions()`) must never be requested before `runApp()`: defer to `WidgetsBinding.instance.addPostFrameCallback` in `AppShell` where the Android Activity is guaranteed to be attached.
   - `FlutterSecureStorage` must enable `encryptedSharedPreferences: true` and `resetOnError: true` with bounded timeouts to prevent Android KeyStore deadlocks.
   - Global `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `ErrorWidget.builder` handlers must always be registered to prevent black screen rendering crashes.
11. **Collapsible Dashboard & Frosted Chrome**:
   - Dashboard items must use `CollapsibleDashboardCard` collapsing into single-line summaries via header-row tap with a hardware-accelerated `AnimatedCrossFade` and `RepaintBoundary` for 120fps butter-smooth non-laggy expand/collapse animations, with collapsed states persisted in `SharedPreferences`.
   - Uptime values in telemetry summaries must have subsecond/microsecond decimals stripped (`.split('.').first.trim()`) to prevent erratic number artifacts.
   - Top and bottom navigation chrome must feature frosted translucent glass blur (`FrostedAppBar` and `NavigationBar` with `sigma: 18`) and `extendBodyBehindAppBar: true` while preserving 120fps butter-smooth scrolling.
   - Settings sections must use uniform neutral monochrome icons (`colorScheme.onSurfaceVariant`) without colored icon backgrounds.
