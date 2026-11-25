import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/landscape_mode_provider.dart';
import '../../../core/providers/server_connection_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../features/auth/models/server_profile.dart';
import '../../../features/auth/presentation/onboarding_screen.dart';
import '../../../features/auth/providers/auth_provider.dart';

class ServerStatusScreen extends ConsumerWidget {
  const ServerStatusScreen({super.key});

  String _formatCountdown(int totalSeconds) {
    final clamped = totalSeconds.clamp(0, 3599);
    final mins = (clamped ~/ 60).toString().padLeft(2, '0');
    final secs = (clamped % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _openServerManagementSheet(
    BuildContext context,
    WidgetRef ref,
    ServerProfile? activeServer,
    List<ServerProfile> profiles,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Server Connection & Profiles',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              if (activeServer != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('Edit "${activeServer.name}"'),
                  subtitle: Text(
                    activeServer.hasWolMac
                        ? 'MAC: ${activeServer.wolMacAddress} • ${activeServer.currentHost}'
                        : 'Configure IP, VPN, or Wake-on-LAN MAC address',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnboardingScreen(initialProfile: activeServer),
                      ),
                    );
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Add Another Server'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
              ),
              if (profiles.length > 1) ...[
                const Divider(),
                const SizedBox(height: 6),
                Text(
                  'Switch Active Server',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                ...profiles.map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      p.id == activeServer?.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: p.id == activeServer?.id
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.currentHost, style: const TextStyle(fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(authStateProvider.notifier).setActiveServer(p.id);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleWakeOnLan(
    BuildContext context,
    WidgetRef ref,
    ServerProfile? activeServer,
  ) async {
    if (activeServer == null) return;
    if (!activeServer.hasWolMac) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No MAC address saved for this server. Add it in Server Settings.',
          ),
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(initialProfile: activeServer),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    final res = await ref.read(serverConnectionProvider.notifier).wakeServer();
    if (!context.mounted) return;
    if (!res.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Failed to send Wake-on-LAN packet'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(serverConnectionProvider);
    final activeServer = ref.watch(activeServerProvider);
    final profiles = ref.watch(authStateProvider).valueOrNull ?? [];
    final isLandscapeLocked = ref.watch(landscapeModeProvider);
    final isLandscape =
        isLandscapeLocked || MediaQuery.of(context).orientation == Orientation.landscape;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (
      IconData heroIcon,
      Color accentColor,
      String title,
      String subtitle,
    ) = switch (connState.status) {
      ServerConnectionStatus.checking => (
          Icons.sync_rounded,
          colorScheme.primary,
          'Connecting to Server...',
          'Probing LAN and VPN routes for ${activeServer?.name ?? 'TrueNAS'}',
        ),
      ServerConnectionStatus.shutDown => (
          Icons.power_settings_new_rounded,
          AppColors.warning,
          'Server is Off',
          '${activeServer?.name ?? 'TrueNAS'} was shut down. Use Wake on LAN when you are ready to power it back on.',
        ),
      ServerConnectionStatus.restarting => (
          Icons.restart_alt_rounded,
          colorScheme.primary,
          'Server is Restarting',
          'Waiting for ${activeServer?.name ?? 'TrueNAS'} to reboot and bring TrueNAS middleware back online.',
        ),
      ServerConnectionStatus.waking => (
          Icons.bolt_rounded,
          AppColors.healthy,
          'Waking Server...',
          'Magic packet sent to ${activeServer?.wolMacAddress ?? 'server'}. Polling every 5 seconds until online.',
        ),
      ServerConnectionStatus.offline || ServerConnectionStatus.online => (
          Icons.cloud_off_rounded,
          AppColors.critical,
          'Server Offline or Disconnected',
          'Could not reach ${activeServer?.name ?? 'TrueNAS'} on LAN or VPN. Verify power, network, or wake it up.',
        ),
    };

    final actions = _buildActions(context, ref, connState, activeServer);

    final statusSummarySection = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: connState.status == ServerConnectionStatus.checking ||
                  connState.isProbing
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accentColor,
                      ),
                    ),
                    Icon(heroIcon, size: 28, color: accentColor),
                  ],
                )
              : Icon(heroIcon, size: 40, color: accentColor),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final detailAndActionsSection = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (connState.status == ServerConnectionStatus.restarting ||
            connState.status == ServerConnectionStatus.waking) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  _formatCountdown(connState.countdownRemainingSeconds),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: connState.status == ServerConnectionStatus.restarting
                      ? (1.0 - (connState.countdownRemainingSeconds / 180.0))
                          .clamp(0.0, 1.0)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  color: accentColor,
                ),
                const SizedBox(height: 6),
                Text(
                  connState.status == ServerConnectionStatus.restarting
                      ? 'Auto-refreshing connection when timer reaches 00:00'
                      : 'Checking server availability every 5s...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (connState.lastError != null && connState.lastError!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.critical.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.critical.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              connState.lastError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.critical,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (activeServer != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.dns_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeServer.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        activeServer.hasWolMac
                            ? '${activeServer.primaryHost} • MAC ${activeServer.wolMacAddress}'
                            : '${activeServer.primaryHost} • No WoL MAC saved',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...actions,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          activeServer?.name ?? 'NAS Dash',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: isLandscapeLocked ? 'Unlock Orientation' : 'Lock Landscape',
            icon: Icon(
              isLandscapeLocked
                  ? Icons.screen_lock_landscape_rounded
                  : Icons.stay_current_landscape_rounded,
            ),
            onPressed: () =>
                ref.read(landscapeModeProvider.notifier).toggleLandscapeLock(),
          ),
          IconButton(
            tooltip: 'Server Settings & Profiles',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _openServerManagementSheet(
              context,
              ref,
              activeServer,
              profiles,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isLandscape ? 780 : 460),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: isLandscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: statusSummarySection),
                          const SizedBox(width: 28),
                          Expanded(child: detailAndActionsSection),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusSummarySection,
                          const SizedBox(height: 22),
                          detailAndActionsSection,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    ServerConnectionState connState,
    ServerProfile? activeServer,
  ) {
    final notifier = ref.read(serverConnectionProvider.notifier);

    switch (connState.status) {
      case ServerConnectionStatus.checking:
        return [
          OutlinedButton.icon(
            onPressed: () => notifier.checkConnection(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Now'),
          ),
        ];

      case ServerConnectionStatus.shutDown:
        return [
          FilledButton.icon(
            onPressed: () => _handleWakeOnLan(context, ref, activeServer),
            icon: const Icon(Icons.power_settings_new_rounded),
            label: Text(
              activeServer?.hasWolMac == true
                  ? 'Wake on LAN'
                  : 'Configure Wake on LAN',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: connState.isProbing ? null : () => notifier.checkConnection(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check Connection'),
          ),
        ];

      case ServerConnectionStatus.restarting:
        return [
          FilledButton.icon(
            onPressed: connState.isProbing ? null : () => notifier.checkConnection(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check Now'),
          ),
        ];

      case ServerConnectionStatus.waking:
        return [
          FilledButton.icon(
            onPressed: () => _handleWakeOnLan(context, ref, activeServer),
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Send Magic Packet Again'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: notifier.cancelWaking,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel'),
          ),
        ];

      case ServerConnectionStatus.offline:
      case ServerConnectionStatus.online:
        return [
          FilledButton.icon(
            onPressed: connState.isProbing ? null : () => notifier.checkConnection(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh Connection'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _handleWakeOnLan(context, ref, activeServer),
            icon: const Icon(Icons.power_settings_new_rounded),
            label: Text(
              activeServer?.hasWolMac == true
                  ? 'Wake on LAN'
                  : 'Configure Wake on LAN',
            ),
          ),
        ];
    }
  }
}
