<div align="center">

<img src="assets/app_icon.png" alt="NAS Dash Logo" width="112" height="112" />

# NAS Dash

[![Platform](https://img.shields.io/badge/Platform-Android-grey.svg?style=flat)](https://android.com) [![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev) [![Release](https://img.shields.io/badge/Release-v1.1.1-blue.svg?style=flat)](https://github.com/mina-android/NAS-Dash/releases) [![Backend](https://img.shields.io/badge/Backend-TrueNAS_SCALE-grey.svg?style=flat)](https://www.truenas.com) [![License](https://img.shields.io/badge/License-GPL--3.0-black.svg?style=flat)](LICENSE)

<p align="center">
  A native Android dashboard and management companion for TrueNAS SCALE servers, providing real-time telemetry, ZFS storage inspection, app lifecycle management, and secure remote connectivity.
</p>

</div>

---

## Navigation

[Features](#features) &bull; [Downloads](#downloads) &bull; [Self Building & Local Setup](#self-building--local-setup) &bull; [Frequently Asked Questions](#frequently-asked-questions) &bull; [Contribution](#contribution) &bull; [About the Developer](#about-the-developer) &bull; [Donate](#donate) &bull; [License](#license)

---

## Features

### Core Capabilities

- **Real-Time Telemetry & Hardware Monitoring**: Stream live CPU load with per-core distributions, ZFS ARC and physical memory metrics, network throughput, active alerts with server-side dismissal/restoration, background jobs, and OS boot pool wear over encrypted WebSockets and REST APIs.
- **Landscape Lock & Always-On Display (AOD) Mode**: One-tap topbar button locks the interface into landscape kiosk mode with screen wake-lock (`FLAG_KEEP_SCREEN_ON`), full-screen `immersiveSticky` system bar hiding, a top bar live telemetry cluster (**LAN/VPN Connection**, **Phone Battery %**, and **Time**), a full-height frosted `LandscapeSideNavBar` with live alert/update badges, responsive 2-column masonry/grid layouts across all 4 tabs, and an automatic 30-second inactivity **OLED Always-On Display (AOD)** mode on the Landscape Dashboard with native brightness dimming, burn-in pixel shifting, and tap-to-wake.
- **Dynamic Power & Wake-on-LAN (WoL) Resilience**: Dedicated full-screen status views for **Server is Off**, **Server is Restarting** (3-minute auto-reconnect countdown), and **Server Offline / Disconnected** on cold start, backed by auto-discovered/editable NIC MAC **Wake-on-LAN** magic packets with 5-second boot polling and 30-minute periodic LAN-first/VPN-fallback connection checks.
- **Customizable Dashboard Widgets**: Modular widget layout featuring 12 toggleable and collapsible cards with per-widget persistence saved to local application storage.
- **ZFS Storage & Dataset Inspector**: Read-only explorer for ZFS pools, VDEV mirror and RAIDZ configurations, dataset compression ratios, mount directories, and physical disk S.M.A.R.T. health indicators.
- **Containerized App Management**: Monitor TrueNAS SCALE catalog applications with search and status filter chips (`All`, `Running`, `Stopped`, `Updates`), inspect active container statuses, review version update differentials (enriched via `upgrade_summary`), trigger container starts/stops, run single or batch **Upgrade All** updates with live TrueNAS job progress, and launch Web UI portals.
- **Dual-Endpoint Network Routing**: Automatic network handoff switching between local LAN IP addresses and remote VPN overlay hosts (NetBird, Tailscale, WireGuard) with automatic app portal host rewriting.
- **Biometric Security Guards & Host Controls**: Biometric fingerprint or system PIN verification guards critical server actions (with TrueNAS 25.04+ audit reason support for reboots and shutdowns), alongside SMB share toggles, username-resolved ACL inspection, power logs, and user account inspection.

### Architecture & Data Handling

- **Guardrail-Enforced Security**: Destructive storage operations (such as pool destruction or dataset deletion) are intentionally excluded from the mobile interface to eliminate risk of accidental data loss.
- **Encrypted TLS Transport**: Strictly mandates HTTPS and WSS protocols when communicating with the TrueNAS WebSocket and REST endpoints, preventing transmission of plain-text API keys across unencrypted channels.
- **Localized Credential Storage**: Server authentication tokens and host parameters are stored securely inside Android encrypted preferences on the client device.

---

## Downloads

Official release packages are published on the [GitHub Releases](https://github.com/mina-android/NAS-Dash/releases) page.

| Platform | Architecture | Package Type | Download Link | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Android** | arm64-v8a | `.apk` | [Download (v1.1.1)](https://github.com/mina-android/NAS-Dash/releases/latest) | 64-bit Android devices (recommended) |
| **Android** | armeabi-v7a | `.apk` | [Download (v1.1.1)](https://github.com/mina-android/NAS-Dash/releases/latest) | Older 32-bit hardware |
| **Android** | x86_64 | `.apk` | [Download (v1.1.1)](https://github.com/mina-android/NAS-Dash/releases/latest) | Android x86 emulators |
| **Android** | Universal | `.apk` | [Download (v1.1.1)](https://github.com/mina-android/NAS-Dash/releases/latest) | Complete universal APK |

---

## Self Building & Local Setup

### 1. Prerequisites

Ensure the following tools are configured:

- **Flutter SDK**: `3.47.6` (pinned)
- **Dart SDK**: `3.13.5` (bundled with Flutter `3.47.6`)
- **Android SDK**: API level `36` (`minSdk 26`, `targetSdk 36`)
- **Java Development Kit**: JDK `21` LTS
- **Git**: `2.30+`

### 2. Repository Setup

```bash
# Clone the repository
git clone https://github.com/mina-android/NAS-Dash.git

# Navigate into project directory
cd NAS-Dash

# Check development environment
flutter doctor
```

### 3. Dependency Installation

```bash
# Install dependencies
flutter pub get
```

### 4. Build Compilation

```bash
# Compile release binaries
flutter build apk --split-per-abi --release
```

Output packages will be generated inside `build/app/outputs/flutter-apk/`.

### 5. Running Locally

```bash
flutter run --release
```

---

## Frequently Asked Questions

#### How do I generate an API key on TrueNAS SCALE?
Log into your TrueNAS SCALE Web UI using a browser. In the upper-right corner, click on your user profile icon, navigate to **API Keys**, select **Add**, name the key (e.g. `NAS-Dash`), and copy the generated token into the NAS Dash connection form.

#### Does NAS Dash work over self-hosted VPNs like Tailscale or NetBird?
Yes. When configuring your server connection, specify your primary local address under **Primary LAN Host** and your VPN IP address under **Fallback VPN Host**. NAS Dash tests local reachability first and transparently falls back to the VPN route when away from your home network.

#### Can NAS Dash execute destructive disk formatting or pool destruction?
No. To safeguard critical network storage and prevent accidental data loss, all pool, disk, and dataset management actions in NAS Dash are strictly read-only.

---

## Contribution

Contributions addressing bug reports, TrueNAS SCALE API compatibility, or UI refinements are welcome.

### Contribution Process

1. Check existing GitHub Issues to verify whether an issue or feature proposal is already being tracked.
2. For API changes related to newer TrueNAS releases (e.g., Electric Eel or Dragonfish), open an issue first.
3. Validate code formatting and tests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Submit a Pull Request targeting `main`.

---

## About the Developer

This project is authored and maintained by **mina-android**, building specialized Android utilities, homelab monitors, and infrastructure tooling.

- **Developer Portfolio**: [portfolio.minaashraf285.workers.dev](https://portfolio.minaashraf285.workers.dev/)
- **GitHub Profile**: [github.com/mina-android](https://github.com/mina-android)
- **Issue Tracker**: [github.com/mina-android/NAS-Dash/issues](https://github.com/mina-android/NAS-Dash/issues)

---

## Donate

If NAS Dash helps you monitor your storage infrastructure and manage your TrueNAS servers efficiently, your support is greatly appreciated:

- **PayPal**: [paypal.me/minaashraf285](https://paypal.me/minaashraf285)
- **GitHub Sponsors**: [github.com/sponsors/mina-android](https://github.com/sponsors/mina-android)

---

## License

Distributed under the **GNU General Public License v3.0**. See the [`LICENSE`](LICENSE) file in the root directory for legal conditions.

```text
Copyright (c) 2026 mina-android
Licensed under the GNU General Public License v3.0.
```

---

<div align="center">
  <sub>NAS Dash &bull; Maintained by mina-android &bull; Telemetry and management for TrueNAS SCALE.</sub>
</div>
