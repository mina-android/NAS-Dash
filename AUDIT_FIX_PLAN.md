# NAS Dash Enterprise Readiness & Security Audit

This document tracks enterprise audit compliance, security verification, code quality, and testing health for **NAS Dash** (`com.ma.nasdash`).

---

## 1. Security & Compliance Matrix

| Audit Item | Verification Status | Notes |
|---|---|---|
| **Enforced HTTPS/WSS Transport** | Passed | HTTP/WS strictly rejected. Self-signed certificate pinned with `badCertificateCallback`. |
| **API Key Protection** | Passed | TrueNAS API keys stored securely in AES-encrypted hardware keystore (`flutter_secure_storage`). |
| **Biometric Power Guard** | Passed | Server Reboot and Shutdown guarded by `LocalAuthentication` biometric/device credential verification. |
| **Read-Only Storage Safety** | Passed | Pool/dataset modification and deletion UI barred. Snapshot creation UI omitted for strict inspection safety. |
| **Safe Failover Route Switching** | Passed | Dynamic LAN $\leftrightarrow$ NetBird VPN route switching with automatic portal host rewriting. |
| **Alert Dismissal & REST Sync** | Passed | Alert dismissal synced with TrueNAS `/api/v2.0/alert/dismiss` and notification action callbacks. |
| **Fail-Safe Startup & KeyStore Resilience** | Passed | Unblocked immediate `runApp()`, deferred notification permissions, `resetOnError: true`, 4s timeout, global error boundaries. |
| **Butter-Smooth Scrolling & Performance** | Passed | GPU offscreen `saveLayer` passes eliminated by switching `GlassCard` to hardware-accelerated surface containers. |
| **Clean Dashboard Telemetry** | Passed | LineChart sparkline graphs removed from CPU & RAM cards for an uncluttered, responsive dashboard. |
| **Unified Server Management UI** | Passed | Merged Active Server and Configured Servers into a single compact section with zero dead space. |
| **Notification Reliability & Diagnostics** | Passed | Protected `ic_notification` (90% status bar glyph) via `res/raw/keep.xml`, `AndroidManifest.xml`, and `isShrinkResources = false` for 100% release delivery. |
| **Adaptive Icon & Notification Silhouette** | Passed | `app_icon.png` centered at 53% safe circular margin on solid white `#FFFFFF` across light/dark; clean 90% full-width notification glyph in `@drawable/ic_notification`. |
| **Frosted Glass Top Bar Blur** | Passed | Reusable `FrostedAppBar` with `extendBodyBehindAppBar` across all 4 screens, maintaining 120fps butter-smooth scrolling. |
| **Collapsible & Expandable Dashboard** | Passed | `CollapsibleDashboardCard` with header-row tap toggle (no overlapping arrows) and single-line status summaries persisted in `SharedPreferences`. |
| **RAM Card Slack Elimination** | Passed | Replaced `GridView.count` (which injected `MediaQuery.padding`) with compact `Row`/`Expanded` stat tiles in `MemoryArcWidget`. |
| **Installed Apps Version Diffs & SVG/PNG Icons** | Passed | `AppIconWidget` supporting `.svg` (`flutter_svg`), raster images, self-signed TLS, and CDN fallback (`walkxcode/dashboard-icons`), plus version diffs (`Current ➔ Upgrade`). |
| **SMB Share Toggles & Username-Resolved ACL** | Passed | Instant SMB share loading on open (fault-isolated `SystemNotifier` + `telemetryProvider` fallback) and username/group-resolved ACL inspector (`SmbAclBottomSheet`). |
| **Host Power Log Dates & Created Users** | Passed | Formatted operation timestamps (`MMM d, yyyy • h:mm a`) in `PowerLogsSheet` and user account inspection in `UsersSheet`. |
| **Advanced Controls & Neutral Monochrome Icons** | Passed | Warning threshold slider, active jobs live monitor, boot SSD health, and container resources with uniform monochrome Settings icons (NIC details removed to streamline settings). |

---

## 2. Code Quality & Test Status

- **Static Analysis:** `dart analyze` — **0 issues found** (clean).
- **Unit Tests:** `flutter test` — **15 / 15 tests passed (100%)**.
- **Release Compilation:** `flutter build apk --split-per-abi` — **Successfully compiled** `arm64-v8a`, `armeabi-v7a`, and `x86_64` release APKs.
