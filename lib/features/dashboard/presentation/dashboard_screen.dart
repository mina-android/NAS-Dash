import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_app_bar.dart';
import '../../../core/widgets/refresh_action_button.dart';
import '../../auth/models/server_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/dashboard_widget_config.dart';
import '../providers/dashboard_layout_provider.dart';
import '../providers/telemetry_provider.dart';
import 'widgets/alerts_jobs_widget.dart';
import 'widgets/apps_usage_widget.dart';
import 'widgets/collapsible_dashboard_card.dart';
import 'widgets/cpu_widget.dart';
import 'widgets/dashboard_customizer_sheet.dart';
import 'widgets/disk_health_widget.dart';
import 'widgets/gpu_widget.dart';
import 'widgets/memory_arc_widget.dart';
import 'widgets/network_traffic_widget.dart';
import 'widgets/shares_services_widget.dart';
import 'widgets/storage_pools_summary_widget.dart';
import 'widgets/system_summary_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryState = ref.watch(telemetryProvider);
    final layout = ref.watch(dashboardLayoutProvider);
    final layoutNotifier = ref.read(dashboardLayoutProvider.notifier);
    final activeServer = ref.watch(activeServerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.healthy,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(activeServer?.name ?? 'NAS Dash'),
          ],
        ),
        actions: [
          // Failover route toggle button (LAN <-> NetBird)
          if (activeServer != null && activeServer.secondaryHost?.isNotEmpty == true)
            IconButton(
              tooltip: 'Switch Route: ${activeServer.activeRoute == ActiveRoute.lan ? "LAN" : "VPN"}',
              icon: Icon(
                activeServer.activeRoute == ActiveRoute.lan ? Icons.wifi : Icons.vpn_lock,
                color: activeServer.activeRoute == ActiveRoute.lan ? AppColors.healthy : colorScheme.primary,
              ),
              onPressed: () {
                final next = activeServer.activeRoute == ActiveRoute.lan
                    ? ActiveRoute.vpn
                    : ActiveRoute.lan;
                ref.read(authStateProvider.notifier).toggleRoute(activeServer.id, next);
                ref.read(telemetryProvider.notifier).fetchTelemetry();
              },
            ),
          IconButton(
            tooltip: 'Customize Layout',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const DashboardCustomizerSheet(),
              );
            },
          ),
          RefreshActionButton(
            onRefresh: () => ref.read(telemetryProvider.notifier).fetchTelemetry(),
          ),
        ],
      ),
      body: telemetryState.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('Connecting to TrueNAS SCALE...', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.critical, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Connection Failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(telemetryProvider.notifier).fetchTelemetry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
        data: (snapshot) {
          final host = activeServer?.primaryHost.replaceAll('http://', '').replaceAll('https://', '') ?? '';
          final vpn = activeServer?.secondaryHost?.replaceAll('http://', '').replaceAll('https://', '') ?? 'VPN';
          final activeRouteLabel = activeServer?.activeRoute == ActiveRoute.lan
              ? 'LAN ($host)'
              : 'VPN ($vpn)';

          final visibleWidgets = layout.where((w) => w.isVisible).toList();

          return RefreshIndicator(
            color: colorScheme.primary,
            edgeOffset: topPadding,
            onRefresh: () => ref.read(telemetryProvider.notifier).fetchTelemetry(),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, 96),
              itemCount: visibleWidgets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cfg = visibleWidgets[index];
                final isCompact = cfg.size == WidgetCardSize.compact;
                final isCollapsed = cfg.isCollapsed;
                void onToggle() => layoutNotifier.toggleCollapsed(cfg.type);

                switch (cfg.type) {
                  case DashboardWidgetType.systemSummary:
                    return CollapsibleDashboardCard(
                      icon: Icons.dns_rounded,
                      title: 'System & Host Summary',
                      summary: '${snapshot.systemInfo.hostname} • Up ${snapshot.systemInfo.uptime.split('.').first.trim()}',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: SystemSummaryWidget(
                        systemInfo: snapshot.systemInfo,
                        activeRouteLabel: activeRouteLabel,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.cpuUsage:
                  case DashboardWidgetType.cpuTemp:
                    return CollapsibleDashboardCard(
                      icon: Icons.speed_rounded,
                      title: 'CPU Usage & Cores',
                      summary: '${snapshot.cpuUsage.toStringAsFixed(1)}% usage • ${snapshot.cpuTemp.toStringAsFixed(0)}°C',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: CpuWidget(
                        cpuUsage: snapshot.cpuUsage,
                        cpuTemp: snapshot.cpuTemp,
                        perCoreTemps: snapshot.perCoreTemps,
                        cpuHistory: snapshot.cpuHistory,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.memoryArc:
                    final ramUsedPct = ((snapshot.ramUsedBytes / (snapshot.ramTotalBytes > 0 ? snapshot.ramTotalBytes : 1)) * 100).toStringAsFixed(1);
                    return CollapsibleDashboardCard(
                      icon: Icons.memory_rounded,
                      title: 'RAM & ZFS ARC Memory',
                      summary: '$ramUsedPct% used • Hit ratio: ${snapshot.arcHitRatio.toStringAsFixed(1)}%',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: MemoryArcWidget(
                        ramUsedBytes: snapshot.ramUsedBytes,
                        ramTotalBytes: snapshot.ramTotalBytes,
                        ramFreeBytes: snapshot.ramFreeBytes,
                        ramCachedBuffersBytes: snapshot.ramCachedBuffersBytes,
                        arcSizeBytes: snapshot.arcSizeBytes,
                        arcHitRatio: snapshot.arcHitRatio,
                        swapTotalBytes: snapshot.swapTotalBytes,
                        swapUsedBytes: snapshot.swapUsedBytes,
                        eccMemory: snapshot.systemInfo.eccMemory,
                        ramHistory: snapshot.ramHistory,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.gpuStatus:
                    return CollapsibleDashboardCard(
                      icon: Icons.videogame_asset_rounded,
                      title: 'GPU Hardware & State',
                      summary: snapshot.gpuData != null ? 'GPU detected & active' : 'No dedicated GPU',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: GpuWidget(
                        gpuData: snapshot.gpuData,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.storagePools:
                    return CollapsibleDashboardCard(
                      icon: Icons.storage_rounded,
                      title: 'Storage Pools Capacity',
                      summary: '${snapshot.pools.length} pool(s) online',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: StoragePoolsSummaryWidget(
                        pools: snapshot.pools,
                        bootState: snapshot.bootState,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.diskHealthIo:
                    return CollapsibleDashboardCard(
                      icon: Icons.disc_full_rounded,
                      title: 'Disk Health & Temps',
                      summary: '${snapshot.diskTemps.length} drives monitored',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: DiskHealthWidget(
                        diskTemps: snapshot.diskTemps,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.networkTraffic:
                    return CollapsibleDashboardCard(
                      icon: Icons.swap_vert_rounded,
                      title: 'Network Interfaces',
                      summary: '${snapshot.networkInterfaces.length} active interfaces',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: NetworkTrafficWidget(
                        interfaces: snapshot.networkInterfaces,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.appsUsage:
                    final running = snapshot.apps
                        .where((a) => (a['state'] as String? ?? '').toUpperCase() == 'RUNNING')
                        .length;
                    return CollapsibleDashboardCard(
                      icon: Icons.apps_rounded,
                      title: 'Installed Apps Usage',
                      summary: '$running running / ${snapshot.apps.length} total apps',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: AppsUsageWidget(
                        apps: snapshot.apps,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.alertsJobs:
                    return CollapsibleDashboardCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Alerts & Active Jobs',
                      summary: '${snapshot.alerts.length} alerts • ${snapshot.jobs.length} jobs',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: AlertsJobsWidget(
                        alerts: snapshot.alerts,
                        jobs: snapshot.jobs,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.sharesServices:
                    return CollapsibleDashboardCard(
                      icon: Icons.folder_shared_rounded,
                      title: 'SMB Shares & Services',
                      summary: '${snapshot.shares.length} SMB share(s)',
                      isCollapsed: isCollapsed,
                      onToggleCollapse: onToggle,
                      child: SharesServicesWidget(
                        shares: snapshot.shares,
                        services: snapshot.services,
                        isCompact: isCompact,
                      ),
                    );
                  case DashboardWidgetType.upsStatus:
                    return const SizedBox.shrink();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
