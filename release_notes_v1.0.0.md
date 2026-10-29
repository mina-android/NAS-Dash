# NAS Dash v1.0.0+1 Release Notes

**Release Date:** 2026-10-28  
**Package:** `com.ma.nasdash`  
**Toolchain:** Flutter 3.47.6 / Dart 3.13.5 / Android compileSdk 36

---

## Highlights

### 1. Modernized UI with Space Grotesk & Butter-Smooth Scrolling Performance
- **Silky 60/120fps Scrolling**: Re-architected `GlassCard` to use hardware-accelerated Material 3 surface containers with subtle borders and 20dp continuous rounded corners. Eliminated CPU/GPU offscreen rasterization bottlenecks (`saveLayer`), removing all scrolling lag and stutter across all tabs.
- **Space Grotesk Typography**: The entire app typography is now styled with Google Fonts `Space Grotesk`, offering a modern, clean, system-administration aesthetic.
- **Dynamic Color Extraction**: Complete support for Android 12+ wallpaper color palettes across light and dark modes.
- **In-App Theme Selector**: Users can select between **System**, **Dark**, and **Light** theme modes, and toggle Android Material You wallpaper colors on or off.

### 2. Streamlined 4-Tab Navigation & Unified Server Management
- **Single-Card Server Management**: Merged separate Active Server and Configured Servers cards in Settings into a compact, unified section featuring active route indicators, quick LAN/VPN failover toggles, and server switching with zero wasted whitespace.
- Promoted **Apps** to a main navigation tab with Start, Stop, Upgrade, and smart VPN portal launcher controls.
- Merged **System** and **Settings** into a unified, rich control center.
- Completely removed the SMB file manager frontend and SMB credential prompts in onboarding.
- Fixed the SMB file share switches: tap highlights now feature continuous 16dp rounded corners and proper padding without sharp-cornered edge cropping.

### 3. Enlarged App Icon (50% Safe Scale & Solid White BG) & Status Bar Silhouette
- **Foreground Launcher Icon**: Scaled to **50% canvas scale** (~54dp graphic on 108dp canvas) centered inside solid `#FFFFFF` pure white background across light and dark system modes for optimal visibility while remaining safely within Android circular mask safe zones.
- **Themed Android 13+ Icon**: Clean pure-white monochrome silhouette (`ic_launcher_monochrome.png`) centered at 50% scale.
- **Legacy Launcher Icons**: `ic_launcher.png` and `ic_launcher_round.png` feature the centered 65% logo on solid white backgrounds.
- **Status Bar Icon**: Enlarged 80% pure white alpha mask (`ic_notification.png`) placed in `res/drawable/` as well as all density directories.

### 4. Reliable Notifications Engine & Diagnostic Controls
- **100% Notification Delivery**: Switched default notification icon and notification details to `@mipmap/ic_launcher` to resolve platform resource lookup failures.
- **Permission Diagnostics**: Added a live permission badge (`Allowed` / `Permission Required`) and one-tap "Grant Notification Access" button directly in Settings.
- **Fail-Safe Startup**: Immediate `runApp()` execution prevents black screen startup freezes.
- **Deferred Permissions**: Deferred notification runtime permission request to `addPostFrameCallback` in `AppShell` with an attached Android Activity.
- Enhanced `FlutterSecureStorage` with `resetOnError: true`, `encryptedSharedPreferences: true`, and a 4-second safety timeout.

### 5. Alert Dismissal & Server-Side Restoration
- Dismiss alerts directly from the Android status bar (`Dismiss` notification action button).
- In-app dismiss button on each alert and a **Dismiss All** button calling `/api/v2.0/alert/dismiss`.
- Dismissed Alerts sheet allowing users to view and restore previously dismissed alerts with 1 tap.

### 6. Deep RAM & Clean Dashboard Telemetry
- **Decluttered Dashboard**: Removed line charts/sparklines from CPU and RAM cards for an instant, distraction-free view.
- Detailed 2×3 metric grid displaying Total Physical RAM, Apps/OS Used, ZFS ARC Cache, Free RAM, ARC Hit %, and Cached/Swap.
- Multi-segment color-coded visual memory allocation bar and per-core CPU bars.
- Hardware ECC memory badge when supported by the server motherboard.

### 7. Informative New Monitoring Features
- **Active Background Jobs Monitor**: Integrated `/api/v2.0/core/get_jobs` for live progress tracking on scrubs, app upgrades, and replications.
- **OS Boot Pool Health Card**: Integrated `/api/v2.0/boot/get_state` for monitoring boot pool health, wear, and last scrub state.
- **Animated Top-Right Refresh**: Smoothly rotating refresh button with haptic impact feedback across all screens.
- **Read-Only Storage Safety**: Removed snapshot creation modal to ensure zero accidental changes to server datasets.

### 8. Comprehensive v1.0.0+1 Feature Expansion & Refinements
- **Safe-Margin `app_icon.png` Launcher Icons & Protected 90% Notification Glyph**: Cropped and scaled `assets/app_icon.png` across all mipmap densities (53% safe circular margin on solid white `#FFFFFF` for adaptive icons, 68% for legacy icons) and protected the 90% full-width status bar notification glyph (`ic_notification.png`) with `res/raw/keep.xml` and `isShrinkResources = false` so notifications fire reliably in release builds.
- **Header-Tap Collapsible Dashboard Cards**: Every dashboard card collapses into a sleek single-line summary by tapping the card's title/header row (with overlapping chevron buttons removed) and persists state in `SharedPreferences`.
- **Compact & Aligned RAM & ZFS ARC Card**: Replaced `GridView.count` in `MemoryArcWidget` with two compact `Row`s of `Expanded` tiles to eliminate `MediaQuery.padding` vertical slack above and below the 2×3 memory grid.
- **Installed Apps SVG/PNG Icons & Version Diffs**: Renders `.svg` (`flutter_svg`) and raster app icons with global self-signed TLS support and automatic CDN fallback (`walkxcode/dashboard-icons`), alongside side-by-side version comparison (`Current Version ➔ Update Version`).
- **Instant SMB Share Loading & Username-Resolved ACLs**: Fault-isolated `SystemNotifier.fetchSystem()` with `telemetryProvider` fallback so SMB File Shares appear immediately without manual refresh, and updated `SmbAclBottomSheet` (`resolve_ids: true` + UID/GID lookup) to display human-readable usernames and group names.
- **Formatted Dates in Host Power Log & Neutral Monochrome Settings Icons**: `PowerLogsSheet` formats EJSON/epoch/ISO operation dates (`MMM d, yyyy • h:mm a`) and includes the current boot session timestamp, while all Settings sections use uniform neutral monochrome icons (`colorScheme.onSurfaceVariant`).

---

## Release Artifacts

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.4 MB)
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (19.1 MB)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (22.9 MB)
