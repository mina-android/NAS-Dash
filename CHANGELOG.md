# Changelog

All notable changes to the **NAS Dash** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.1] - 2026-11-25

### Changed
- **README & GitHub Releases**: Removed the Frequently Asked Questions section and navigation link from `README.md` to match `README_TEMPLATE.md`, and aligned all GitHub release notes (`v1.0.0`–`v1.1.1`) with the `IT-Box` release note format.

### Dynamic Server Connection States, Wake-on-LAN & Landscape AOD (2026-11-25)
- **Wake-on-LAN (WoL) Service & Server Profile (`wake_on_lan_service.dart`, `server_profile.dart`, `auth_provider.dart`, `onboarding_screen.dart`)**:
  - Added `WakeOnLanService` (`RawDatagramSocket` UDP magic packet sender with MAC normalization, 102-byte payload builder, subnet broadcast derivation + `255.255.255.255`, and 3-burst transmission).
  - Added `wolMacAddress`, `wolBroadcastAddress`, and `wolPort` (default `9`) to `ServerProfile` with full backward-compatible JSON serialization and an optional **Wake-on-LAN** section in `OnboardingScreen`.
  - Added automatic physical NIC MAC discovery (`state.link_address` from `/api/v2.0/interface`) in `TelemetryNotifier` persisted via `AuthNotifier.updateWolMacIfEmpty()`.
- **Dynamic Server Status Machine & Screens (`server_connection_provider.dart`, `server_status_screen.dart`, `app_shell.dart`, `settings_screen.dart`)**:
  - Added `ServerConnectionNotifier` (`checking`, `online`, `offline`, `shutDown`, `restarting`, `waking`) and gated `AppShell` on `ServerConnectionStatus.online`.
  - **Shutdown Flow**: Dispatching **Shutdown** from `SettingsScreen` transitions immediately to a full-screen **Server is Off** view (`ServerStatusScreen`) with **Wake on LAN** (auto-polling every 5s for up to 3 minutes) and **Check Connection**.
  - **Cold Start Offline Flow**: Unreachable servers on cold start show **Server Offline or Disconnected** with **Refresh Connection**, **Wake on LAN**, and a top-right **Server Settings** sheet (edit/switch/add servers).
  - **3-Minute Post-Restart & 30-Minute Periodic Refresh**: Dispatching **Reboot** transitions to a **Server is Restarting** countdown (`03:00` wall-clock tracked + **Check Now**) that auto-refreshes at `00:00`. A 30-minute periodic health check probes LAN first then VPN, switching to **Offline** if both fail.
- **Landscape Dashboard Always-On Display (AOD) (`aod_mode_provider.dart`, `landscape_aod_overlay.dart`, `MainActivity.kt`)**:
  - Added `AodModeNotifier` and `LandscapeAodOverlay` triggering after 30 seconds of inactivity when on the **Dashboard** tab in **Landscape** mode (while online).
  - Renders a true-black (`#000000`) OLED desk display with Clock & Date, Hostname + `LAN`/`VPN` & Online badge, CPU % & Temp, RAM % & ARC, Pools health/capacity, Network RX/TX, Active Alerts, Uptime, and Phone Battery % + Charging, plus 60-second burn-in pixel shifting and an enable/disable toggle in Settings.
  - Extended `MainActivity.kt` (`com.ma.nasdash/device`) with `dimScreenBrightness` and `setScreenBrightness` to dim brightness by 10% (`0.90` of current system brightness, `0.02` floor) in AOD and restore system brightness (`-1.0`) immediately on touch or app pause.
- **Unit Tests (`test/connection_wol_aod_test.dart`)**:
  - Added unit tests covering `WakeOnLanService`, `ServerProfile` WoL serialization, `ServerConnectionNotifier` state transitions/timers, and `AodModeNotifier` inactivity/wake behavior.
- **Version Bump (`1.1.1+3`)**:
  - Bumped `pubspec.yaml`, Settings About badge, and `README.md` release badges/links from `1.1.0+2` to `1.1.1+3`.

---

## [1.1.0] - 2026-11-22

### TrueNAS SCALE App Upgrade & Lifecycle Fix (2026-11-22)
- **Fixed App Upgrade & Start/Stop Endpoints (`apps_provider.dart`, `api_endpoints.dart`)**:
  - Updated `AppsNotifier.upgradeApp()` from the broken `/api/v2.0/app/id/$appName/upgrade` route to `POST /api/v2.0/app/upgrade` with `{"app_name": appName, "options": {}}`, with automatic fallback to `{"app_name": appName}` on HTTP 400/422 and legacy `/id/$appName/upgrade` on HTTP 404/405.
  - Hardened `startApp()` and `stopApp()` to use `POST /api/v2.0/app/start` and `POST /api/v2.0/app/stop` with multi-version payload/route fallbacks.
- **Asynchronous TrueNAS Job Polling & Error Reporting (`AppActionResult`, `activeAppJobsProvider`)**:
  - Added `AppActionResult`, `BatchUpgradeResult`, and `AppJobProgress` so app actions track returned TrueNAS background job IDs via `/api/v2.0/core/get_jobs`, report live percentage progress, and surface exact HTTP/middleware failure reasons in SnackBars.
- **Upgrade Target Version Enrichment (`app_model.dart`, `apps_provider.dart`)**:
  - Automatically queries `POST /api/v2.0/app/upgrade_summary` for apps with `upgrade_available: true` when target version strings are missing from `GET /api/v2.0/app`, and added `available_versions_for_upgrade` parsing plus `TrueNasApp.copyWith`.
- **Per-App Progress UI & "Upgrade All" Batch Action (`apps_screen.dart`)**:
  - Disabled duplicate actions and displayed live job progress spinners/percentages on active app cards, plus added a one-tap **"Upgrade All (N)"** `ActionChip` in the filter header when updates are available.
- **Unit Tests (`test/app_upgrade_test.dart`)**:
  - Added unit tests covering `upgradeApp` payload/fallbacks, job polling (`SUCCESS` and `FAILED` middleware error extraction), `startApp`/`stopApp`, `upgrade_summary` enrichment, and `upgradeAllApps`.

### Release & Repository Maintenance (2026-11-22)
- **Version Bump (`1.1.0+2`)**: Bumped `pubspec.yaml` and Settings About badge from `1.0.0+1` to `1.1.0+2`.
- **README & `.gitignore` Updates**:
  - Pinned **Flutter `3.47.6`** and **Dart `3.13.5`** in `README.md` prerequisites and added a pinned Flutter badge.
  - Switched main `README.md` badges from `style=flat-square` to rounded-corner `style=flat` and updated release download links to `v1.1.0`.
  - Added `AGENTS.md`, `AI_INSTRUCTIONS.md`, and `CLAUDE.md` to `.gitignore` and marked `.gitignore` as hidden.

### Landscape Navigation Rail & UI/UX Polish (2026-11-22)
- **Tonal Top Bar Action Pills, Landscape Right Padding & Cohesive Rounded Icons (`FrostedAppBar`, `RefreshActionButton`, `AppShell`)**:
  - Added `frostedAppBarActionStyle` in `lib/core/widgets/frosted_app_bar.dart` for unified 36×36 rounded-square (`12dp`) tonal pill action buttons across `RefreshActionButton`, Dashboard Customize, and the Landscape Lock toggle, with `6dp` spacing between buttons and `12dp` right-edge padding in landscape (`8dp` in portrait).
  - Updated navigation icons across both portrait `NavigationBar` and landscape `LandscapeSideNavBar` to cohesive Material Rounded icons (`space_dashboard_rounded`, `storage_rounded`, `grid_view_rounded`, `settings_rounded`) and `dashboard_customize_rounded` on the Dashboard top bar.
- **Full-Height Stretched Landscape Side Navbar (`LandscapeSideNavBar`)**:
  - Replaced the centered `NavigationRail` in `lib/app_shell.dart` with a custom frosted `LandscapeSideNavBar` (`116dp` inner width inside `SafeArea`, preventing display-cutout cropping) whose 4 destinations (**Dashboard**, **Storage**, **Apps**, **Settings**) stretch equally via `Expanded` to fill 100% of the vertical rail height, featuring a left-edge vertical active accent bar, full-height rounded pill indicator, 26dp icons, and haptic selection feedback.
- **Live Navigation Status Badges & Smooth Tab Cross-Fade**:
  - Added live `Badge.count` indicators on both `LandscapeSideNavBar` and portrait `NavigationBar` for active (non-dismissed) system alerts on **Dashboard** and available app updates on **Apps**.
  - Added `_FadeIndexedStack` for a smooth 180ms `Curves.easeOutCubic` cross-fade when switching between tabs while preserving scroll and provider state.
- **Apps Search & Status Filter Chips (`AppsScreen`)**:
  - Upgraded `lib/features/apps/presentation/apps_screen.dart` with a Material 3 rounded search bar (matching app name or version) and live-counted `FilterChip` bar (`All`, `Running`, `Stopped`, `Updates`) plus a one-tap `"Clear filters"` empty state.
- **Widget Tests**:
  - Added `test/landscape_nav_and_apps_test.dart` verifying full-height equal-sized rail tiles, badge rendering, and `AppsScreen` search/chip filtering.

### Landscape Lock Mode — On-The-Go Server Dashboard & Kiosk Mode (2026-11-22)
- **Landscape Orientation Lock, WakeLock & Immersive Sticky Full-Screen (`landscape_mode_provider.dart` & `MainActivity.kt`)**:
  - Added `LandscapeModeNotifier` (`landscapeModeProvider`) backed by `SharedPreferences` (`nas_dash_landscape_lock`) so the locked landscape state persists across app restarts.
  - Locks orientation to `DeviceOrientation.landscapeLeft` and `DeviceOrientation.landscapeRight` and hides Android OS status/navigation bars via `SystemUiMode.immersiveSticky`.
  - Added native `com.ma.nasdash/device` `MethodChannel` in `MainActivity.kt` to toggle `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON` (preventing display sleep when mounted next to the server) and query real-time Android `BatteryManager` capacity and charging status.
- **Top Bar Landscape Lock Toggle & Live Telemetry Cluster (`FrostedAppBar`)**:
  - Added a one-tap Landscape Lock toggle button (`Icons.screen_lock_landscape_rounded` / `Icons.screen_rotation_rounded`) with haptic feedback across all 4 tabs' `FrostedAppBar`.
  - When in landscape mode, `FrostedAppBar` displays a compact live telemetry cluster showing the active **Connection Route Pill** (`LAN` / `VPN` with tap-to-switch), **Phone Battery % + Charging Indicator Pill**, and **Desk Clock Time (`HH:mm`) Pill**.
- **Adaptive Left Frosted `NavigationRail` (`AppShell`)**:
  - Automatically replaces the bottom `NavigationBar` with a left-mounted frosted glass `NavigationRail` (`BackdropFilter` with `sigma: 20`) when in landscape mode to maximize vertical screen real estate.
- **Responsive 2-Column Masonry & Grid Layouts Across All 4 Screens (`responsive_two_column_grid.dart`)**:
  - Added `MasonryTwoColumnGrid` and `UniformTwoColumnGrid` for side-by-side card rendering without vertical whitespace gaps.
  - **Dashboard (`DashboardScreen`)**: Renders visible `CollapsibleDashboardCard` widgets in a balanced 2-column masonry layout in landscape.
  - **Storage (`StorageScreen`)**: Renders ZFS Pools & VDEVs and Physical Disks in 2-column grids in landscape.
  - **Apps (`AppsScreen`)**: Renders installed TrueNAS applications in a 2-column grid in landscape.
  - **Settings (`SettingsScreen`)**: Arranges the 8 settings section cards into a 2-column masonry layout in landscape and adds a synchronized **Landscape Dashboard Lock (Kiosk Mode)** switch inside the Appearance & Theme section.

### Host Power Management Fix (2026-11-16)
- **Fixed TrueNAS SCALE 25.04+ / 25.10+ Host Reboot & Shutdown**:
  - Updated `SystemNotifier.reboot()` and `SystemNotifier.shutdown()` in `lib/features/system/providers/system_provider.dart` to send the mandatory `reason` JSON payload (`{'reason': ...}`) required by TrueNAS SCALE 25.04+ audit compliance, with automatic fallback to `{}` for legacy TrueNAS SCALE 24.10 nodes.
  - Added `PowerCommandResult` to return structured success status and extracted HTTP/TrueNAS middleware error details instead of silently swallowing exceptions.
  - Added an optional, pre-filled **Audit Reason** `TextField` to the power confirmation dialog in `SettingsScreen`, double-tap protection (`_isDispatchingPower`), and detailed failure messages in the SnackBar.
  - Added unit tests in `test/power_commands_test.dart` covering default reason dispatch, custom reason trimming, empty-reason fallback, legacy 24.10 fallback, and HTTP error formatting.
  - Added `kotlin.incremental=false` to `android/gradle.properties` to prevent cross-drive (`C:\` Pub Cache vs `T:\` workspace) Kotlin incremental cache failures during Android release builds.

---

## [1.0.0+1] - 2026-10-29

### UI, Icon, Telemetry & Reliability Refinements (16 User-Verified Fixes)
- **Direct Asset Reference in README**: Updated the header logo image in README.md to point directly to ssets/app_icon.png.
- **Adaptive Monochrome & Status Bar Notification Icon (`adaptive_icon.png`)**:
  - Dedicated `assets/adaptive_icon.png` (featuring transparent separation lines for the cube facets, donut chart, and metric bars) exclusively as the Android homescreen monochrome adaptive icon (`ic_launcher_monochrome.png` at 51% canvas height) and status bar notification icon (`ic_notification.png` at 90% glyph scale on pure `#FFFFFF` alpha mask across all densities), replacing opaque white blocks with sharp, detailed cutouts.
- **Normal App Icon Size Reduction (-2 Units)**:
  - Scaled down the normal colored launcher icon (`assets/app_icon.png`) by 2 units across all mipmap densities: adaptive foreground icon (`ic_launcher_foreground.png`) reduced from 53% to 51% canvas height on solid `#FFFFFF` white background, and legacy launcher icons (`ic_launcher.png`, `ic_launcher_round.png`) reduced from 68% to 66% canvas height.
- **Smooth, 120fps Expand & Collapse Dashboard Card Animation**:
  - Replaced abrupt widget swapping in `CollapsibleDashboardCard` with a hardware-accelerated `AnimatedCrossFade` wrapped in `RepaintBoundary` utilizing `Curves.fastOutSlowIn` size transitions, `Curves.easeOutCubic`/`Curves.easeInCubic` opacity curves, and top-pinned layout constraints for stutter-free, buttery smooth card transitions.
- **Fixed Collapsed System Summary Uptime Display**:
  - Sanitized TrueNAS SCALE `uptime` strings across `SystemInfoData.fromJson`, `DashboardScreen`, and `SystemNotifier` by stripping trailing fractional microsecond decimals (`.split('.').first.trim()`), ensuring collapsed System Summary cards display clean, formatted uptime without trailing numbers.
- **Removed Network Interfaces from Settings**:
  - Removed the Network Interfaces & NIC Details tile from `SettingsScreen`, deleted `network_interfaces_sheet.dart`, and pruned `fetchNetworkInterfaces()` from `SystemNotifier`, keeping physical interface telemetry centralized within the dedicated Dashboard Network Traffic widget.
- **Header-Tap Collapsible Dashboard Cards (Removed Overlapping Arrows)**:
  - Removed overlapping chevron `IconButton` arrows from `CollapsibleDashboardCard` while preserving full expand/collapse functionality via tapping the card's title/header row when expanded or anywhere on the card when collapsed.
- **Compact & Aligned RAM & ZFS ARC Card (`MemoryArcWidget`)**:
  - Replaced `GridView.count` (which inherited top/bottom `MediaQuery.padding` from `extendBodyBehindAppBar: true` and `extendBody: true`) with two compact `Row`s of `Expanded` `_StatTile` widgets, completely eliminating ~160dp of empty vertical space above and below the 2×3 memory metric grid.
- **Full SVG & Raster App Icon Loading (`AppIconWidget`)**:
  - Added `flutter_svg` and global TLS `HttpOverrides` (`badCertificateCallback`) in `main.dart` to render TrueNAS SCALE catalog `.svg` and `.png` application icons seamlessly, with automatic CDN fallback (`walkxcode/dashboard-icons`) and clean default icon fallback.
- **Human-Readable Usernames & Group Names in SMB Share ACLs**:
  - Updated `SystemNotifier.getFilesystemAcl` to request `simplified: true, resolve_ids: true` and enhanced `SmbAclBottomSheet` to resolve UIDs and GIDs against `/api/v2.0/user` and `/api/v2.0/group` so Owner User, Owner Group, and every ACL entry display human-readable usernames and group names alongside IDs.
- **Streamlined Settings Screen & Monochrome Neutral Section Icons**:
  - Removed Sign-in & Audit Logs, TrueNAS SCALE OS Updates, Hardware Sensors & Fan RPMs, and Active Web & API Sessions from Settings to keep the control surface focused and responsive.
  - Standardized all Settings section headers and list tile icons to neutral monochrome (`colorScheme.onSurfaceVariant`) without colored icon backgrounds.
- **Formatted Operation Dates in Host Power Log (`PowerLogsSheet`)**:
  - Added EJSON (`{"$date": epoch_ms}`), epoch, and ISO timestamp parsing formatted via `DateFormat('MMM d, yyyy • h:mm a')` along with current boot session calculation from `system.info` (`uptime_seconds`), ensuring every power/reboot/boot record displays its exact date and time.
- **Instant SMB File Shares Loading Without Manual Refresh**:
  - Refactored `SystemNotifier.fetchSystem()` with per-endpoint fault isolation (`try/catch` per call) and linked `SettingsScreen` to `telemetryProvider` shares as an immediate fallback so SMB File Shares appear immediately on first open.
- **100% Reliable Notification Firing with Enlarged 90% Status Bar Icon**:
  - Added `android/app/src/main/res/raw/keep.xml` (`tools:keep="@drawable/ic_notification"`), referenced `@drawable/ic_notification` in `AndroidManifest.xml`, disabled release resource shrinking (`isShrinkResources = false`), and updated `NotificationService` to use `'ic_notification'` so status bar alerts fire reliably in release builds while preserving the 90% status bar icon size.
- **Cleaned Up Customize Dashboard Sheet**:
  - Removed the expand/collapse card size buttons from `DashboardCustomizerSheet`, keeping only drag-to-reorder and visibility switches.

### Comprehensive Feature, UI & Reliability Enhancements (12 Key Additions)
- **Normal App Icon Enlargement (62% Scale)**:
  - Enlarged adaptive launcher icon foreground (`ic_launcher_foreground.png`), monochrome silhouette (`ic_launcher_monochrome.png`), and legacy launcher icons (`ic_launcher.png`, `ic_launcher_round.png`) across all densities to **62% canvas scale** for a bolder, modern look with minimal empty border space while remaining safely within Android adaptive mask boundaries.
- **Enlarged Status Bar Notification Icon**:
  - Re-rendered `ic_notification.png` across all drawable densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) with a full-width **90% glyph scale**, eliminating excess transparent padding so TrueNAS heads-up alerts appear sharp, distinct, and properly sized in the Android status bar and shade.
- **RAM Dashboard Card Spacing Reduction**:
  - Optimized `MemoryArcWidget` 2×3 metric grid: increased tile `childAspectRatio` from 2.2 to 2.7, tightened vertical margins to 8dp, and eliminated excessive empty slack below Total RAM, Free RAM, and Cached/Swap metrics.
- **Installed Apps Upgrade Version & App Icon Rendering**:
  - Enhanced `TrueNasApp` model with `upgradeVersion` and `upgradeHumanVersion` properties parsed from TrueNAS SCALE `app.query` metadata.
  - In `AppsScreen`, rendered network application icons with fallback placeholders and side-by-side version comparison badges (`v1.40.5 ➔ v1.41.0`) when upgrades are available.
- **Server Management Alignment Fix in Settings**:
  - Redesigned active server card in `SettingsScreen` with vertically centered status indicator, server title, and `ACTIVE` chip, aligned host and authentication metadata pills, and resolved layout offset discrepancies.
- **Frosted Glass Top Bar Blur Across All 4 Screens**:
  - Implemented reusable `FrostedAppBar` (`BackdropFilter` with `sigmaX: 18, sigmaY: 18`) and `extendBodyBehindAppBar: true` across **Dashboard**, **Storage**, **Apps**, and **Settings**, delivering unified frosted translucent glass chrome with hardware-accelerated clipping for 120fps stutter-free butter-smooth scrolling.
- **SMB Share On/Off Toggle Restoration**:
  - Restored interactive `Switch` toggles for SMB File Shares in `SettingsScreen` with immediate optimistic UI feedback, error recovery, and SnackBar status notifications calling `/api/v2.0/sharing/smb/id/{id}`.
- **Filesystem ACL Inspector for SMB Shares**:
  - Added dedicated `SmbAclBottomSheet` modal sheet calling TrueNAS `/api/v2.0/filesystem/getacl`, displaying share absolute path, owner UID/GID, ACL type (NFSv4/POSIX), and detailed access control entries with ALLOW/DENY rights.
- **System Logs & Audit Viewers**:
  - Added dedicated "System Logs & User Audit" section in Settings with modal viewers:
    - `SigninLogsSheet`: displays chronological user authentication and administrative login events from TrueNAS `/api/v2.0/audit`.
    - `PowerLogsSheet`: inspects host reboot, shutdown, and boot task execution history via `/api/v2.0/core/get_jobs`.
- **Created User Accounts Viewer**:
  - Added `UsersSheet` displaying created non-system user accounts from `/api/v2.0/user` with UID, username, full name, sudo privilege badges, and system account visibility toggle.
- **8 Selected Advanced Settings & Controls**:
  - **Storage Pool Warning Threshold**: Interactive percentage slider (70% - 95%) in Settings stored in `SharedPreferences` to alert when pool capacity nears critical levels.
  - **Active Jobs & Background Tasks Live Monitor**: `ActiveJobsSheet` displaying live TrueNAS tasks, progress percentages, and task abort functionality.
  - **TrueNAS SCALE OS Update Inspector**: `SystemUpdateSheet` checking release trains, pending OS versions, and changelogs (`/api/v2.0/update/check_available`).
  - **Network Interfaces & NIC Details**: `NetworkInterfacesSheet` listing adapters, link states (UP/DOWN), MTU, MAC addresses, and active IP bindings.
  - **Boot Pool SSD Wear & Health**: `BootPoolSheet` inspecting mirrored boot SSD status and ZFS boot scrub errors.
  - **App Container Resources**: `AppResourceUsageSheet` detailing container runtimes and application state.
  - **Hardware Sensors & Fan RPMs**: `HardwareSensorsSheet` inspecting IPMI/lm-sensors for motherboard temperatures, fan tachometers, and voltages.
  - **Active Web & API Sessions**: `ActiveSessionsSheet` viewing active TrueNAS Web UI client sessions and client IPs.
- **Collapsible & Expandable Dashboard Items**:
  - Added `CollapsibleDashboardCard` with animated chevron toggle on every dashboard card header. Cards smoothly collapse into sleek single-line status summaries and expand on demand, with collapse states saved to `SharedPreferences`.
- **Butter-Smooth Scrolling & Performance Optimization**:
  - Eliminated `BackdropFilter` and GPU offscreen `saveLayer` passes from list items (`GlassCard`), transitioning to high-performance hardware-accelerated Material 3 surface containers with subtle border styling and rounded corners (20dp). This completely eliminates frame drops, stuttering, and scrolling lag across all tabs and lists.
- **Dashboard Telemetry Decluttering**:
  - Removed sparkline trend line charts (`fl_chart` LineChart widgets) from `cpu_widget.dart` and `memory_arc_widget.dart` to provide a clean, uncluttered, distraction-free dashboard layout while preserving real-time gauges, multi-core bars, and the detailed 2×3 physical memory metric grid.
- **Unified Server Management Section**:
  - Merged separate "Active Server" and "Configured Servers" cards in `settings_screen.dart` into a single, compact "Server Management" section with active route indicators, quick host failover toggle, and server switcher, eliminating redundant panels and excessive whitespace.
- **Reliable Notification Subsystem & Permission Diagnostics**:
  - Fixed notification dispatch failures: updated Android notification initialization and alert details to use `@mipmap/ic_launcher` for 100% platform and OEM reliability.
  - Added background worker initialization fallbacks and an interactive Permission Status badge (`Allowed` / `Permission Required`) with a one-tap "Grant Notification Access" button in Settings.
- **Enlarged App Icon (50% Canvas Scale & Solid White BG)**:
  - Enlarged adaptive foreground (`ic_launcher_foreground.png`) and monochrome silhouette (`ic_launcher_monochrome.png`) from 42% to **50% canvas scale** (~54dp graphic on 108dp canvas) on pure solid white background, increasing icon visibility and prominence while remaining safely inside Android circular mask safe zones.
  - Scaled legacy launcher icons to 65% scale on solid white background.

### Fixed & Modernized
- **Startup Black Screen Resolution & Fail-Safe App Initialization**:
  - Resolved startup freeze/black screen on Android: made `main()` completely fail-safe by invoking `runApp()` immediately.
  - Wrapped `NotificationService.instance.initialize()` and `Workmanager().initialize(...)` in safe asynchronous `try/catch` blocks so background worker or notification setup issues can never prevent UI startup.
  - Deferred `NotificationService.instance.requestPermissions()` to `WidgetsBinding.instance.addPostFrameCallback` in `AppShell`, ensuring Android Activity is fully attached and ready before requesting runtime notification permissions.
  - Installed global `FlutterError.onError` and `PlatformDispatcher.instance.onError` logging handlers along with a custom `ErrorWidget.builder` fallback to prevent uncaught runtime errors from rendering blank surfaces.
  - Enhanced `FlutterSecureStorage` resilience: configured `AndroidOptions(encryptedSharedPreferences: true, resetOnError: true)` and a 4-second safety timeout on `loadProfiles()` to prevent Android KeyStore deadlocks.
- **App Launcher, Adaptive & Status Bar Icon Overhaul (42% Scale & Solid White Background)**:
  - Resized adaptive foreground (`ic_launcher_foreground.png`) and monochrome silhouette (`ic_launcher_monochrome.png`) to **42% canvas scale** (~45dp graphic on 108dp canvas with 31.5dp outer padding), guaranteeing zero edge cropping across all OEM launcher shapes (circle, squircle, pebble, rounded rectangle).
  - Enforced solid pure white (`#FFFFFF`) launcher background across all themes: updated both `values/colors.xml` and `values-night/colors.xml` (`ic_launcher_background`).
  - Updated legacy non-adaptive launcher icons (`ic_launcher.png`, `ic_launcher_round.png`) with the centered 42% graphic on solid pure white backgrounds across all mipmap densities (`mdpi` through `xxxhdpi`).
  - Placed base fallback status bar notification icon in `android/app/src/main/res/drawable/ic_notification.png` in addition to all density directories.
- **Modernized Frosted Glass & Material You UI with Space Grotesk**:
  - Integrated `google_fonts` (`Space Grotesk`) across entire application typography and app bar titles.
  - Replaced hardcoded dark obsidian colors with true Android 12+ Material You Dynamic Colors, supporting both Light and Dark themes.
  - Added dedicated Appearance & Theme controls in Settings (Segmented ThemeMode: System / Light / Dark, and Android Dynamic Colors toggle).
  - Built reusable `GlassCard` utilizing `ImageFilter.blur(sigmaX: 16, sigmaY: 16)` and frosted translucent surfaces for cards, app bars, and sheets.
- **4-Tab Navigation & System/Settings Merge**:
  - Merged `SystemScreen` and `SettingsScreen` into a unified, clean `SettingsScreen` with server profiles, theme controls, SMB shares, power controls, push alert tester, and developer info.
  - Promoted Installed Apps to a primary navigation destination: bottom bar now consists of 4 streamlined destinations: **Dashboard**, **Storage**, **Apps**, and **Settings**.
  - Wrapped `NavigationBar` in frosted glass with `extendBody: true` for smooth backdrop scrolling.
- **Removed SMB File Manager & Credentials**:
  - Completely deleted SMB file browser screen, credential dialogs, and unused SMB platform channel frontend code.
  - Removed SMB credential prompts (username, password, domain) from onboarding wizard.
- **Fixed SMB File Shares Switch Highlight**:
  - Wrapped share list tiles in rounded containers (`shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` and `contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2)`), eliminating cropped and sharp-cornered tap ripples.
- **Server-Side Alert Dismissal & Restoration**:
  - Added inline alert dismissal (`Icons.close_rounded`) and "Dismiss All" button calling TrueNAS SCALE `/api/v2.0/alert/dismiss`.
  - Added Android notification action button (`Dismiss`) on status bar heads-up alerts.
  - Added Dismissed Alerts inspection sheet with one-click restore via `/api/v2.0/alert/restore`.
- **Expanded RAM & ZFS ARC Telemetry**:
  - Enhanced memory dashboard card with 2×3 metric grid: Total Physical RAM, Apps/OS Used, ZFS ARC Cache, Free RAM, ARC Hit %, and Cached/Swap.
  - Added multi-segment visual memory bar and live rolling sparkline trend chart.
  - Added hardware ECC memory badge when supported by motherboard.
- **Animated Top-Right Refresh Action Button**:
  - Created `RefreshActionButton` featuring smooth rotation animation, haptic feedback, and async awaiting across Dashboard, Storage, Apps, and Settings tabs.
- **Removed Storage Snapshot Creation Button**:
  - Removed snapshot camera button and modal dialog from the Storage tab to enforce read-only inspection safety.
- **Removed Settings Version Footer Text**:
  - Cleaned up settings screen by removing `'NAS Dash • v1.0.0+1 • Material 3 Adaptive'` footer label.

### Added (New Informative Features)
- **Active Background Jobs & Tasks Monitor**:
  - Integrated `/api/v2.0/core/get_jobs` into `AlertsJobsWidget` to render running and waiting TrueNAS jobs (pool scrubs, app updates, replications) with live progress bars.
- **Boot Pool Health & Capacity Card**:
  - Integrated `/api/v2.0/boot/get_state` into `StoragePoolsSummaryWidget` showing OS boot pool health, filesystem name, and last scrub state.
- **Real-Time Mini Sparkline History**:
  - Integrated `fl_chart` rolling 20-sample history buffers for CPU and RAM load trends.

---

## [1.0.0] - 2026-10-28

### Added
- **TrueNAS Onboarding Setup Wizard**:
  - Implemented initial launch onboarding screen (`OnboardingScreen`) prompting for Server Name, Primary Host URL (LAN), optional Secondary Host URL (VPN/Remote), Auth Type (API Key or Username/Password), and Self-Signed TLS toggle.
  - Added interactive "Test Connection" button testing HTTPS REST endpoint `/api/v2.0/system/info` with instant feedback banners.
- **Realtime Network Interface Throughput Cards**:
  - Created `NetworkInterfaceTelemetry` model with human-readable binary throughput rate formatting (`KB/s` and `MB/s`).
  - Integrated `/api/v2.0/interface` and `/api/v2.0/reporting/netdata_get_data` polling every 4 seconds for live In/Out rates per interface.
- **Split Release APKs Built**:
  - `app-arm64-v8a-release.apk` for modern 64-bit devices.
  - `app-armeabi-v7a-release.apk` for 32-bit ARM devices.
  - `app-x86_64-release.apk` for Intel/AMD and emulators.
