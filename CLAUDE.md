# NAS Dash — Project Reference for AI Assistants

> **Purpose:** This file gives a complete, code-verified picture of the NAS Dash Flutter app so an AI assistant can pick up work immediately without re-reading every source file.
> **Last synced with code:** v1.0.0+1 — Frosted Glass Top Bar Blur Across All 4 Screens, Space Grotesk UI, Cutout Adaptive & Notification Icons from `adaptive_icon.png`, 51% Scaled Colored App Icon, Smooth 120fps Collapsible Dashboard Animation, Fractional Uptime Formatting Fix, Streamlined Settings Screen (Pruned NIC Sheet), Compact `Row`-Based RAM & ZFS ARC Card, SVG & Raster App Icon Loading (`flutter_svg` + CDN Fallback), Username-Resolved SMB Share ACLs, Formatted Operation Dates in Host Power Log, Instant SMB Share Loading, and Neutral Monochrome Settings Icons.

---

## 1. Project Identity

| Field | Value |
|---|---|
| Package Name | `com.ma.nasdash` |
| Flutter Package | `nas_dash` |
| Version | `1.0.0+1` (`pubspec.yaml`) |
| Flutter SDK | `3.47.6` / Dart `3.13.5` |
| Android Toolchain | Gradle `8.12`, AGP `8.9.0`, Kotlin `2.1.0`, JDK 21 LTS |
| Android SDK Constraints | minSdk `26` (Android 8.0 Oreo), compileSdk `36`, targetSdk `36` |
| Platform | Android only |
| Backend Compatibility | TrueNAS SCALE 24.10+ (Electric Eel) & 25.04+ (Dragonfish / 25.10.7) |
| GitHub Repository | `https://github.com/mina-android/NAS-Dash` |
| Developer | `https://github.com/mina-android` |

---

## 2. Directory Architecture

```
c:\Projects\NAS Dash\
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # compileSdk 36, desugaring enabled, proguard rules, split per ABI
│   │   ├── proguard-rules.pro       # JCIFS keep rules, SLF4J warning suppression
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # INTERNET, USE_BIOMETRIC, POST_NOTIFICATIONS, VIBRATE, RECEIVE_BOOT_COMPLETED
│   │       └── res/
│   │           ├── mipmap-*         # ic_launcher, ic_launcher_round (66% scale), ic_launcher_foreground (51% scale), ic_launcher_monochrome (51% adaptive_icon.png cutouts)
│   │           ├── mipmap-anydpi-v26/ # ic_launcher.xml, ic_launcher_round.xml (<foreground>, <monochrome>)
│   │           └── drawable-*       # ic_notification (crisp 90% full-width adaptive_icon.png cutouts in pure white alpha mask)
├── lib/
│   ├── main.dart                    # App entry point, immediate runApp(), error boundaries, async background setup
│   ├── app_shell.dart               # Frosted glass 4-tab shell: Dashboard, Storage, Apps, Settings (post-frame permission request)
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_endpoints.dart   # TrueNAS SCALE REST endpoints
│   │   ├── network/
│   │   │   ├── truenas_http_client.dart # Dio client with badCertificateCallback for self-signed TLS & failover
│   │   │   └── truenas_ws_client.dart   # WebSocket client for JSON-RPC core.subscribe & real-time telemetry
│   │   ├── services/
│   │   │   ├── notification_service.dart     # flutter_local_notifications wrapper with @drawable/ic_notification & action dismiss
│   │   │   └── background_alert_worker.dart  # 15-minute periodic Workmanager callback for alerts
│   │   ├── theme/
│   │   │   ├── app_colors.dart      # Semantic brand accents & telemetry status colors
│   │   │   ├── app_theme.dart       # Material 3 ThemeData with GoogleFonts.spaceGrotesk and dynamic colors
│   │   │   └── theme_provider.dart  # ThemeSettings notifier (ThemeMode: system/dark/light, dynamic wallpaper colors)
│   │   └── widgets/
│   │       ├── frosted_app_bar.dart # Translucent frosted glass top AppBar across all 4 screens (120fps lag-free)
│   │       ├── glass_card.dart      # Hardware-accelerated Material 3 surface container with rounded border (lag-free scrolling)
│   │       └── refresh_action_button.dart # Animated rotating refresh button with haptic feedback
│   └── features/
│       ├── auth/
│       │   ├── models/server_profile.dart           # Server host (LAN + NetBird VPN), API key, route state
│       │   ├── providers/auth_provider.dart         # StateNotifier managing active server profile and secure storage
│       │   └── presentation/onboarding_screen.dart  # First-launch setup wizard & connection test screen
│       ├── dashboard/
│       │   ├── models/
│       │   │   ├── dashboard_widget_config.dart     # Widget ordering, visibility, size, and isCollapsed model
│       │   │   └── telemetry_models.dart            # SystemInfo, RAM breakdown, GPU
│       │   ├── presentation/
│       │   │   ├── dashboard_screen.dart            # Overview tab with FrostedAppBar and 12 collapsible modular widgets
│       │   │   └── widgets/
│       │   │       ├── collapsible_dashboard_card.dart # Header chevron toggle and sleek single-line summary card
│       │   │       ├── alerts_jobs_widget.dart      # Alert dismissal, restore sheet, active background jobs
│       │   │       ├── apps_usage_widget.dart       # Installed apps quick summary & link to Apps tab
│       │   │       ├── cpu_widget.dart              # CPU load, core thermals, multi-core bars (sparklines removed)
│       │   │       ├── disk_health_widget.dart      # Disk temperatures & status pills
│       │   │       ├── gpu_widget.dart              # Dedicated GPU details
│       │   │       ├── memory_arc_widget.dart       # Tightened 6-metric RAM & ARC grid with reduced slack
│       │   │       ├── network_traffic_widget.dart  # Real-time RX/TX throughput cards
│       │   │       ├── shares_services_widget.dart  # Configured SMB shares list
│       │   │       ├── storage_pools_summary_widget.dart # ZFS pools capacity & OS boot pool health card
│       │   │       └── system_summary_widget.dart   # Hostname, hardware, uptime, load averages
│       │   └── providers/
│       │       ├── dashboard_layout_provider.dart   # Layout state with persistent toggleCollapsed SharedPreferences
│       │       └── telemetry_provider.dart          # Telemetry notifier with alert dismissal & restore APIs
│       ├── storage/
│       │   ├── presentation/storage_screen.dart     # Read-only Pools & VDEVs, Disks, Datasets tree with FrostedAppBar
│       │   └── providers/storage_provider.dart      # Storage fetcher with RAID and usable space calculation
│       ├── apps/
│       │   ├── models/app_model.dart                # App model with upgradeVersion and app icon
│       │   ├── presentation/apps_screen.dart        # 3rd tab: Network icons, version diffs, Start/Stop/Upgrade
│       │   └── providers/apps_provider.dart         # TrueNAS app.query notifier
│       └── settings/
│           ├── presentation/
│           │   ├── settings_screen.dart             # Merged 4th tab: Aligned servers, SMB toggles & ACL, Logs, Users, Advanced sheets
│           │   └── widgets/                         # Dedicated modal bottom sheets for ACL, Logs, Users, Jobs, Power, Boot, App Resources
│           └── providers/system_provider.dart       # System state & notifier with ACL, audit, power, jobs, and sensor APIs
├── test/
│   ├── enhancements_test.dart                       # Unit tests for app upgrades, icons, and collapsible config
│   ├── models_test.dart                             # Unit tests for SystemInfoData, ZfsPool, TrueNasApp, ServerProfile
│   ├── new_features_test.dart                       # Unit tests for RAID calculation and NetworkInterfaceTelemetry
│   └── notification_test.dart                       # Unit tests for alert deduplication
├── AGENTS.md                                        # AI rules and constraints
├── AI_INSTRUCTIONS.md                               # Architectural rules & transport security
├── AUDIT_FIX_PLAN.md                                # Enterprise readiness & audit matrix
├── CHANGELOG.md                                     # Itemized release changelog
├── CLAUDE.md                                        # Quick project reference
├── README.md                                        # User-facing README and documentation
├── release_notes_v1.0.0.md                          # Release notes
└── STRUCTURE.md                                     # Full architecture blueprint
```

---

## 3. Core Models & Provider API Surface

### 3.1 Authentication & Profile (`auth_provider.dart`)
- `ServerProfile`:
  - `id`: Unique UUID
  - `name`: Display name (e.g. "Home Server")
  - `primaryHost`: Local IP or hostname (e.g. `https://192.168.1.11`)
  - `secondaryHost`: Fallback VPN IP (e.g. NetBird `https://100.102.141.91`)
  - `authType`: `apiKey` or `credentials`
  - `apiKey`: Encrypted API token
  - `activeRoute`: `ActiveRoute.lan` or `ActiveRoute.vpn`
- `AuthProvider`:
  - `loadProfiles()`: Reads saved profiles from `flutter_secure_storage`.
  - `saveProfile(ServerProfile)`: Persists profile and connects.
  - `testConnection(ServerProfile)`: Sends test ping to TrueNAS HTTPS REST `/api/v2.0/system/info`.
  - `activeHost`: Returns `lanHost` if ping succeeds, otherwise `vpnHost`.

### 3.2 Telemetry & Dashboard (`telemetry_provider.dart`)
- `TelemetrySnapshot`:
  - `systemInfo`: Hostname, CPU model, cores, uptime, load averages, version, eccMemory.
  - `cpuUsage`, `cpuTemp`, `perCoreTemps`, `cpuHistory`: Rolling 20-sample line graph history.
  - `ramTotalBytes`, `ramUsedBytes`, `ramFreeBytes`, `ramCachedBuffersBytes`, `arcSizeBytes`, `arcHitRatio`, `swapTotalBytes`, `swapUsedBytes`, `ramHistory`: 6-metric memory breakdown with sparkline.
  - `pools`, `bootState`: Data pools and OS boot pool wear & scrub state.
  - `jobs`: Active running and waiting background jobs (`/api/v2.0/core/get_jobs`).
  - `alerts`: Active and dismissed TrueNAS alerts.
- Methods:
  - `dismissAlert(uuid)`: Calls `/api/v2.0/alert/dismiss`, cancels local notification, updates state.
  - `restoreAlert(uuid)`: Calls `/api/v2.0/alert/restore`, refreshes state.
  - `dismissAllAlerts(uuids)`: Batch dismisses active alerts.

### 3.3 Theming & Appearance (`theme_provider.dart`)
- `ThemeSettings`:
  - `themeMode`: `ThemeMode.system`, `ThemeMode.dark`, `ThemeMode.light`.
  - `useDynamicColors`: Material You wallpaper color extraction toggle on Android 12+.
- `AppTheme`:
  - Space Grotesk typography (`google_fonts`).
  - Derived surface and card roles from `colorScheme`.
  - Frosted glass components with continuous rounded corners (16–24dp).

---

## 4. Verification & Build Commands

- **Static Analysis:**
  ```powershell
  flutter analyze
  ```
- **Unit Tests:**
  ```powershell
  flutter test
  ```
- **Build Split-per-ABI Release APKs:**
  ```powershell
  flutter build apk --split-per-abi
  ```
