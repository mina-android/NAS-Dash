import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/frosted_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/refresh_action_button.dart';
import '../../apps/providers/apps_provider.dart';
import '../../auth/models/server_profile.dart';
import '../../auth/presentation/onboarding_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/telemetry_provider.dart';
import '../../system/providers/system_provider.dart';
import 'widgets/active_jobs_sheet.dart';
import 'widgets/app_resource_usage_sheet.dart';
import 'widgets/boot_pool_sheet.dart';
import 'widgets/power_logs_sheet.dart';
import 'widgets/smb_acl_bottom_sheet.dart';
import 'widgets/users_sheet.dart';

const String _kPoolWarningThresholdKey = 'nas_dash_pool_warning_threshold';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _poolWarningThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _loadPoolThreshold();
  }

  Future<void> _loadPoolThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kPoolWarningThresholdKey);
    if (saved != null && mounted) {
      setState(() => _poolWarningThreshold = saved);
    }
  }

  Future<void> _setPoolThreshold(double val) async {
    setState(() => _poolWarningThreshold = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPoolWarningThresholdKey, val);
  }

  Future<bool> _authenticateBiometrics(BuildContext context) async {
    final localAuth = LocalAuthentication();
    try {
      final canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (!canCheck) return true;
      return await localAuth.authenticate(
        localizedReason: 'Confirm device biometric / PIN to perform TrueNAS Power actions',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return true;
    }
  }

  void _showPowerDialog(BuildContext context, bool isReboot) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isReboot ? Icons.restart_alt : Icons.power_settings_new,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(isReboot ? 'Reboot Server?' : 'Shutdown Server?'),
          ],
        ),
        content: Text(
          isReboot
              ? 'Are you sure you want to reboot the TrueNAS SCALE host? All active containers and shares will temporarily disconnect.'
              : 'Are you sure you want to shut down the TrueNAS SCALE host? You will need physical or IPMI access to turn it back on.',
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final authenticated = await _authenticateBiometrics(context);
              if (authenticated) {
                final ok = isReboot
                    ? await ref.read(systemProvider.notifier).reboot()
                    : await ref.read(systemProvider.notifier).shutdown();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Power command dispatched' : 'Failed to dispatch command'),
                      backgroundColor: ok ? AppColors.healthy : AppColors.critical,
                    ),
                  );
                }
              }
            },
            child: Text(isReboot ? 'Reboot' : 'Shutdown'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final activeServer = ref.watch(activeServerProvider);
    final profiles = authState.valueOrNull ?? [];
    final sysState = ref.watch(systemProvider);
    final sysNotifier = ref.read(systemProvider.notifier);
    final telemetryState = ref.watch(telemetryProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    final themeNotifier = ref.read(themeSettingsProvider.notifier);
    final appsState = ref.watch(appsProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = colorScheme.onSurfaceVariant;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 12;

    final sysShares = sysState.valueOrNull?.smbShares ?? [];
    final telemetryShares = telemetryState.valueOrNull?.shares ?? [];
    final smbShares = sysShares.isNotEmpty ? sysShares : telemetryShares;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        title: const Text('System & Settings'),
        actions: [
          RefreshActionButton(
            onRefresh: () async {
              await Future.wait([
                ref.read(authStateProvider.notifier).loadProfiles(),
                sysNotifier.fetchSystem(),
                ref.read(telemetryProvider.notifier).fetchTelemetry(),
              ]);
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, 96),
        children: [
          // 1. Unified Server Management Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SERVER MANAGEMENT (${profiles.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Server'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: profiles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No servers configured. Tap "Add Server" to get started.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeServer != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(Icons.dns_rounded, color: iconColor, size: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          activeServer.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    activeServer.currentHost,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit Profile',
                                  icon: Icon(Icons.edit_outlined, size: 20, color: iconColor),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => OnboardingScreen(initialProfile: activeServer),
                                      ),
                                    );
                                  },
                                ),
                                if (profiles.length > 1)
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, size: 18, color: iconColor),
                                    onSelected: (val) {
                                      if (val == 'delete') {
                                        ref.read(authStateProvider.notifier).deleteProfile(activeServer.id);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete Server', style: TextStyle(color: AppColors.critical)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: iconColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Auth: ${activeServer.authType == AuthType.apiKey ? "API Key" : "Credentials (${activeServer.username})"}'
                                  '${activeServer.allowSelfSigned ? " • TLS Self-Signed Allowed" : ""}',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (activeServer.secondaryHost?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Route: ${activeServer.activeRoute == ActiveRoute.lan ? "Primary (LAN)" : "Secondary (VPN)"}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Switch(
                                value: activeServer.activeRoute == ActiveRoute.vpn,
                                onChanged: (val) {
                                  ref.read(authStateProvider.notifier).toggleRoute(
                                    activeServer.id,
                                    val ? ActiveRoute.vpn : ActiveRoute.lan,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (profiles.length > 1) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'SWITCH SERVER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...profiles.where((p) => p.id != activeServer?.id).map((p) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              leading: Icon(Icons.dns_outlined, color: iconColor, size: 20),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(p.primaryHost, style: const TextStyle(fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    ),
                                    onPressed: () => ref.read(authStateProvider.notifier).setActiveServer(p.id),
                                    child: const Text('Switch', style: TextStyle(fontSize: 11)),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, size: 16, color: iconColor),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => OnboardingScreen(initialProfile: p)),
                                        );
                                      } else if (val == 'delete') {
                                        ref.read(authStateProvider.notifier).deleteProfile(p.id);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete', style: TextStyle(color: AppColors.critical)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // 2. SMB File Shares (Always visible on load without requiring manual refresh)
          Text(
            'SMB FILE SHARES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.folder_shared_outlined, color: iconColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Active File Shares',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                if (smbShares.isEmpty && (sysState.isLoading || telemetryState.isLoading))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                      ),
                    ),
                  )
                else if (smbShares.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'No SMB file shares configured on this TrueNAS host.',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  ...smbShares.map((s) {
                    final id = (s['id'] as num?)?.toInt() ?? 0;
                    final name = s['name'] as String? ?? 'share';
                    final enabled = s['enabled'] as bool? ?? true;
                    final path = s['path'] as String? ?? '';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Icon(Icons.folder_outlined, color: iconColor),
                        title: Text(
                          name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                        ),
                        subtitle: Text(path, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View ACL / Permissions',
                              icon: Icon(Icons.security_outlined, size: 20, color: iconColor),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => SmbAclBottomSheet(
                                    shareName: name,
                                    sharePath: path,
                                    systemNotifier: sysNotifier,
                                    users: sysState.valueOrNull?.users ?? [],
                                    groups: sysState.valueOrNull?.groups ?? [],
                                  ),
                                );
                              },
                            ),
                            Switch(
                              value: enabled,
                              activeThumbColor: colorScheme.primary,
                              onChanged: (val) async {
                                final ok = await sysNotifier.toggleShare(id, val);
                                ref.read(telemetryProvider.notifier).fetchTelemetry();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Share "$name" ${val ? "enabled" : "disabled"}'
                                            : 'Failed to update share state',
                                      ),
                                      backgroundColor: ok ? AppColors.healthy : AppColors.critical,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. System Logs & User Accounts
          Text(
            'SYSTEM LOGS & USER ACCOUNTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.history_toggle_off_rounded, color: iconColor, size: 22),
                  title: const Text('Host Power & Reboot History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Server restart, shutdown, and boot operation dates', style: TextStyle(fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, size: 18, color: iconColor),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => PowerLogsSheet(systemNotifier: sysNotifier),
                    );
                  },
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.manage_accounts_outlined, color: iconColor, size: 22),
                  title: const Text('Created User Accounts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Inspect non-system users, UIDs, and sudo privileges (${sysState.valueOrNull?.users.length ?? 0} total)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Icon(Icons.chevron_right, size: 18, color: iconColor),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => UsersSheet(users: sysState.valueOrNull?.users ?? []),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Advanced Controls & Telemetry
          Text(
            'ADVANCED CONTROLS & TELEMETRY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storage_rounded, size: 18, color: iconColor),
                              const SizedBox(width: 8),
                              const Text('Storage Pool Warning Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(
                            '${_poolWarningThreshold.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Send notifications when any pool capacity exceeds threshold',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                      Slider(
                        value: _poolWarningThreshold,
                        min: 70.0,
                        max: 95.0,
                        divisions: 5,
                        label: '${_poolWarningThreshold.toStringAsFixed(0)}%',
                        onChanged: (val) => _setPoolThreshold(val),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.pending_actions_rounded, color: iconColor),
                  title: const Text('Active Jobs & Tasks Monitor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Live view of running TrueNAS background tasks with abort', style: TextStyle(fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, size: 18, color: iconColor),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ActiveJobsSheet(systemNotifier: sysNotifier),
                    );
                  },
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.shield_outlined, color: iconColor),
                  title: const Text('OS Boot Pool & SSD Health', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Mirror disk status, wear level %, and boot scrub state', style: TextStyle(fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, size: 18, color: iconColor),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BootPoolSheet(systemNotifier: sysNotifier),
                    );
                  },
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(Icons.pie_chart_outline_rounded, color: iconColor),
                  title: const Text('App Container Resources', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Container runtime state and memory allocation breakdown', style: TextStyle(fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, size: 18, color: iconColor),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => AppResourceUsageSheet(apps: appsState.valueOrNull ?? []),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Host Power Management
          Text(
            'HOST POWER CONTROLS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.power_settings_new, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text('Host Power Management', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Guarded by biometric / device lock to prevent accidental server interruptions.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showPowerDialog(context, true),
                        icon: Icon(Icons.restart_alt, color: colorScheme.onSurface),
                        label: const Text('Reboot Host'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical, foregroundColor: Colors.white),
                        onPressed: () => _showPowerDialog(context, false),
                        icon: const Icon(Icons.power_settings_new, color: Colors.white),
                        label: const Text('Shutdown'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. Appearance & Theme Card
          Text(
            'APPEARANCE & THEME',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text('Theme Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 16),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 16),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 16),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeSettings.themeMode},
                    onSelectionChanged: (set) {
                      themeNotifier.setThemeMode(set.first);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Android Dynamic Colors (Material You)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Adapts UI palette to your Android 12+ wallpaper colors', style: TextStyle(fontSize: 11)),
                  value: themeSettings.useDynamicColors,
                  onChanged: (val) => themeNotifier.setUseDynamicColors(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 7. System Notifications & Push Alerts Card
          Text(
            'NOTIFICATIONS & ALERTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: FutureBuilder<bool>(
              future: NotificationService.instance.areNotificationsEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notifications_active_outlined, color: iconColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Server Alerts Engine',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            enabled ? 'Allowed' : 'Permission Required',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Push notifications trigger via TrueNAS WebSocket alert event stream and 15-minute background workers.',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (!enabled)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.security, size: 16),
                            label: const Text('Grant Notification Access'),
                            onPressed: () async {
                              final granted = await NotificationService.instance.requestPermissions();
                              if (context.mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      granted
                                          ? 'Notification permission granted!'
                                          : 'Please enable notifications in Android Settings.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send_outlined, size: 16),
                          label: const Text('Test Local Alert Notification'),
                          onPressed: () async {
                            await NotificationService.instance.requestPermissions();
                            await NotificationService.instance.showAlertNotification(
                              uuid: 'test_${DateTime.now().millisecondsSinceEpoch}',
                              title: 'Test Notification (INFO)',
                              body: 'NAS Dash alert notification channel is working correctly!',
                              level: 'INFO',
                              force: true,
                            );
                            if (context.mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test notification dispatched to status bar')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 8. About Section
          Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.dns, color: iconColor, size: 22),
                  ),
                  title: Text('NAS Dash', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                  subtitle: Text('TrueNAS SCALE Dashboard & Control Panel', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('v1.0.0+1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant)),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline, color: iconColor),
                  title: Text('Developer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  subtitle: Text('Discover more projects by Mina Android', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  trailing: Icon(Icons.chevron_right, color: iconColor),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Developer Info', style: TextStyle(fontWeight: FontWeight.w700)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.code_rounded, color: iconColor),
                              title: const Text('GitHub Profile'),
                              subtitle: const Text('github.com/mina-android', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.open_in_new, size: 16),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final uri = Uri.parse('https://github.com/mina-android');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.language_rounded, color: iconColor),
                              title: const Text('Developer Website'),
                              subtitle: const Text('portfolio.minaashraf285.workers.dev', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.open_in_new, size: 16),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final uri = Uri.parse('https://portfolio.minaashraf285.workers.dev');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.code, color: iconColor),
                  title: Text('GitHub Repository', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  subtitle: Text('View source code and contribute', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  trailing: Icon(Icons.open_in_new, size: 16, color: iconColor),
                  onTap: () async {
                    final uri = Uri.parse('https://github.com/mina-android/NAS-Dash');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
